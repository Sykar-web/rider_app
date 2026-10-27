import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../services/ride_service.dart';
import '../../services/delivery_service.dart';
import '../../services/location_service.dart';
import '../../services/route_service.dart';
import '../../widgets/driver_board.dart';

class DriverJobScreen extends StatefulWidget {
  const DriverJobScreen({
    super.key,
    required this.job,
    required this.delivery,
    this.position,
    this.onAccept,
  });
  final Map<String, dynamic> job;
  final bool delivery;
  final LatLng? position;
  final Future<bool> Function()? onAccept;
  @override
  State<DriverJobScreen> createState() => _DriverJobScreenState();
}

class _DriverJobScreenState extends State<DriverJobScreen> {
  late Stream<Map<String, dynamic>?> _stream;
  late Map<String, dynamic> _job;
  Map<String, dynamic>? _passenger;
  StreamSubscription<Position>? _gps;
  LatLng? _position, _lastTarget;
  GoogleMapController? _map;
  RouteResult? _route;
  bool _busy = false, _routing = false, _routeFailed = false;
  DateTime? _lastRoute;
  String? _profileId;
  String? _pendingStatus;
  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _position = widget.position;
    _stream = widget.delivery
        ? DeliveryService().watchDelivery(_job['id'])
        : RideService().watchRide(_job['id']);
    _gps = LocationService().positionStream().listen(
      (p) {
        if (mounted) {
          setState(() => _position = LatLng(p.latitude, p.longitude));
        }
      },
      onError: (_) {
        if (mounted) {
          driverInfo(
            context,
            'Location paused',
            'Enable location access to continue live navigation.',
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _gps?.cancel();
    _map?.dispose();
    super.dispose();
  }

  LatLng point(String prefix) => LatLng(
    (_job['${prefix}_lat'] as num).toDouble(),
    (_job['${prefix}_lng'] as num).toDouble(),
  );
  Future<void> _loadPassenger(String? id) async {
    if (id == null || id == _profileId) return;
    _profileId = id;
    try {
      final profile = await RideService().getProfileById(id);
      if (mounted && _profileId == id) setState(() => _passenger = profile);
    } catch (_) {
      /* Never substitute invented passenger details. */
    }
  }

  Future<void> _directions(LatLng start, LatLng end) async {
    if (_routing) return;
    if (_lastTarget == end &&
        _lastRoute != null &&
        DateTime.now().difference(_lastRoute!).inSeconds < 30) {
      return;
    }
    if (_lastTarget != end) _route = null;
    _routing = true;
    _lastTarget = end;
    _lastRoute = DateTime.now();
    try {
      final route = await RouteService().getRoute(
        start,
        end,
        vehicleType: _job['vehicle_type'] ?? 'car',
      );
      if (mounted) {
        setState(() {
          _route = route;
          _routeFailed = false;
        });
        _fit(route.points);
      }
    } catch (_) {
      if (mounted) setState(() => _routeFailed = true);
    } finally {
      _routing = false;
    }
  }

  void _fit(List<LatLng> points) {
    if (points.isEmpty) return;
    var minLat = points.first.latitude,
        maxLat = minLat,
        minLng = points.first.longitude,
        maxLng = minLng;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    if (minLat == maxLat && minLng == maxLng) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(points.first, 16));
      return;
    }
    _map?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        55,
      ),
    );
  }

  Future<void> _contact(bool sms) async {
    final phone = (_passenger?['phone'] ?? '').toString().replaceAll(
      RegExp(r'[^+0-9]'),
      '',
    );
    if (phone.isEmpty) {
      driverInfo(
        context,
        'Contact details',
        'Contact details become available after acceptance when the passenger has supplied a phone number.',
      );
      return;
    }
    try {
      if (!await launchUrl(Uri(scheme: sms ? 'sms' : 'tel', path: phone))) {
        throw StateError('No handler');
      }
    } catch (_) {
      if (mounted) {
        driverInfo(context, 'Contact passenger', 'Call or message $phone.');
      }
    }
  }

  Future<void> _navigate(LatLng target) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${target.latitude},${target.longitude}',
      'travelmode': _job['vehicle_type'] == 'bicycle' ? 'bicycling' : 'driving',
      'dir_action': 'navigate',
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('No maps');
      }
    } catch (_) {
      if (mounted) {
        driverInfo(
          context,
          'Maps unavailable',
          'Could not open Google Maps. Use the road route shown here and try again.',
        );
      }
    }
  }

  Future<void> _advance(String status) async {
    if (_busy) return;
    final next = widget.delivery
        ? switch (status) {
            'accepted' => 'picked_up',
            'picked_up' => 'in_progress',
            'in_progress' => 'completed',
            _ => null,
          }
        : switch (status) {
            'accepted' => 'arriving',
            'arriving' => 'in_progress',
            'in_progress' => 'completed',
            _ => null,
          };
    if (next == null) return;
    if (!await driverConfirm(
      context,
      next == 'completed'
          ? 'End this trip?'
          : next == 'in_progress'
          ? 'Start this trip?'
          : 'Confirm arrival / pickup?',
      next == 'completed'
          ? 'Confirm the journey has ended and agree the cash fare with your customer.'
          : 'Confirm you are at the correct stage before continuing.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      if (widget.delivery) {
        await DeliveryService().updateDeliveryStatus(_job['id'], next);
      } else {
        await RideService().updateRideStatus(_job['id'], next);
      }
      if (mounted) {
        setState(() {
          _pendingStatus = next;
          _job = {..._job, 'status': next};
        });
      }
    } catch (_) {
      if (mounted) {
        driverInfo(
          context,
          'Trip not updated',
          'Check your connection and try again. The trip may already have changed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.delivery ? 'Delivery details' : 'Passenger details'),
      centerTitle: true,
    ),
    body: StreamBuilder<Map<String, dynamic>?>(
      stream: _stream,
      initialData: _job,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return DriverEmpty(
            title: 'Trip unavailable',
            message: 'Check your connection and reload this trip.',
            onRetry: () => setState(
              () => _stream = widget.delivery
                  ? DeliveryService().watchDelivery(_job['id'])
                  : RideService().watchRide(_job['id']),
            ),
          );
        }
        if (snapshot.data != null &&
            (_pendingStatus == null ||
                snapshot.data!['status'] == 'cancelled' ||
                snapshot.data!['status'] == _pendingStatus)) {
          _job = snapshot.data!;
          _pendingStatus = null;
        }
        final status = _job['status'] ?? 'requested';
        if (status != 'requested' &&
            status != 'cancelled' &&
            _job[widget.delivery ? 'courier_id' : 'driver_id'] !=
                Supabase.instance.client.auth.currentUser?.id) {
          return const DriverEmpty(
            title: 'Request unavailable',
            message: 'This request is assigned to another driver. Return Home for available jobs.',
          );
        }
        if (status == 'completed') {
          return DriverTripCompleted(
            job: _job,
            onHome: () => Navigator.pop(context),
          );
        }
        if (status == 'cancelled') {
          return const DriverEmpty(
            title: 'Booking cancelled',
            message: 'This request is no longer active. Return Home to find another trip.',
          );
        }
        final pickup = point('pickup'), dropoff = point('dropoff');
        final underway = status == 'in_progress' || status == 'picked_up';
        final target = underway || status == 'requested' ? dropoff : pickup;
        final start = status == 'requested' ? pickup : _position;
        if (start != null) _directions(start, target);
        if (status != 'requested') {
          _loadPassenger(
            (_job[widget.delivery ? 'sender_id' : 'passenger_id']) as String?,
          );
        }
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _position ?? pickup,
                      zoom: 14,
                    ),
                    onMapCreated: (c) {
                      _map = c;
                      _fit(_route?.points ?? [pickup, dropoff]);
                    },
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationEnabled: _position != null,
                    markers: {
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: pickup,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure,
                        ),
                      ),
                      Marker(
                        markerId: const MarkerId('destination'),
                        position: dropoff,
                      ),
                      if (_position != null)
                        Marker(
                          markerId: const MarkerId('driver'),
                          position: _position!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                        ),
                    },
                    polylines: {
                      if (_route != null)
                        Polyline(
                          polylineId: const PolylineId('road-route'),
                          points: _lastTarget == target
                              ? _route!.points
                              : const <LatLng>[],
                          color: AppColors.blueDeep,
                          width: 5,
                        ),
                    },
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: DriverCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.navigation_rounded,
                            color: AppColors.blueDeep,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              status == 'requested'
                                  ? 'New ${widget.delivery ? 'delivery' : 'ride'} request'
                                  : underway
                                  ? 'On trip'
                                  : 'Go to pickup',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (_route != null)
                            Text(
                              '${_route!.durationLabel} · ${_route!.distanceLabel}',
                              style: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_routeFailed)
                    Positioned(
                      bottom: 8,
                      left: 16,
                      right: 16,
                      child: DriverCard(
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Road route unavailable. Check your connection.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _lastRoute = null;
                                if (start != null) _directions(start, target);
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .5,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (status != 'requested')
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppColors.blueTint,
                              child: Icon(
                                Icons.person_outline,
                                color: AppColors.blueDeep,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _passenger?['full_name'] ??
                                    (widget.delivery
                                        ? 'Your customer'
                                        : 'Your passenger'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Call customer',
                              onPressed: () => _contact(false),
                              icon: const Icon(
                                Icons.call_outlined,
                                color: AppColors.blueDeep,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Message customer',
                              onPressed: () => _contact(true),
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                color: AppColors.blueDeep,
                              ),
                            ),
                          ],
                        ),
                      DriverRouteRows(job: _job),
                      if (_job['rider_note'] != null || _job['notes'] != null)
                        Text(
                          'Customer note: ${_job['rider_note'] ?? _job['notes']}',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              money(_job['fare_ugx']),
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                color: AppColors.blueDeep,
                              ),
                            ),
                          ),
                          const Chip(label: Text('Cash')),
                        ],
                      ),
                      if (status == 'requested') ...[
                        FilledButton(
                          onPressed: _busy || widget.onAccept == null
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    final accepted = await widget.onAccept!();
                                    if (mounted && accepted) {
                                      setState(() {
                                        _pendingStatus = 'accepted';
                                        _job = {
                                          ..._job,
                                          'status': 'accepted',
                                          (widget.delivery
                                              ? 'courier_id'
                                              : 'driver_id'): Supabase
                                              .instance
                                              .client
                                              .auth
                                              .currentUser!
                                              .id,
                                        };
                                      });
                                    }
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          child: Text(_busy ? 'Confirming…' : 'Accept'),
                        ),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context, 'declined'),
                          child: const Text(
                            'Decline',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          onPressed: () => _navigate(target),
                          icon: const Icon(Icons.navigation_outlined),
                          label: const Text('Open in Maps'),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          style: underway
                              ? FilledButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                )
                              : null,
                          onPressed: _busy ? null : () => _advance(status),
                          child: Text(
                            _busy
                                ? 'Updating…'
                                : status == 'accepted'
                                ? (widget.delivery
                                      ? 'Confirm package pickup'
                                      : 'I have arrived')
                                : status == 'arriving' || status == 'picked_up'
                                ? (widget.delivery
                                      ? 'Start delivery'
                                      : 'Start trip')
                                : 'End trip',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class DriverTripCompleted extends StatelessWidget {
  const DriverTripCompleted({
    super.key,
    required this.job,
    required this.onHome,
  });
  final Map<String, dynamic> job;
  final VoidCallback onHome;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 36),
      const CircleAvatar(
        radius: 45,
        backgroundColor: AppColors.blueDeep,
        child: Icon(Icons.check_rounded, color: Colors.white, size: 58),
      ),
      const SizedBox(height: 24),
      const Text(
        'Trip Completed!',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 27,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Great job! Your trip has been completed.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted),
      ),
      const SizedBox(height: 30),
      DriverCard(
        child: Column(
          children: [
            ListTile(
              title: const Text('Fare'),
              trailing: Text(
                money(job['fare_ugx']),
                style: const TextStyle(
                  color: AppColors.blueDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (job['distance_km'] != null)
              ListTile(
                title: const Text('Distance'),
                trailing: Text('${job['distance_km']} km'),
              ),
            const ListTile(
              title: Text('Payment method'),
              trailing: Text('Cash'),
            ),
            const Text(
              'Cash is collected directly from your customer. This is not a wallet credit.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 30),
      FilledButton(onPressed: onHome, child: const Text('Go to Home')),
    ],
  );
}
