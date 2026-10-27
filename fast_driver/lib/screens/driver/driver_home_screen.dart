import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/theme.dart';
import '../../services/driver_account_service.dart';
import '../../widgets/driver_board.dart';
import 'driver_pages.dart';
import 'driver_job_screen.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/ride_service.dart';
import '../../services/delivery_service.dart';

enum _JobType { ride, delivery }

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
    this.accountService,
    this.rideService,
    this.deliveryService,
  });
  final DriverAccountService? accountService;
  final RideService? rideService;
  final DeliveryService? deliveryService;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  late final RideService _rideService;
  late final DeliveryService _deliveryService;
  final _authService = AuthService();
  final _locationService = LocationService();

  late final TabController _tabController;
  StreamSubscription<Position>? _positionSubscription;
  int _navigationIndex = 0;
  late Future<List<Map<String, dynamic>>> _jobs;
  late final DriverAccountService _account;
  late Stream<List<Map<String, dynamic>>> _openRidesStream,
      _openDeliveriesStream;
  Map<String, dynamic> _profile = {};
  final Set<String> _declined = {};
  void _refreshAccount() {
    setState(() {
      _jobs = _account.jobs();
    });
    _jobs.then((_) {}, onError: (Object e, StackTrace s) {});
    _account
        .profile()
        .then((value) {
          if (mounted) {
            setState(() {
              _profile = value;
              _isOnline = value['is_online'] == true;
            });
            if ((_isOnline || _activeJobId != null) &&
                _positionSubscription == null) {
              _restoreTracking();
            }
          }
        })
        .catchError((Object e) {});
  }

  void _page(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  bool _recoveringJob = true;
  bool _recoveryFailed = false;
  bool _acceptingJob = false;
  bool _isOnline = false;
  bool _updatingStatus = false;
  double? _driverLat;
  double? _driverLng;

  _JobType? _activeJobType;
  String? _activeJobId;

  @override
  void initState() {
    super.initState();
    _rideService = widget.rideService ?? RideService();
    _deliveryService = widget.deliveryService ?? DeliveryService();
    _account = widget.accountService ?? DriverAccountService();
    _openRidesStream = _rideService.watchOpenRides();
    _openDeliveriesStream = _deliveryService.watchOpenDeliveries();
    _tabController = TabController(length: 2, vsync: this);
    _refreshAccount();
    _restoreActiveJob();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleOnline(bool value) async {
    if (!value && _activeJobId != null) {
      driverInfo(
        context,
        'Active trip',
        'Complete your trip before going offline.',
      );
      return;
    }
    setState(() => _updatingStatus = true);
    try {
      if (value) {
        final position = await _locationService.getCurrentPosition();
        _driverLat = position.latitude;
        _driverLng = position.longitude;
        _startLocationTracking();
      } else {
        await _positionSubscription?.cancel();
        _positionSubscription = null;
      }
      await _rideService.setOnline(value, lat: _driverLat, lng: _driverLng);
      if (mounted) setState(() => _isOnline = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not change status. Check your connection and location access.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _restoreTracking() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _driverLat = position.latitude;
        _driverLng = position.longitude;
      });
      await _rideService.updateDriverLocation(
        position.latitude,
        position.longitude,
      );
      _startLocationTracking();
    } catch (_) {
      /* Online switch and Continue trip offer GPS retry. */
    }
  }

  void _startLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = _locationService.positionStream().listen((
      position,
    ) {
      if (!mounted ||
          (!_isOnline && !_updatingStatus && _activeJobId == null)) {
        return;
      }
      setState(() {
        _driverLat = position.latitude;
        _driverLng = position.longitude;
      });
      _rideService
          .updateDriverLocation(position.latitude, position.longitude)
          .catchError((Object e) {});
    });
  }

  Future<void> _restoreActiveJob() async {
    setState(() {
      _recoveringJob = true;
      _recoveryFailed = false;
    });
    try {
      final jobs = await Future.wait([
        _rideService.getActiveRide(),
        _deliveryService.getActiveDelivery(),
      ]);
      if (!mounted) return;
      final ride = jobs[0];
      final delivery = jobs[1];
      final useRide =
          ride != null &&
          (delivery == null ||
              (ride['accepted_at'] as String? ?? '').compareTo(
                    delivery['accepted_at'] as String? ?? '',
                  ) <=
                  0);
      setState(() {
        _activeJobType = useRide
            ? _JobType.ride
            : delivery != null
            ? _JobType.delivery
            : null;
        _activeJobId = (useRide ? ride : delivery)?['id'] as String?;
      });
    } catch (_) {
      if (mounted) setState(() => _recoveryFailed = true);
    } finally {
      if (mounted) setState(() => _recoveringJob = false);
    }
  }

  Future<void> _acceptJob(_JobType type, String id) async {
    if (_acceptingJob ||
        _recoveringJob ||
        _recoveryFailed ||
        _activeJobId != null) {
      return;
    }
    setState(() => _acceptingJob = true);
    try {
      final accepted = type == _JobType.ride
          ? await _rideService.acceptRide(id)
          : await _deliveryService.acceptDelivery(id);
      if (!mounted) return;
      if (!accepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This request is no longer available.')),
        );
        return;
      }
      setState(() {
        _activeJobType = type;
        _activeJobId = id;
      });
    } catch (_) {
      if (!mounted) return;
      // A lost response may still mean the server accepted the job.
      await _restoreActiveJob();
      if (!mounted) return;
      if (_activeJobId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not confirm acceptance. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acceptingJob = false);
    }
  }

  Future<void> _resumeActive() async {
    try {
      final delivery = _activeJobType == _JobType.delivery;
      final job = delivery
          ? await _deliveryService.getActiveDelivery()
          : await _rideService.getActiveRide();
      if (!mounted) return;
      if (job == null) {
        await _restoreActiveJob();
        return;
      }
      try {
        final p = await _locationService.getCurrentPosition();
        _driverLat = p.latitude;
        _driverLng = p.longitude;
        _startLocationTracking();
      } catch (_) {}
      if (mounted) await _openRequest(job, delivery);
    } catch (_) {
      if (mounted) {
        driverInfo(
          context,
          'Trip unavailable',
          'Check your connection and try again.',
        );
      }
    }
  }

  Future<void> _openRequest(Map<String, dynamic> job, bool delivery) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => DriverJobScreen(
          job: job,
          delivery: delivery,
          position: _driverPosition,
          onAccept: () async {
            await _acceptJob(
              delivery ? _JobType.delivery : _JobType.ride,
              job['id'],
            );
            return _activeJobId == job['id'];
          },
        ),
      ),
    );
    if (result == 'declined') _declined.add(job['id']);
    if (mounted) {
      _refreshAccount();
      await _restoreActiveJob();
    }
  }

  Future<void> _logout() async {
    if (_activeJobId != null) {
      driverInfo(
        context,
        'Active trip',
        'Complete your trip before signing out.',
      );
      return;
    }
    if (!await driverConfirm(
      context,
      'Log out?',
      'You will go offline and sign out of FastDriver.',
    )) {
      return;
    }
    try {
      await _rideService.setOnline(false);
      await _authService.signOut();
    } catch (_) {
      if (mounted) {
        driverInfo(
          context,
          'Could not log out',
          'Check your connection and try again.',
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveJob = _activeJobId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          [
            'FastDriver',
            'Earnings',
            'Ride History',
            'My Profile',
          ][_navigationIndex],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _page(DriverNotifications.fromFuture(jobs: _jobs)),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => _page(DriverSettings(onLogout: _logout)),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: _navigationIndex == 0
          ? _buildDashboard(hasActiveJob)
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _jobs,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return DriverEmpty(
                    title: 'Unable to load your records',
                    message: 'Check your connection and try again.',
                    onRetry: _refreshAccount,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return switch (_navigationIndex) {
                  1 => DriverEarnings(
                    jobs: snapshot.data!,
                    onRefresh: () async {
                      _refreshAccount();
                      await _jobs;
                    },
                  ),
                  2 => DriverHistory(
                    jobs: snapshot.data!,
                    onRefresh: () async {
                      _refreshAccount();
                      await _jobs;
                    },
                    onOpen: (job) => _page(DriverJobReceipt(job: job)),
                  ),
                  _ => DriverProfile(
                    profile: _profile,
                    onChanged: () async {
                      _refreshAccount();
                    },
                    onLogout: _logout,
                  ),
                };
              },
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navigationIndex,
        onDestinationSelected: (i) {
          setState(() => _navigationIndex = i);
          _refreshAccount();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(bool hasActiveJob) {
    if (_recoveringJob) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking for an unfinished trip...'),
          ],
        ),
      );
    }
    if (_recoveryFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not check your current trip.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _restoreActiveJob,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          decoration: BoxDecoration(
            color: _isOnline ? AppColors.success : AppColors.field,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Icon(
                _isOnline ? Icons.near_me : Icons.wifi_off,
                color: _isOnline ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _isOnline ? Colors.white : AppColors.navy,
                  ),
                ),
              ),
              if (_updatingStatus)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: _isOnline,
                  onChanged: _toggleOnline,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.success,
                ),
            ],
          ),
        ),
        if (!hasActiveJob) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _jobs,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Earnings unavailable. Refresh to retry.');
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final totals = DriverTotals(snapshot.data!);
                return DriverCard(
                  color: AppColors.blueTint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, ${_profile['full_name'] ?? 'Driver'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.blueDeep,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Today's recorded fares",
                                  style: TextStyle(
                                    color: AppColors.blueDeep,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  money(totals.gross),
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.blueDeep,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${totals.count} trips',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _navigationIndex = 1),
                            child: const Text('Earnings'),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _navigationIndex = 2),
                            child: const Text('History'),
                          ),
                          TextButton(
                            onPressed: () => _page(const DriverWallet()),
                            child: const Text('Wallet'),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _navigationIndex = 3),
                            child: const Text('Profile'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isOnline) SizedBox(height: 130, child: _buildMapHeader()),
          if (_isOnline)
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Ride requests'),
                Tab(text: 'Deliveries'),
              ],
            ),
        ],
        const Divider(height: 1, color: AppColors.hairline),
        Expanded(
          child: hasActiveJob
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: DriverCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.navigation_rounded,
                            size: 54,
                            color: AppColors.blueDeep,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your trip is active',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Continue navigation, contact your customer or update trip status.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _resumeActive,
                            child: const Text('Continue trip'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : (_isOnline
                    ? TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOpenRidesList(),
                          _buildOpenDeliveriesList(),
                        ],
                      )
                    : _buildOfflineMessage()),
        ),
      ],
    );
  }

  LatLng? get _driverPosition => _driverLat == null || _driverLng == null
      ? null
      : LatLng(_driverLat!, _driverLng!);

  Widget _buildMapHeader() {
    final position = _driverPosition;
    return SizedBox(
      height: 210,
      child: position == null
          ? Container(
              color: const Color(0xFFE5F4FD),
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 42, color: AppColors.blueDeep),
                  SizedBox(height: 8),
                  Text('Go online to show your live position'),
                ],
              ),
            )
          : GoogleMap(
              initialCameraPosition: CameraPosition(target: position, zoom: 15),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: {
                Marker(
                  markerId: const MarkerId('driver'),
                  position: position,
                  infoWindow: const InfoWindow(title: 'Your live location'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure,
                  ),
                ),
              },
            ),
    );
  }

  Widget _buildOfflineMessage() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _jobs,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return DriverEmpty(
            title: 'Activity unavailable',
            message: 'Check your connection and try again.',
            onRetry: _refreshAccount,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const DriverEmpty(
                title: 'Ready when you are',
                message: 'Go online to receive ride and delivery requests. Your trips will appear here.',
              ),
            for (final job in rows.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DriverCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      job['_delivery'] == true
                          ? Icons.inventory_2_outlined
                          : Icons.route,
                      color: AppColors.blueDeep,
                    ),
                    title: Text(
                      job['dropoff_address'] ?? 'Destination',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${(job['status'] ?? '').toString().replaceAll('_', ' ')}\n${jobDate(job)}',
                    ),
                    trailing: Text(
                      money(job['fare_ugx']),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => _page(DriverJobReceipt(job: job)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOpenRidesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _openRidesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return DriverEmpty(
            title: 'Requests unavailable',
            message: 'Check your connection and try again.',
            onRetry: () => setState(() {
              _openRidesStream = _rideService.watchOpenRides();
              _openDeliveriesStream = _deliveryService.watchOpenDeliveries();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var rides = snapshot.data!.where((job) {
          final scheduled = DateTime.tryParse(
            (job['scheduled_at'] ?? '').toString(),
          );
          return !_declined.contains(job['id']) &&
              (scheduled == null || !scheduled.isAfter(DateTime.now())) &&
              (_profile['vehicle_type'] == null ||
                  job['vehicle_type'] == null ||
                  job['vehicle_type'] == _profile['vehicle_type']);
        }).toList();
        if (_driverLat != null && _driverLng != null) {
          rides = [...rides]
            ..sort(
              (a, b) =>
                  RideService.distanceKm(
                    _driverLat!,
                    _driverLng!,
                    a['pickup_lat'],
                    a['pickup_lng'],
                  ).compareTo(
                    RideService.distanceKm(
                      _driverLat!,
                      _driverLng!,
                      b['pickup_lat'],
                      b['pickup_lng'],
                    ),
                  ),
            );
        }
        if (rides.isEmpty) {
          return const Center(
            child: Text(
              'No ride requests nearby right now.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rides.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final ride = rides[index];
            final distance = (_driverLat != null && _driverLng != null)
                ? RideService.distanceKm(
                    _driverLat!,
                    _driverLng!,
                    ride['pickup_lat'],
                    ride['pickup_lng'],
                  )
                : null;
            return _RequestCard(
              fare: ride['fare_ugx'],
              vehicleType: ride['vehicle_type'] as String?,
              pickupIcon: Icons.radio_button_checked,
              pickup: ride['pickup_address'] ?? 'Pickup location',
              dropoff: ride['dropoff_address'] ?? 'Dropoff location',
              distanceKm: distance,
              onAccept: _acceptingJob ? null : () => _openRequest(ride, false),
            );
          },
        );
      },
    );
  }

  Widget _buildOpenDeliveriesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _openDeliveriesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return DriverEmpty(
            title: 'Requests unavailable',
            message: 'Check your connection and try again.',
            onRetry: () => setState(() {
              _openRidesStream = _rideService.watchOpenRides();
              _openDeliveriesStream = _deliveryService.watchOpenDeliveries();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var deliveries = snapshot.data!
            .where((job) => !_declined.contains(job['id']))
            .toList();
        if (_driverLat != null && _driverLng != null) {
          deliveries = [...deliveries]
            ..sort(
              (a, b) =>
                  DeliveryService.distanceKm(
                    _driverLat!,
                    _driverLng!,
                    a['pickup_lat'],
                    a['pickup_lng'],
                  ).compareTo(
                    DeliveryService.distanceKm(
                      _driverLat!,
                      _driverLng!,
                      b['pickup_lat'],
                      b['pickup_lng'],
                    ),
                  ),
            );
        }
        if (deliveries.isEmpty) {
          return const Center(
            child: Text(
              'No delivery requests nearby right now.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: deliveries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final delivery = deliveries[index];
            final distance = (_driverLat != null && _driverLng != null)
                ? DeliveryService.distanceKm(
                    _driverLat!,
                    _driverLng!,
                    delivery['pickup_lat'],
                    delivery['pickup_lng'],
                  )
                : null;
            return _RequestCard(
              fare: delivery['fare_ugx'],
              vehicleType: delivery['vehicle_type'] as String?,
              pickupIcon: Icons.inventory_2_outlined,
              pickup: delivery['pickup_address'] ?? 'Pickup location',
              dropoff: delivery['dropoff_address'] ?? 'Dropoff location',
              distanceKm: distance,
              onAccept: _acceptingJob
                  ? null
                  : () => _openRequest(delivery, true),
            );
          },
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final String? vehicleType;
  final Object? fare;
  final IconData pickupIcon;
  final String pickup;
  final String dropoff;
  final double? distanceKm;
  final VoidCallback? onAccept;

  const _RequestCard({
    required this.vehicleType,
    this.fare,
    required this.pickupIcon,
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vehicleType != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD8F0FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _vehicleLabel(vehicleType!),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.blueDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (distanceKm != null)
            Text(
              '${distanceKm!.toStringAsFixed(1)} km to pickup (approx.)',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.blueDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(pickupIcon, size: 15, color: AppColors.blueLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pickup,
                  style: const TextStyle(fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.location_on,
                size: 15,
                color: AppColors.blueDeep,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dropoff,
                  style: const TextStyle(fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            money(fare),
            style: const TextStyle(
              color: AppColors.blueDeep,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: onAccept,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(onAccept == null ? 'Confirming...' : 'View request'),
          ),
        ],
      ),
    );
  }

  String _vehicleLabel(String value) => switch (value) {
    'motorcycle' => 'Motorcycle',
    'tuktuk' => 'Tuk Tuk',
    'bicycle' => 'Bicycle',
    'van' => 'Van',
    'bus' => 'Bus',
    _ => 'Car',
  };
}
