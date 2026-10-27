import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../app/board_widgets.dart';
import '../../services/delivery_service.dart';
import '../../services/route_service.dart';

class DeliverySearchingScreen extends StatefulWidget {
  const DeliverySearchingScreen({
    super.key,
    required this.deliveryId,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.deliveryStream,
    this.profileStream,
  });
  final String deliveryId, pickupAddress, dropoffAddress;
  final Stream<Map<String, dynamic>?>? deliveryStream;
  final Stream<Map<String, dynamic>?> Function(String)? profileStream;
  @override
  State<DeliverySearchingScreen> createState() =>
      _DeliverySearchingScreenState();
}

class _DeliverySearchingScreenState extends State<DeliverySearchingScreen> {
  final _service = DeliveryService();
  late Stream<Map<String, dynamic>?> _deliveryStream;
  Stream<Map<String, dynamic>?>? _courierStream;
  String? _courierId;
  GoogleMapController? _map;
  RouteResult? _route;
  DateTime? _routeAt;
  LatLng? _target;
  bool _routeBusy = false, _cancelling = false;

  @override
  void initState() {
    super.initState();
    _deliveryStream =
        widget.deliveryStream ?? _service.watchDelivery(widget.deliveryId);
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    final confirmed = await boardConfirm(
      context,
      title: 'Cancel delivery?',
      message: 'Your package request will be cancelled. You can book another delivery from Home.',
      confirmLabel: 'Cancel delivery',
      cancelLabel: 'Keep delivery',
      icon: Icons.inventory_2_outlined,
    );
    if (!confirmed || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await _service.cancelDelivery(widget.deliveryId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        boardInfo(
          context,
          'Could not cancel',
          'The courier may already have accepted. Check your connection and the latest delivery status.',
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _contact(String phone, bool message) async {
    try {
      if (await launchUrl(Uri(scheme: message ? 'sms' : 'tel', path: phone))) {
        return;
      }
    } catch (_) {
      /* Show the number when the platform has no handler. */
    }
    if (mounted) boardInfo(context, 'Contact your courier', phone);
  }

  Future<void> _updateRoute(LatLng from, LatLng to) async {
    if (_routeBusy ||
        (_target == to &&
            _routeAt != null &&
            DateTime.now().difference(_routeAt!).inSeconds < 30)) {
      return;
    }
    _routeBusy = true;
    _target = to;
    _routeAt = DateTime.now();
    try {
      final route = await RouteService().getRoute(from, to);
      if (mounted && _target == to) setState(() => _route = route);
    } catch (_) {
      /* Markers stay visible if directions are unavailable. */
    } finally {
      _routeBusy = false;
    }
  }

  LatLng? _point(Map<String, dynamic>? row, String lat, String lng) =>
      row?[lat] is num && row?[lng] is num
      ? LatLng((row![lat] as num).toDouble(), (row[lng] as num).toDouble())
      : null;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your Delivery'), centerTitle: true),
    body: StreamBuilder<Map<String, dynamic>?>(
      stream: _deliveryStream,
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            (snapshot.connectionState != ConnectionState.waiting &&
                snapshot.data == null)) {
          return Center(
            child: StatusMessage(
              message: 'Could not load your delivery. Check your connection and try again.',
              onRetry: () => setState(
                () => _deliveryStream =
                    widget.deliveryStream ??
                    _service.watchDelivery(widget.deliveryId),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final delivery = snapshot.data!;
        final courierId = delivery['courier_id'] as String?;
        if (_courierId != courierId) {
          _courierId = courierId;
          _courierStream = courierId == null
              ? null
              : (widget.profileStream?.call(courierId) ??
                    _service.watchProfile(courierId));
        }
        return StreamBuilder<Map<String, dynamic>?>(
          key: ValueKey(courierId),
          stream: _courierStream,
          builder: (context, courier) => _tracking(delivery, courier.data),
        );
      },
    ),
  );

  Widget _tracking(
    Map<String, dynamic> delivery,
    Map<String, dynamic>? courier,
  ) {
    final status = delivery['status'] as String? ?? 'requested';
    final complete = status == 'completed';
    final ended = complete || status == 'cancelled';
    final pickup = _point(delivery, 'pickup_lat', 'pickup_lng');
    final dropoff = _point(delivery, 'dropoff_lat', 'dropoff_lng');
    final position = ended
        ? null
        : _point(courier, 'current_lat', 'current_lng');
    final name = courier?['full_name'] as String? ?? 'Your courier';
    final phone = courier?['phone'] as String?;
    final title = switch (status) {
      'accepted' => 'Courier on the way',
      'picked_up' || 'in_progress' => 'Package on the way',
      'completed' => 'Delivery completed!',
      'cancelled' => 'Delivery cancelled',
      _ => 'Finding your courier',
    };
    if (!ended &&
        pickup != null &&
        dropoff != null &&
        widget.deliveryStream == null) {
      _updateRoute(
        position ?? pickup,
        position != null && status == 'accepted' ? pickup : dropoff,
      );
    }
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: pickup ?? const LatLng(.3476, 32.5825),
                    zoom: 13,
                  ),
                  onMapCreated: (controller) => _map = controller,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  markers: {
                    if (pickup != null)
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: pickup,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure,
                        ),
                        infoWindow: const InfoWindow(title: 'Pickup'),
                      ),
                    if (dropoff != null)
                      Marker(
                        markerId: const MarkerId('dropoff'),
                        position: dropoff,
                        infoWindow: const InfoWindow(
                          title: 'Delivery location',
                        ),
                      ),
                    if (position != null)
                      Marker(
                        markerId: const MarkerId('courier'),
                        position: position,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen,
                        ),
                        infoWindow: InfoWindow(title: name),
                      ),
                  },
                  polylines: {
                    if (_route != null && !ended)
                      Polyline(
                        polylineId: const PolylineId('delivery-route'),
                        points: _route!.points,
                        color: AppColors.blueDeep,
                        width: 5,
                      ),
                  },
                ),
              ),
              if (position != null)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'courier-follow',
                    tooltip: 'Find courier on map',
                    backgroundColor: Colors.white,
                    onPressed: () => _map?.animateCamera(
                      CameraUpdate.newLatLngZoom(position, 15),
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: AppColors.blueDeep,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .55,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: complete
                            ? const Color(0xFFE7F8EE)
                            : AppColors.blueTint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        complete
                            ? Icons.check_rounded
                            : Icons.inventory_2_outlined,
                        color: complete
                            ? AppColors.success
                            : AppColors.blueDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (status == 'requested')
                  const Text(
                    'We will update this page when a courier accepts.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                if (!ended && _courierId != null) ...[
                  const SizedBox(height: 8),
                  BoardCard(
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.blueTint,
                          child: Icon(
                            Icons.person_outline,
                            color: AppColors.blueDeep,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                position == null
                                    ? 'Waiting for live location'
                                    : 'Live courier location',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (phone != null && phone.isNotEmpty) ...[
                          IconButton(
                            tooltip: 'Call courier',
                            onPressed: () => _contact(phone, false),
                            icon: const Icon(
                              Icons.call_outlined,
                              color: AppColors.blueDeep,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Message courier',
                            onPressed: () => _contact(phone, true),
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              color: AppColors.blueDeep,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                BoardCard(
                  child: Column(
                    children: [
                      RouteRow(
                        title: 'Pickup location',
                        value: widget.pickupAddress,
                      ),
                      const Divider(height: 1),
                      RouteRow(
                        title: 'Delivery location',
                        value: widget.dropoffAddress,
                        destination: true,
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            size: 18,
                            color: AppColors.blueDeep,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Cash')),
                          Text(
                            ugx(delivery['fare_ugx']),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (status == 'requested')
                  OutlinedButton(
                    onPressed: _cancelling ? null : _cancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: Text(
                      _cancelling ? 'Cancelling...' : 'Cancel delivery',
                    ),
                  ),
                if (ended)
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
