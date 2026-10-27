import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../app/board_widgets.dart';
import '../../services/ride_service.dart';
import '../../models/booking_summary.dart';
import '../../services/route_service.dart';
import '../account/customer_pages.dart';
import 'trip_completed_screen.dart';

class SearchingScreen extends StatefulWidget {
  final String rideId;
  final String pickupAddress;
  final String dropoffAddress;
  final String? bookingReference;
  final String? reservationType;
  final String? seatNumber;
  final List<String>? seatNumbers;
  final RouteResult? initialRoute;
  final Stream<Map<String, dynamic>?>? rideStream;
  final Stream<Map<String, dynamic>?> Function(String)? profileStream;
  final Future<RouteResult> Function(LatLng, LatLng, String)? routeLoader;

  const SearchingScreen({
    super.key,
    required this.rideId,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.bookingReference,
    this.reservationType,
    this.seatNumber,
    this.seatNumbers,
    this.initialRoute,
    this.rideStream,
    this.profileStream,
    this.routeLoader,
  });

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen> {
  final _rideService = RideService();
  GoogleMapController? _mapController;
  LatLng? _lastDriverPosition;
  late Stream<Map<String, dynamic>?> _rideStream;
  Stream<Map<String, dynamic>?>? _driverStream;
  String? _driverId;
  RouteResult? _trackingRoute;
  DateTime? _lastRouteAt;
  LatLng? _routeTarget;
  bool _routeBusy = false;
  bool _routeFailed = false;
  RouteResult? _tripRoute;
  LatLng? _desiredStart;
  LatLng? _desiredTarget;
  String _desiredVehicle = 'car';

  Future<void> _updateRoute(
    LatLng driver,
    LatLng target,
    String vehicle,
  ) async {
    _desiredStart = driver;
    _desiredTarget = target;
    _desiredVehicle = vehicle;
    if (_routeBusy ||
        (_routeTarget == target &&
            _lastRouteAt != null &&
            DateTime.now().difference(_lastRouteAt!).inSeconds < 30)) {
      return;
    }
    if (_routeTarget != target) _trackingRoute = null;
    _routeBusy = true;
    _routeFailed = false;
    _routeTarget = target;
    _lastRouteAt = DateTime.now();
    try {
      final route =
          await (widget.routeLoader?.call(driver, target, vehicle) ??
              RouteService().getRoute(driver, target, vehicleType: vehicle));
      if (mounted && _desiredTarget == target) {
        setState(() => _trackingRoute = route);
        _fitRoute(route);
      }
    } catch (_) {
      if (mounted && _desiredTarget == target) {
        setState(() => _routeFailed = true);
      }
    } finally {
      _routeBusy = false;
      if (mounted && _desiredTarget != target && _desiredStart != null) {
        _updateRoute(_desiredStart!, _desiredTarget!, _desiredVehicle);
      }
    }
  }

  void _fitRoute(RouteResult? route) {
    if (route == null || route.points.isEmpty) return;
    final points = route.points;
    double minLat = points.first.latitude, maxLat = minLat;
    double minLng = points.first.longitude, maxLng = minLng;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    if (minLat == maxLat && minLng == maxLng) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 16),
      );
    } else {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          50,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _tripRoute = widget.initialRoute;
    _rideStream = widget.rideStream ?? _rideService.watchRide(widget.rideId);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BoardDialog(
        title: const Text('Cancel this booking?'),
        content: const Text(
          'You will need to make a new request if you still want to travel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _rideService.cancelRide(widget.rideId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not cancel. Check your connection and try again.',
            ),
          ),
        );
      }
    }
  }

  void _followDriver(LatLng driver, LatLng pickup) {
    if (_lastDriverPosition == driver) return;
    _lastDriverPosition = driver;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (RideService.distanceKm(
            driver.latitude,
            driver.longitude,
            pickup.latitude,
            pickup.longitude,
          ) <
          0.02) {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pickup, 16));
        return;
      }
      final southwest = LatLng(
        driver.latitude < pickup.latitude ? driver.latitude : pickup.latitude,
        driver.longitude < pickup.longitude
            ? driver.longitude
            : pickup.longitude,
      );
      final northeast = LatLng(
        driver.latitude > pickup.latitude ? driver.latitude : pickup.latitude,
        driver.longitude > pickup.longitude
            ? driver.longitude
            : pickup.longitude,
      );
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: southwest, northeast: northeast),
          70,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Trip'), centerTitle: true),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _rideStream,
        builder: (context, rideSnapshot) {
          if (rideSnapshot.hasError ||
              (rideSnapshot.connectionState != ConnectionState.waiting &&
                  rideSnapshot.data == null)) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Could not load this booking. Check your connection.',
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _rideStream = _rideService.watchRide(widget.rideId),
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }
          final ride = rideSnapshot.data;
          if (ride == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final driverId = ride['driver_id'] as String?;
          if (_driverId != driverId) {
            _driverId = driverId;
            _driverStream = driverId == null
                ? null
                : widget.profileStream?.call(driverId) ??
                      _rideService.watchProfile(driverId);
          }
          return StreamBuilder<Map<String, dynamic>?>(
            key: ValueKey(driverId),
            stream: _driverStream,
            builder: (context, profileSnapshot) {
              return _buildTrackingView(ride, profileSnapshot.data);
            },
          );
        },
      ),
    );
  }

  Widget _buildTrackingView(
    Map<String, dynamic> ride,
    Map<String, dynamic>? driver,
  ) {
    final status = ride['status'] as String? ?? 'requested';
    if (status == 'completed') {
      return TripCompletedScreen(ride: ride, driver: driver);
    }
    final pickup = LatLng(
      (ride['pickup_lat'] as num).toDouble(),
      (ride['pickup_lng'] as num).toDouble(),
    );
    final dropoff = LatLng(
      (ride['dropoff_lat'] as num).toDouble(),
      (ride['dropoff_lng'] as num).toDouble(),
    );
    final lat = driver?['current_lat'] as num?;
    final lng = driver?['current_lng'] as num?;
    final driverPosition = lat == null || lng == null
        ? null
        : LatLng(lat.toDouble(), lng.toDouble());
    final vehicle = ride['vehicle_type'] as String? ?? 'car';
    final target = status == 'in_progress' || driverPosition == null
        ? dropoff
        : pickup;
    if (status != 'cancelled') {
      if (driverPosition != null || _tripRoute == null) {
        _updateRoute(driverPosition ?? pickup, target, vehicle);
      }
    }
    final visibleRoute = _routeTarget == target && _trackingRoute != null
        ? _trackingRoute
        : target == dropoff
        ? _tripRoute
        : null;
    if (driverPosition != null && status != 'completed') {
      _followDriver(driverPosition, status == 'in_progress' ? dropoff : pickup);
    }

    return Column(
      children: [
        if (visibleRoute == null && status != 'cancelled')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _routeFailed
                        ? 'Road route unavailable. Check your connection and retry.'
                        : 'Loading road route…',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                if (_routeFailed)
                  TextButton(
                    onPressed: () {
                      _lastRouteAt = null;
                      _updateRoute(driverPosition ?? pickup, target, vehicle);
                      setState(() {});
                    },
                    child: const Text('Retry'),
                  ),
              ],
            ),
          ),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
            onMapCreated: (controller) {
              _mapController = controller;
              _fitRoute(visibleRoute);
            },
            zoomControlsEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId('pickup'),
                position: pickup,
                infoWindow: const InfoWindow(title: 'Pickup'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
              ),
              Marker(
                markerId: const MarkerId('dropoff'),
                position: dropoff,
                infoWindow: const InfoWindow(title: 'Destination'),
              ),
              if (driverPosition != null)
                Marker(
                  markerId: const MarkerId('driver'),
                  position: driverPosition,
                  infoWindow: InfoWindow(
                    title: driver?['full_name'] as String? ?? 'Your driver',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure,
                  ),
                ),
            },
            polylines: {
              if (visibleRoute != null && status != 'cancelled')
                Polyline(
                  polylineId: const PolylineId('trip'),
                  points: visibleRoute.points,
                  color: AppColors.blueDeep,
                  width: 5,
                ),
            },
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.52,
          ),
          child: SingleChildScrollView(
            child: _TrackingPanel(
              ride: ride,
              eta: visibleRoute?.durationLabel,
              status: status,
              driver: driver,
              pickupAddress: widget.pickupAddress,
              dropoffAddress: widget.dropoffAddress,
              bookingReference:
                  ride['booking_reference'] as String? ??
                  widget.bookingReference,
              reservationType:
                  ride['reservation_type'] as String? ?? widget.reservationType,
              seatNumber: ride['seat_number'] as String? ?? widget.seatNumber,
              seatNumbers: BookingSummary.seats(ride),
              onCancel: status == 'requested' ? _cancelRide : null,
              onDone: status == 'completed' || status == 'cancelled'
                  ? () => Navigator.of(context).pop()
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackingPanel extends StatelessWidget {
  const _TrackingPanel({
    required this.ride,
    required this.status,
    required this.driver,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.bookingReference,
    required this.reservationType,
    required this.seatNumber,
    required this.seatNumbers,
    required this.onCancel,
    required this.onDone,
    this.eta,
  });
  final Map<String, dynamic> ride;
  final String status;
  final Map<String, dynamic>? driver;
  final String pickupAddress, dropoffAddress;
  final String? bookingReference, reservationType, seatNumber, eta;
  final List<String>? seatNumbers;
  final VoidCallback? onCancel, onDone;
  String get title => status == 'in_progress'
      ? 'Heading to your destination'
      : status == 'requested'
      ? (ride['vehicle_type'] == 'bus'
            ? 'Reservation requested'
            : 'Finding your driver')
      : status == 'cancelled'
      ? 'Ride cancelled'
      : 'Driver on the way';
  Future<void> _contact(BuildContext context, bool sms) async {
    final phone = driver?['phone']?.toString().replaceAll(
      RegExp(r'[^+0-9]'),
      '',
    );
    if (phone == null || phone.isEmpty) {
      boardInfo(
        context,
        'Contact driver',
        'Contact details are not available yet.',
      );
      return;
    }
    try {
      final opened = await launchUrl(
        Uri(scheme: sms ? 'sms' : 'tel', path: phone),
      );
      if (!opened && context.mounted) {
        boardInfo(
          context,
          'Contact driver',
          'You can contact your driver at $phone.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        boardInfo(
          context,
          'Contact driver',
          'You can contact your driver at $phone.',
        );
      }
    }
  }

  void _share(BuildContext context) {
    final text =
        '${BookingSummary.text(ride)}${driver == null ? '' : '\nDriver: ${driver!['full_name'] ?? ''}\nContact: ${driver!['phone'] ?? ''}'}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share Trip',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Copy these details and send them to someone you trust.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              SelectableText(text),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Trip details copied.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy trip details'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = driver?['full_name'] as String? ?? 'Your driver';
    final plate = driver?['vehicle_plate'] as String?;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8DDE7),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              status == 'requested'
                  ? 'We’ll update you when your request is accepted.'
                  : eta != null
                  ? 'Estimated travel time: $eta'
                  : 'Follow your journey on the map.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            if (driver != null)
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppColors.blueTint,
                    child: Text(
                      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.blueDeep,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
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
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          plate ?? 'Your matched driver',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.blueTint,
                      foregroundColor: AppColors.blueDeep,
                    ),
                    onPressed: () => _contact(context, false),
                    icon: const Icon(Icons.call, size: 20),
                  ),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.blueTint,
                      foregroundColor: AppColors.blueDeep,
                    ),
                    onPressed: () => _contact(context, true),
                    icon: const Icon(Icons.chat_bubble, size: 20),
                  ),
                ],
              ),
            if (status == 'requested')
              const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 16),
            Row(
              children: [
                if (onCancel != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Cancel Ride'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () => _share(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Share Trip'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            BoardCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Column(
                children: [
                  RouteRow(title: 'Pickup location', value: pickupAddress),
                  const Divider(height: 1, indent: 36),
                  RouteRow(
                    title: 'Destination',
                    value: dropoffAddress,
                    destination: true,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Fare', style: TextStyle(fontSize: 12)),
                        ),
                        Text(
                          ugx(ride['fare_ugx']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Payment method',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        Text('Cash', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (bookingReference != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '$bookingReference${reservationType == 'whole_bus'
                      ? ' · Whole bus'
                      : (seatNumbers?.isNotEmpty ?? false)
                      ? ' · Seats ${seatNumbers!.join(', ')}'
                      : ''}',
                  style: const TextStyle(
                    color: AppColors.blueDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            TextButton(
              onPressed: () =>
                  boardInfo(context, 'Your booking', BookingSummary.text(ride)),
              child: const Text('View booking details'),
            ),
            if (status == 'in_progress')
              FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Need to end your trip?',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Ask your driver to stop somewhere safe and confirm the trip has ended. If something is wrong, send a support request. For urgent help, contact local emergency services directly.',
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const SupportRequestScreen(
                                    category: 'ride_issue',
                                    title: 'Trip help',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Request help'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('End Trip'),
              ),
            if (onDone != null)
              FilledButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}
