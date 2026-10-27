import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/theme.dart';
import '../../app/board_widgets.dart';
import '../../services/location_service.dart';

class MapLocationPicker extends StatefulWidget {
  const MapLocationPicker({super.key});
  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  LatLng _point = const LatLng(.3476, 32.5825);
  GoogleMapController? _map;
  bool _busy = false;
  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final point = _point;
    var address = 'Selected map location';
    try {
      final result = await LocationService().reverseGeocode(
        point.latitude,
        point.longitude,
      );
      if (result != 'Current location') address = result;
    } catch (_) {
      /* Exact map coordinates remain usable. */
    }
    if (mounted) {
      Navigator.pop(
        context,
        PlaceResult(
          displayName: address,
          placeId: '',
          lat: point.latitude,
          lon: point.longitude,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Select Location'), centerTitle: true),
    body: Column(
      children: [
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: _point, zoom: 14),
            onMapCreated: (controller) => _map = controller,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onTap: _busy
                ? null
                : (position) => setState(() => _point = position),
            markers: {
              Marker(
                markerId: const MarkerId('selected'),
                position: _point,
                draggable: !_busy,
                onDragEnd: (position) => setState(() => _point = position),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
              ),
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BoardCard(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.blueDeep),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Drag the pin or tap the map',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_point.latitude.toStringAsFixed(5)}, ${_point.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _confirm,
                  child: Text(
                    _busy ? 'Confirming location...' : 'Confirm Location',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
