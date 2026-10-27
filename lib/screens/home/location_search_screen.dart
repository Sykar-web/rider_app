import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/board_widgets.dart';
import '../../services/location_service.dart';
import '../../services/customer_service.dart';
import 'map_location_picker.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({
    super.key,
    this.title = 'Choose Location',
    this.initialQuery = '',
  });
  final String title;
  final String initialQuery;
  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _search = TextEditingController();
  final _location = LocationService();
  Timer? _debounce;
  int _generation = 0;
  bool _busy = false;
  String? _error;
  List<PlaceResult> _results = [];
  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _recent = [];
  @override
  void initState() {
    super.initState();
    _loadPlaces();
    if (widget.initialQuery.isNotEmpty) {
      _search.text = widget.initialQuery;
      _changed(widget.initialQuery);
    }
  }

  Future<void> _loadPlaces() async {
    try {
      final service = CustomerService();
      final results = await Future.wait([
        service.places(),
        service.places(recent: true),
      ]);
      if (mounted) {
        setState(() {
          _places = results[0];
          _recent = results[1];
        });
      }
    } catch (_) {
      /* Search remains usable before the database migration. */
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _changed(String query, {bool expanded = false}) {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _results = [];
      _error = null;
      _busy = query.trim().length >= 2;
    });
    if (query.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final places = await _location.searchPlaces(query, expanded: expanded);
        if (mounted && generation == _generation) {
          setState(() {
            _results = places;
            _busy = false;
          });
        }
      } catch (_) {
        if (mounted && generation == _generation) {
          setState(() {
            _error = 'Could not search. Check your connection and try again.';
            _busy = false;
          });
        }
      }
    });
  }

  Future<void> _choose(PlaceResult place) async {
    if (_busy) return;
    ++_generation;
    _debounce?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final resolved = await _location.resolvePlace(place);
      if (resolved == null || resolved.lat == null || resolved.lon == null) {
        throw StateError('Missing coordinates');
      }
      try {
        await CustomerService().savePlace(
          resolved.displayName.split(',').first,
          'recent',
          resolved,
        );
      } catch (_) {
        /* Saving a recent search must not block a route. */
      }
      if (mounted) Navigator.pop(context, resolved);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not load that location. Please try again.';
        });
      }
    }
  }

  Future<void> _gps() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final position = await _location.getCurrentPosition();
      final address = await _location.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (mounted) {
        Navigator.pop(
          context,
          PlaceResult(
            displayName: address,
            placeId: '',
            lat: position.latitude,
            lon: position.longitude,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Enable location access or search for your pickup manually.';
        });
      }
    }
  }

  Widget _saved(Map<String, dynamic> row, {bool recent = false}) => ListTile(
    leading: Icon(
      recent
          ? Icons.history
          : row['kind'] == 'home'
          ? Icons.home_rounded
          : row['kind'] == 'work'
          ? Icons.work_rounded
          : Icons.location_on,
      color: AppColors.blueDeep,
    ),
    title: Text(
      readablePlaceLabel(row['label'] as String),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      readablePlaceLabel(row['address'] as String),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12),
    ),
    onTap: () => _choose(
      PlaceResult(
        displayName: row['address'] as String,
        placeId: row['place_id'] as String? ?? '',
        lat: (row['latitude'] as num).toDouble(),
        lon: (row['longitude'] as num).toDouble(),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title), centerTitle: true),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            onChanged: _changed,
            onSubmitted: (query) => _changed(query, expanded: true),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search for area, landmark...',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              ListTile(
                leading: const Icon(
                  Icons.map_outlined,
                  color: AppColors.blueDeep,
                ),
                title: const Text('Choose on map'),
                subtitle: const Text(
                  'Move a pin to an exact location',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  final place = await Navigator.push<PlaceResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MapLocationPicker(),
                    ),
                  );
                  if (place != null && context.mounted) {
                    Navigator.pop(context, place);
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.my_location,
                  color: AppColors.blueDeep,
                ),
                title: const Text('Current location'),
                subtitle: const Text(
                  'Using GPS',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: _gps,
              ),
              if (_search.text.trim().length >= 2) ...[
                ListTile(
                  leading: const Icon(
                    Icons.travel_explore,
                    color: AppColors.blueDeep,
                  ),
                  title: const Text('Search more places in Uganda'),
                  subtitle: const Text(
                    'Villages, shops, schools and local landmarks',
                  ),
                  onTap: _busy
                      ? null
                      : () => _changed(_search.text, expanded: true),
                ),
                for (final place in _results)
                  ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.blueDeep,
                    ),
                    title: Text(
                      place.displayName,
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () => _choose(place),
                  ),
                if (!_busy && _results.isEmpty && _error == null)
                  const StatusMessage(
                    message: 'No named place found. Try its village or nearby landmark, or choose the exact spot on the map.',
                  ),
              ] else ...[
                for (final row in _places) _saved(row),
                if (_places.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Save Home, Work and favourite places from your profile.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                if (_recent.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Recent Searches',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                for (final row in _recent) _saved(row, recent: true),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
