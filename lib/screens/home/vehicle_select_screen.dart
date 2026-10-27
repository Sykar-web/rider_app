import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/auth_service.dart';

class _VehicleOption {
  final String value;
  final String label;
  final String description;
  final String asset;

  const _VehicleOption(this.value, this.label, this.description, this.asset);
}

class VehicleSelectScreen extends StatefulWidget {
  final ValueChanged<String>? onSelected;
  final String? selectedVehicle;

  const VehicleSelectScreen({super.key, this.onSelected, this.selectedVehicle});

  @override
  State<VehicleSelectScreen> createState() => _VehicleSelectScreenState();
}

class _VehicleSelectScreenState extends State<VehicleSelectScreen> {
  static const _vehicles = [
    _VehicleOption(
      'motorcycle',
      'Motorcycle',
      'Quick solo trips',
      'assets/vehicles/motorcycle.png',
    ),
    _VehicleOption(
      'tuktuk',
      'Tuk Tuk',
      'Compact city rides',
      'assets/vehicles/tuktuk.png',
    ),
    _VehicleOption(
      'car',
      'Car',
      'Comfort for up to 4',
      'assets/vehicles/car.png',
    ),
    _VehicleOption(
      'bicycle',
      'Bicycle',
      'Light local delivery',
      'assets/vehicles/bicycle.png',
    ),
    _VehicleOption(
      'van',
      'Van',
      'Large parcel delivery',
      'assets/vehicles/van.png',
    ),
    _VehicleOption(
      'bus',
      'Bus',
      'Groups and shared trips',
      'assets/vehicles/bus.png',
    ),
  ];

  String? _selectedVehicle;
  String? _firstName;

  @override
  void initState() {
    super.initState();
    _selectedVehicle = widget.selectedVehicle;
    _loadName();
  }

  Future<void> _loadName() async {
    // Vehicle selection is also usable in previews before Supabase is ready.
    try {
      final profile = await AuthService().getCurrentProfile();
      if (!mounted) return;
      final profileName = profile?['full_name'] as String?;
      final metadataName =
          AuthService().currentUser?.userMetadata?['full_name'] as String?;
      final name = (profileName ?? metadataName ?? '').trim();
      if (name.isNotEmpty) {
        setState(() => _firstName = name.split(RegExp(r'\s+')).first);
      }
    } catch (_) {
      // An unavailable profile must not prevent vehicle selection.
    }
  }

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void didUpdateWidget(covariant VehicleSelectScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedVehicle != widget.selectedVehicle) {
      _selectedVehicle = widget.selectedVehicle;
    }
  }

  void _selectVehicle(String vehicleType) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _selectedVehicle = vehicleType);
    widget.onSelected?.call(vehicleType);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose a Ride'), centerTitle: true),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          _firstName == null
              ? '$_timeGreeting!'
              : '$_timeGreeting, $_firstName!',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        const Text(
          'A ride for every journey',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _selectedVehicle == null
              ? 'Choose how you want to travel.'
              : 'Vehicle selected. Choose your destination next.',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        for (final vehicle in _vehicles)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              button: true,
              selected: _selectedVehicle == vehicle.value,
              label: vehicle.label,
              child: InkWell(
                onTap: () => _selectVehicle(vehicle.value),
                borderRadius: BorderRadius.circular(15),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedVehicle == vehicle.value
                        ? AppColors.blueTint
                        : Colors.white,
                    border: Border.all(
                      color: _selectedVehicle == vehicle.value
                          ? AppColors.blueDeep
                          : AppColors.hairline,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        vehicle.asset,
                        width: 82,
                        height: 55,
                        fit: BoxFit.contain,
                        semanticLabel: vehicle.label,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.label,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              vehicle.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _selectedVehicle == vehicle.value
                            ? Icons.check_circle
                            : Icons.radio_button_off,
                        size: 21,
                        color: _selectedVehicle == vehicle.value
                            ? AppColors.blueDeep
                            : AppColors.hairline,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
