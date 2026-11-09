import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/board_widgets.dart';
import 'where_to_screen.dart';
import 'location_search_screen.dart';
import '../../services/location_service.dart';

class ScheduleRideScreen extends StatefulWidget {
  const ScheduleRideScreen({super.key, this.vehicleType = 'car'});
  final String vehicleType;
  @override
  State<ScheduleRideScreen> createState() => _ScheduleRideScreenState();
}

class _ScheduleRideScreenState extends State<ScheduleRideScreen> {
  PlaceResult? _pickup, _destination;
  Future<void> _choosePlace(bool pickup) async {
    final place = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSearchScreen(
          title: pickup ? 'Pickup location' : 'Destination',
        ),
      ),
    );
    if (place != null && mounted) {
      setState(() {
        if (pickup) {
          _pickup = place;
        } else {
          _destination = place;
        }
      });
    }
  }

  DateTime _departure = DateTime.now().add(const Duration(hours: 1));
  late String _vehicle =
      ['car', 'motorcycle', 'van', 'tuktuk'].contains(widget.vehicleType)
      ? widget.vehicleType
      : 'car';
  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departure,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date != null && mounted) {
      setState(
        () => _departure = DateTime(
          date.year,
          date.month,
          date.day,
          _departure.hour,
          _departure.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departure),
    );
    if (time != null && mounted) {
      setState(
        () => _departure = DateTime(
          _departure.year,
          _departure.month,
          _departure.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  void _continue() {
    if (_pickup == null || _destination == null) {
      boardInfo(
        context,
        'Choose your route',
        'Select your pickup and destination before scheduling.',
      );
      return;
    }
    if (!_departure.isAfter(DateTime.now().add(const Duration(minutes: 15)))) {
      boardInfo(
        context,
        'Choose a later time',
        'Please schedule at least 15 minutes from now.',
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => WhereToScreen(
          vehicleType: _vehicle,
          scheduledAt: _departure,
          initialPickup: _pickup,
          initialDestination: _destination,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Schedule a Ride'), centerTitle: true),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 108,
          decoration: BoxDecoration(
            color: AppColors.blueTint,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(
            child: Icon(
              Icons.calendar_month_rounded,
              color: AppColors.blueDeep,
              size: 65,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Plan your next journey',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Asap',
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose when you want to leave. Your driver will need to confirm availability.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        BoardCard(
          child: Column(
            children: [
              RouteRow(
                title: 'Pickup location',
                value: _pickup?.displayName ?? 'Select pickup location',
                onTap: () => _choosePlace(true),
              ),
              const Divider(height: 1),
              RouteRow(
                title: 'Destination',
                value: _destination?.displayName ?? 'Select destination',
                destination: true,
                onTap: () => _choosePlace(false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        BoardCard(
          child: Column(
            children: [
              BoardAction(
                icon: Icons.calendar_today_outlined,
                title: 'Date',
                subtitle:
                    '${_departure.day}/${_departure.month}/${_departure.year}',
                onTap: _pickDate,
              ),
              const Divider(height: 1),
              BoardAction(
                icon: Icons.schedule,
                title: 'Time',
                subtitle: TimeOfDay.fromDateTime(_departure).format(context),
                onTap: _pickTime,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: _vehicle,
          decoration: const InputDecoration(labelText: 'Ride type'),
          items: const [
            DropdownMenuItem(value: 'car', child: Text('Car (1–4 seats)')),
            DropdownMenuItem(value: 'motorcycle', child: Text('Moto (1 seat)')),
            DropdownMenuItem(value: 'van', child: Text('Van')),
            DropdownMenuItem(value: 'tuktuk', child: Text('Tuk Tuk')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _vehicle = v);
          },
        ),
        const SizedBox(height: 18),
        const BoardCard(
          child: Row(
            children: [
              Icon(Icons.payments_outlined, color: AppColors.blueDeep),
              SizedBox(width: 12),
              Expanded(child: Text('Payment method')),
              Text('Cash', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _continue,
          child: const Text('Review Scheduled Ride'),
        ),
      ],
    ),
  );
}

class SharedRideScreen extends StatelessWidget {
  const SharedRideScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ride with others'), centerTitle: true),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 25),
        Container(
          height: 185,
          decoration: BoxDecoration(
            color: AppColors.blueTint,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned(
                top: 20,
                child: Icon(
                  Icons.groups_rounded,
                  color: AppColors.blueDeep,
                  size: 65,
                ),
              ),
              Positioned(
                left: 25,
                right: 25,
                bottom: 5,
                child: Image.asset(
                  'assets/vehicles/illustrated_car.png',
                  height: 115,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'Share a ride and save',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text(
          'Request to travel with others heading the same way. Availability and the final fare must be confirmed.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        for (final item in [
          (Icons.payments_outlined, 'Share travel costs'),
          (Icons.people_outline, 'Meet new people'),
          (Icons.route_outlined, 'Travel the same route'),
          (Icons.eco_outlined, 'Make room for a greener journey'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              children: [
                Icon(item.$1, color: AppColors.blueDeep, size: 22),
                const SizedBox(width: 14),
                Expanded(child: Text(item.$2)),
              ],
            ),
          ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  const WhereToScreen(vehicleType: 'car', shared: true),
            ),
          ),
          child: const Text('Request a Shared Ride'),
        ),
      ],
    ),
  );
}
