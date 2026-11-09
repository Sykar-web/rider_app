import 'package:flutter/material.dart';

import '../../services/driver_account_service.dart';
import '../../widgets/driver_board.dart';

class DriverVehicleInformation extends StatefulWidget {
  const DriverVehicleInformation({super.key});
  @override
  State<DriverVehicleInformation> createState() =>
      _DriverVehicleInformationState();
}

class _DriverVehicleInformationState extends State<DriverVehicleInformation> {
  late Future<Map<String, dynamic>> _profile = DriverAccountService().profile();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vehicle Information')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return DriverEmpty(
            title: 'Vehicle unavailable',
            message: 'Check your connection and try again.',
            onRetry: () =>
                setState(() => _profile = DriverAccountService().profile()),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final p = snapshot.data!;
        final a = p['driver_application'] as Map? ?? {};
        final values = <String, dynamic>{
          'Vehicle type': p['vehicle_type'] ?? a['vehicle_type'],
          'Registration number': p['vehicle_plate'] ?? a['registration_number'],
          'Make': a['make'],
          'Model': a['model'],
          'Year': a['year'],
          'Colour': a['colour'],
        };
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DriverCard(
              child: Column(
                children: [
                  for (final e in values.entries)
                    ListTile(
                      title: Text(e.key),
                      subtitle: Text(e.value?.toString() ?? 'Not provided'),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
