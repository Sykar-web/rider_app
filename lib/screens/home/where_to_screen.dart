import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/theme.dart';
import '../../services/location_service.dart';
import '../../services/ride_service.dart';
import '../../services/delivery_service.dart';
import '../../services/route_service.dart';
import 'searching_screen.dart';
import 'delivery_searching_screen.dart';
import 'ride_booking_details_sheet.dart';
import 'location_search_screen.dart';
import '../account/payment_methods_screen.dart';

enum TripMode { ride, delivery }

class WhereToScreen extends StatefulWidget {
  final String vehicleType;
  final TripMode initialMode;
  final DateTime? scheduledAt;
  final bool shared;
  final PlaceResult? initialDestination;
  final PlaceResult? initialPickup;

  final VoidCallback? onChangeVehicle;
  const WhereToScreen({
    super.key,
    required this.vehicleType,
    this.onChangeVehicle,
    this.initialMode = TripMode.ride,
    this.scheduledAt,
    this.shared = false,
    this.initialDestination,
    this.initialPickup,
  });

  @override
  State<WhereToScreen> createState() => _WhereToScreenState();
}

class _WhereToScreenState extends State<WhereToScreen> {
  final _locationService = LocationService();
  final _rideService = RideService();
  final _deliveryService = DeliveryService();
  final _routeService = RouteService();

  // Set once GoogleMap finishes initializing (onMapCreated). Used for
  // camera moves (recenter, fitBounds) in place of flutter_map's MapController.
  GoogleMapController? _mapController;

  TripMode _mode = TripMode.ride;
  Set<Polyline> _polylines = {};
  bool _loadingRoute = false;
  bool _resolvingPin = false;
  bool _confirming = false;
  bool _collectingDetails = false;
  late String _vehicleType;
  RouteResult? _route;
  final _packageNotes = TextEditingController();
  String _packageType = 'document';
  int _routeGeneration = 0;
  int _pinGeneration = 0;
  bool _ridePickupReady = false;

  // Ride mode fields
  final _fromController = TextEditingController(); // GPS-filled, editable
  final _toController = TextEditingController();
  final FocusNode _toFocusNode = FocusNode();
  LatLng? _destinationPosition;

  // Delivery mode fields (both freely typed, not GPS auto-filled)
  final _pickupController = TextEditingController();
  final _deliveryController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _deliveryFocusNode = FocusNode();
  LatLng? _pickupPosition;
  LatLng? _deliveryPosition;

  // Shared search state — whichever field the user is typing in
  String? _activeField; // 'to' | 'pickup' | 'delivery'
  List<PlaceResult> _suggestions = [];
  bool _searching = false;
  Timer? _debounce;
  int _searchGeneration = 0;

  LatLng? _currentPosition;
  bool _loadingLocation = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _vehicleType = widget.vehicleType;
    _mode = widget.initialMode;
    _initLocation().then((_) async {
      if (mounted && widget.initialDestination != null) {
        _activeField = 'to';
        await _selectSuggestion(widget.initialDestination!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant WhereToScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicleType != widget.vehicleType) {
      _vehicleType = widget.vehicleType;
      _polylines = {};
      final start = _mode == TripMode.ride ? _currentPosition : _pickupPosition;
      final end = _mode == TripMode.ride
          ? _destinationPosition
          : _deliveryPosition;
      if (start != null && end != null) _loadRoute(start, end);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController?.dispose();
    _packageNotes.dispose();
    _fromController.dispose();
    _toController.dispose();
    _toFocusNode.dispose();
    _pickupController.dispose();
    _deliveryController.dispose();
    _pickupFocusNode.dispose();
    _deliveryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final pickup = widget.initialPickup;
    if (pickup?.lat != null && pickup?.lon != null) {
      setState(() {
        _currentPosition = LatLng(pickup!.lat!, pickup.lon!);
        _fromController.text = pickup.displayName;
        _ridePickupReady = true;
        _loadingLocation = false;
        _locationError = null;
      });
      return;
    }
    try {
      final position = await _locationService.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      final address = await _locationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = latLng;
        _ridePickupReady = true;
        _fromController.text = address;
        _loadingLocation = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      // GoogleMap is only built once _currentPosition is set, and it uses
      // initialCameraPosition: CameraPosition(target: _currentPosition!, ...),
      // so it already starts centered correctly — no need to move the
      // camera here.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError =
            'Location access is unavailable. Choose your pickup manually.';
        _loadingLocation = false;
        _currentPosition = const LatLng(
          0.3476,
          32.5825,
        ); // Kampala, as a default
      });
    }
  }

  void _onFieldChanged(String field, String value, {bool expanded = false}) {
    final generation = ++_searchGeneration;
    _activeField = field;
    setState(() {
      switch (field) {
        case 'from':
          _ridePickupReady = false;
        case 'to':
          _destinationPosition = null;
        case 'pickup':
          _pickupPosition = null;
        case 'delivery':
          _deliveryPosition = null;
      }
      _routeGeneration++;
      _loadingRoute = false;
      _route = null;
      _polylines = {};
      _suggestions = [];
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      if (value.trim().length < 2) {
        if (mounted && generation == _searchGeneration) {
          setState(() {
            _suggestions = [];
            _searching = false;
          });
        }
        return;
      }
      setState(() => _searching = true);
      List<PlaceResult> results = [];
      try {
        results = await _locationService.searchPlaces(
          value,
          expanded: expanded,
        );
      } catch (_) {
        // A later keystroke can start a fresh request immediately.
      }
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      }
    });
  }

  Future<void> _selectSuggestion(PlaceResult suggestion) async {
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    setState(() {
      _searching = true;
      _suggestions = [];
    });
    PlaceResult? place;
    try {
      place = await _locationService.resolvePlace(suggestion);
    } catch (_) {
      place = null;
    }
    if (!mounted || generation != _searchGeneration) return;
    if (place == null || place.lat == null || place.lon == null) {
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load that place. Try again.')),
      );
      return;
    }
    final selectedPlace = place;
    final selectedPosition = LatLng(place.lat!, place.lon!);
    setState(() {
      switch (_activeField) {
        case 'from':
          _fromController.text = selectedPlace.displayName;
          _ridePickupReady = true;
          _currentPosition = selectedPosition;
          if (_destinationPosition != null) {
            _fitBounds(_currentPosition!, _destinationPosition!);
            _loadRoute(_currentPosition!, _destinationPosition!);
          }
        case 'to':
          _toController.text = selectedPlace.displayName;
          _destinationPosition = selectedPosition;
          if (_currentPosition != null) {
            _fitBounds(_currentPosition!, _destinationPosition!);
            _loadRoute(_currentPosition!, _destinationPosition!);
          }
        case 'pickup':
          _pickupController.text = selectedPlace.displayName;
          _pickupPosition = selectedPosition;
          if (_deliveryPosition != null) {
            _fitBounds(_pickupPosition!, _deliveryPosition!);
            _loadRoute(_pickupPosition!, _deliveryPosition!);
          }
        case 'delivery':
          _deliveryController.text = selectedPlace.displayName;
          _deliveryPosition = selectedPosition;
          if (_pickupPosition != null) {
            _fitBounds(_pickupPosition!, _deliveryPosition!);
            _loadRoute(_pickupPosition!, _deliveryPosition!);
          }
      }
      _suggestions = [];
      _searching = false;
    });
    _toFocusNode.unfocus();
    _pickupFocusNode.unfocus();
    _deliveryFocusNode.unfocus();
  }

  /// Fetches and draws the shortest available route between two points as
  /// soon as both ends of a trip are known — shown immediately on the map,
  /// before the user has even chosen a vehicle type.
  Future<void> _loadRoute(LatLng start, LatLng end) async {
    final generation = ++_routeGeneration;
    setState(() {
      _loadingRoute = true;
      _route = null;
    });
    try {
      final route = await _routeService.getRoute(
        start,
        end,
        vehicleType: _vehicleType,
      );
      if (mounted && generation == _routeGeneration) {
        setState(() {
          _route = route;
          _polylines = {
            Polyline(
              polylineId: const PolylineId('active_route'),
              points: route.points,
              width: 5,
              color: AppColors.blueDeep,
            ),
          };
        });
      }
    } catch (_) {
      // Route drawing is a visual aid — if it fails, the rest of the flow
      // (vehicle selection, matching) still works without it.
    } finally {
      if (mounted && generation == _routeGeneration) {
        setState(() => _loadingRoute = false);
      }
    }
  }

  void _fitBounds(LatLng a, LatLng b) {
    if (RideService.distanceKm(
          a.latitude,
          a.longitude,
          b.latitude,
          b.longitude,
        ) <
        .02) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(a, 16));
      return;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      ),
      northeast: LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      ),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  Future<void> _setDestinationFromMap(LatLng position) async {
    final generation = ++_pinGeneration;
    final mode = _mode;
    _toFocusNode.unfocus();
    _deliveryFocusNode.unfocus();
    setState(() {
      _suggestions = [];
      _polylines = {};
      _resolvingPin = true;
      if (mode == TripMode.ride) {
        _destinationPosition = position;
        _toController.text = 'Finding address…';
      } else {
        _deliveryPosition = position;
        _deliveryController.text = 'Finding address…';
      }
    });

    final start = mode == TripMode.ride ? _currentPosition : _pickupPosition;
    if (start != null) {
      _loadRoute(start, position);
    }

    try {
      final address = await _locationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (!mounted || generation != _pinGeneration) return;
      setState(() {
        final label = address == 'Current location'
            ? '${position.latitude.toStringAsFixed(5)}, '
                  '${position.longitude.toStringAsFixed(5)}'
            : address;
        if (mode == TripMode.ride) {
          _toController.text = label;
        } else {
          _deliveryController.text = label;
        }
      });
    } catch (_) {
      if (!mounted || generation != _pinGeneration) return;
      setState(() {
        final coordinates =
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}';
        if (mode == TripMode.ride) {
          _toController.text = coordinates;
        } else {
          _deliveryController.text = coordinates;
        }
      });
    } finally {
      if (mounted && generation == _pinGeneration) {
        setState(() => _resolvingPin = false);
      }
    }
  }

  Future<void> _handleGetRide() async {
    if (_confirming || _collectingDetails) return;
    if (_toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a destination first.')),
      );
      return;
    }
    if (!_ridePickupReady ||
        _currentPosition == null ||
        _destinationPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Waiting for your location and destination to be ready.',
          ),
        ),
      );
      return;
    }

    RideBookingDetails? booking;
    if (['car', 'van', 'bus'].contains(_vehicleType)) {
      _collectingDetails = true;
      try {
        booking = await showModalBottomSheet<RideBookingDetails>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => RideBookingDetailsSheet(vehicleType: _vehicleType),
        );
      } finally {
        _collectingDetails = false;
      }
      if (booking == null || !mounted) return;
    }

    setState(() => _confirming = true);
    try {
      final rideId = await _rideService.requestRide(
        pickupLat: _currentPosition!.latitude,
        pickupLng: _currentPosition!.longitude,
        pickupAddress: _fromController.text,
        dropoffLat: _destinationPosition!.latitude,
        dropoffLng: _destinationPosition!.longitude,
        dropoffAddress: _toController.text,
        vehicleType: _vehicleType,
        scheduledAt: widget.scheduledAt,
        requestType: widget.shared ? 'shared' : 'private',
        distanceKm: _route?.distanceKm,
        durationMinutes: _route?.durationMinutes,
        bookingDetails: booking?.details,
        bookingReference: booking?.reference,
        reservationType: booking?.reservationType,
        seatNumber: booking?.seatNumber,
        seatNumbers: booking?.seatNumbers,
        busScheduleId: booking?.busScheduleId,
        travelDate: booking?.travelDate,
        travelClass: booking?.travelClass,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SearchingScreen(
            initialRoute: _route,
            rideId: rideId,
            pickupAddress: _fromController.text,
            dropoffAddress: _toController.text,
            bookingReference: booking?.reference,
            reservationType: booking?.reservationType,
            seatNumber: booking?.seatNumber,
            seatNumbers: booking?.seatNumbers,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not reserve this trip. Check your connection and try again. For buses, your chosen seats may no longer be available.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _handleRequestDelivery() async {
    if (_confirming) return;
    if (_pickupController.text.trim().isEmpty ||
        _deliveryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter both a pickup and a delivery location.'),
        ),
      );
      return;
    }
    if (_pickupPosition == null || _deliveryPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a suggestion for both locations.'),
        ),
      );
      return;
    }

    setState(() => _confirming = true);
    try {
      final deliveryId = await _deliveryService.requestDelivery(
        pickupLat: _pickupPosition!.latitude,
        pickupLng: _pickupPosition!.longitude,
        pickupAddress: _pickupController.text,
        dropoffLat: _deliveryPosition!.latitude,
        dropoffLng: _deliveryPosition!.longitude,
        dropoffAddress: _deliveryController.text,
        vehicleType: _vehicleType,
        packageType: _packageType,
        packageNotes: _packageNotes.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeliverySearchingScreen(
            deliveryId: deliveryId,
            pickupAddress: _pickupController.text,
            dropoffAddress: _deliveryController.text,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not request delivery. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Set<Marker> _buildMarkers() {
    return {
      if (_mode == TripMode.ride &&
          _ridePickupReady &&
          _currentPosition != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: _currentPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      if (_mode == TripMode.ride && _destinationPosition != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationPosition!,
          draggable: true,
          onDragEnd: _setDestinationFromMap,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      if (_mode == TripMode.delivery && _pickupPosition != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      if (_mode == TripMode.delivery && _deliveryPosition != null)
        Marker(
          markerId: const MarkerId('delivery'),
          position: _deliveryPosition!,
          draggable: true,
          onDragEnd: _setDestinationFromMap,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
    };
  }

  Future<void> _pickLocation(String field) async {
    final selected = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSearchScreen(
          title: field == 'from' || field == 'pickup'
              ? 'Choose Pickup'
              : 'Choose Location',
        ),
      ),
    );
    if (selected == null || !mounted) return;
    _activeField = field;
    await _selectSuggestion(selected);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final ready = _mode == TripMode.ride
        ? _ridePickupReady && _destinationPosition != null
        : _pickupPosition != null && _deliveryPosition != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _mode == TripMode.delivery
              ? 'Send a Package'
              : widget.scheduledAt != null
              ? 'Schedule a Ride'
              : widget.shared
              ? 'Shared Ride'
              : 'Choose a Ride',
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _vehicleLabel,
                style: const TextStyle(color: AppColors.blueDeep, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * (keyboard ? .63 : .38),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Column(
                    children: [
                      if (widget.scheduledAt != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Scheduled: ${widget.scheduledAt!.day}/${widget.scheduledAt!.month} at ${TimeOfDay.fromDateTime(widget.scheduledAt!).format(context)}',
                            style: const TextStyle(
                              color: AppColors.blueDeep,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (!widget.shared && widget.scheduledAt == null)
                        Row(
                          children: [
                            Expanded(
                              child: _modeTab(
                                'Ride',
                                Icons.directions_car_outlined,
                                TripMode.ride,
                              ),
                            ),
                            Expanded(
                              child: _modeTab(
                                'Delivery',
                                Icons.inventory_2_outlined,
                                TripMode.delivery,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      if (_mode == TripMode.ride)
                        ..._buildRideFields()
                      else
                        ..._buildDeliveryFields(),
                      if (_suggestions.isNotEmpty) _buildSuggestionsList(),
                      if (_locationError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _InfoBanner(message: _locationError!),
                        ),
                      if (_searching || _loadingRoute)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target:
                            _currentPosition ?? const LatLng(.3476, 32.5825),
                        zoom: 13,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (_currentPosition != null) {
                          controller.moveCamera(
                            CameraUpdate.newLatLng(_currentPosition!),
                          );
                        }
                      },
                      myLocationEnabled:
                          _locationError == null && !_loadingLocation,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      onTap: _setDestinationFromMap,
                      markers: _buildMarkers(),
                      polylines: _polylines,
                    ),
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 10),
                            ],
                          ),
                          child: Text(
                            _route != null
                                ? '${_route!.durationLabel} · ${_route!.distanceLabel}'
                                : _resolvingPin
                                ? 'Finding address...'
                                : 'Tap the map or drag the destination pin',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.blueDeep,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'recenter',
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.blueDeep,
                        onPressed: () {
                          if (_currentPosition != null) {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(_currentPosition!, 15),
                            );
                          }
                        },
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                  ],
                ),
              ),
              if (!keyboard)
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_mode == TripMode.ride)
                        SizedBox(
                          height: constraints.maxHeight < 600 ? 110 : 170,
                          child: ListView(
                            children: [
                              for (final v in const [
                                ('car', 'Car', '1–4 seats'),
                                ('motorcycle', 'Moto', '1 seat'),
                                ('van', 'Van', 'People & luggage'),
                                ('bus', 'Bus', 'Seats or whole bus'),
                                ('tuktuk', 'Tuk Tuk', 'City trips'),
                                ('bicycle', 'Bicycle', 'Local delivery'),
                              ])
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _vehicleType = v.$1;
                                      _route = null;
                                    });
                                    if (_currentPosition != null &&
                                        _destinationPosition != null) {
                                      _loadRoute(
                                        _currentPosition!,
                                        _destinationPosition!,
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 5),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _vehicleType == v.$1
                                          ? AppColors.blueTint
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _vehicleType == v.$1
                                            ? AppColors.blueDeep
                                            : AppColors.hairline,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Image.asset(
                                          'assets/vehicles/${v.$1}.png',
                                          width: 65,
                                          height: 38,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                v.$2,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                v.$3,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          _vehicleType == v.$1
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: _vehicleType == v.$1
                                              ? AppColors.blueDeep
                                              : AppColors.hairline,
                                          size: 19,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            TextField(
                              controller: _packageNotes,
                              maxLength: 500,
                              maxLines: 1,
                              decoration: const InputDecoration(
                                labelText: 'Package details',
                                hintText: 'What are you sending?',
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                for (final item in const [
                                  (
                                    'document',
                                    'Document',
                                    Icons.description_outlined,
                                  ),
                                  (
                                    'small',
                                    'Small item',
                                    Icons.inventory_2_outlined,
                                  ),
                                  ('large', 'Large item', Icons.work_outline),
                                ])
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(
                                        () => _packageType = item.$1,
                                      ),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _packageType == item.$1
                                              ? AppColors.blueTint
                                              : Colors.white,
                                          border: Border.all(
                                            color: _packageType == item.$1
                                                ? AppColors.blueDeep
                                                : AppColors.hairline,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              item.$3,
                                              color: AppColors.blueDeep,
                                              size: 20,
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              item.$2,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<String>(
                            builder: (_) =>
                                const PaymentMethodsScreen(selecting: true),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.payments_outlined,
                                color: AppColors.success,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Cash',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Spacer(),
                              Text(
                                'Fare confirmed by driver',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                child: FilledButton(
                  onPressed: _confirming || _resolvingPin || !ready
                      ? null
                      : _mode == TripMode.ride
                      ? _handleGetRide
                      : _handleRequestDelivery,
                  child: Text(
                    _confirming
                        ? 'Sending request...'
                        : _mode == TripMode.delivery
                        ? 'Request Delivery'
                        : _vehicleType == 'bus'
                        ? 'Choose Bus & Seats'
                        : 'Confirm Ride',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _vehicleLabel => switch (_vehicleType) {
    'motorcycle' => 'Motorcycle',
    'tuktuk' => 'Tuk Tuk',
    'bicycle' => 'Bicycle',
    'van' => 'Van',
    'bus' => 'Bus',
    _ => 'Car',
  };
  Widget _modeTab(String label, IconData icon, TripMode mode) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        if (_confirming) return;
        _routeGeneration++;
        _pinGeneration++;
        _resolvingPin = false;
        _loadingRoute = false;
        _mode = mode;
        _route = null;
        _suggestions = [];
        _polylines = {};
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? const [BoxShadow(color: Colors.black12, blurRadius: 4)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? AppColors.blueDeep : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.blueDeep : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRideFields() {
    return [
      _LocationField(
        icon: Icons.radio_button_checked,
        iconColor: AppColors.blueLight,
        controller: _fromController,
        hint: 'Current location',
        // Editable — GPS fills it initially, but the user can type over it.
        onChanged: (v) => _onFieldChanged('from', v),
        onSubmitted: (v) => _onFieldChanged('from', v, expanded: true),
        onPick: () => _pickLocation('from'),
      ),
      const SizedBox(height: 10),
      _LocationField(
        icon: Icons.location_on,
        iconColor: AppColors.error,
        controller: _toController,
        hint: 'Enter destination',
        focusNode: _toFocusNode,
        onChanged: (v) => _onFieldChanged('to', v),
        onSubmitted: (v) => _onFieldChanged('to', v, expanded: true),
        onPick: () => _pickLocation('to'),
      ),
    ];
  }

  List<Widget> _buildDeliveryFields() {
    return [
      _LocationField(
        icon: Icons.inventory_2_outlined,
        iconColor: AppColors.blueLight,
        controller: _pickupController,
        hint: 'Pickup location',
        focusNode: _pickupFocusNode,
        onChanged: (v) => _onFieldChanged('pickup', v),
        onSubmitted: (v) => _onFieldChanged('pickup', v, expanded: true),
        onPick: () => _pickLocation('pickup'),
      ),
      const SizedBox(height: 10),
      _LocationField(
        icon: Icons.location_on,
        iconColor: AppColors.error,
        controller: _deliveryController,
        hint: 'Delivery location',
        focusNode: _deliveryFocusNode,
        onChanged: (v) => _onFieldChanged('delivery', v),
        onSubmitted: (v) => _onFieldChanged('delivery', v, expanded: true),
        onPick: () => _pickLocation('delivery'),
      ),
    ];
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.hairline),
        itemBuilder: (context, index) {
          final place = _suggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined, size: 20),
            title: Text(
              place.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5),
            ),
            onTap: () => _selectSuggestion(place),
          );
        },
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onPick;

  const _LocationField({
    required this.icon,
    required this.iconColor,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hint,
                suffixIcon: IconButton(
                  tooltip: 'Search saved and recent places',
                  onPressed: onPick,
                  icon: const Icon(Icons.search, size: 19),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
      ),
    );
  }
}
