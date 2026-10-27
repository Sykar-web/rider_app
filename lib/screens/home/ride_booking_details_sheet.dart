import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/bus_service.dart';

class RideBookingDetails {
  const RideBookingDetails({
    required this.reference,
    required this.details,
    this.reservationType,
    this.seatNumber,
    this.seatNumbers,
    this.busScheduleId,
    this.travelDate,
    this.travelClass,
  });
  final String reference;
  final Map<String, dynamic> details;
  final String? reservationType;
  final String? seatNumber;
  final List<String>? seatNumbers;
  final String? busScheduleId;
  final DateTime? travelDate;
  final String? travelClass;
}

class RideBookingDetailsSheet extends StatefulWidget {
  const RideBookingDetailsSheet({
    super.key,
    required this.vehicleType,
    this.loadSchedules,
  });
  final String vehicleType;
  final Future<List<BusSchedule>> Function()? loadSchedules;
  @override
  State<RideBookingDetailsSheet> createState() =>
      _RideBookingDetailsSheetState();
}

class _RideBookingDetailsSheetState extends State<RideBookingDetailsSheet> {
  final _notes = TextEditingController();
  Future<List<BusSchedule>> _loadSchedules() =>
      widget.loadSchedules?.call() ?? BusService().aruaSchedules();
  late Future<List<BusSchedule>> _schedules = _loadSchedules();
  int _passengers = 1;
  bool _wholeBus = false;
  String _classFilter = 'ordinary';
  DateTime _travelDate = DateTime.now().add(const Duration(days: 1));
  BusSchedule? _schedule;
  final Set<String> _seats = {};

  bool get _isBus => widget.vehicleType == 'bus';
  bool get _isVan => widget.vehicleType == 'van';

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String _reference() {
    final random = Random.secure();
    return 'FR-${List.generate(12, (_) => random.nextInt(16).toRadixString(16)).join().toUpperCase()}';
  }

  String _time(String raw) => raw.length >= 5 ? raw.substring(0, 5) : raw;
  String _duration(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';

  @override
  Widget build(BuildContext context) {
    final capacity = _isVan ? 14 : 4;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.blueTint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _isBus
                            ? Icons.confirmation_number_outlined
                            : Icons.directions_car_outlined,
                        color: AppColors.blueDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'BOOKING DETAILS',
                        style: TextStyle(
                          color: AppColors.blueDeep,
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close booking details',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _isBus
                      ? 'Book your bus ticket'
                      : 'Complete your ${_isVan ? 'van' : 'car'} booking',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  _isBus
                      ? 'Choose an Arua departure, travel class, and seats.'
                      : 'These details help your driver prepare for the trip.',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                if (_isBus)
                  _busBooking(context)
                else ...[
                  const SizedBox(height: 20),
                  Text(
                    'Number of passengers',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    children: List.generate(
                      capacity,
                      (i) => ChoiceChip(
                        label: Text('${i + 1}'),
                        selected: _passengers == i + 1,
                        onSelected: (_) => setState(() => _passengers = i + 1),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _isVan
                        ? 'Luggage or special requests (optional)'
                        : 'Trip notes (optional)',
                    hintText: _isVan
                        ? 'For example: 3 bags'
                        : 'Anything the driver should know',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _canContinue ? _submit : null,
                  icon: Icon(
                    _isBus
                        ? Icons.confirmation_number_outlined
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    _isBus
                        ? 'Request reservation'
                        : 'Continue to find a driver',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canContinue =>
      !_isBus || (_schedule != null && (_wholeBus || _seats.isNotEmpty));
  void _submit() => Navigator.pop(
    context,
    RideBookingDetails(
      reference: _reference(),
      reservationType: _isBus ? (_wholeBus ? 'whole_bus' : 'individual') : null,
      seatNumber: _isBus && !_wholeBus ? _seats.first : null,
      seatNumbers: _isBus && !_wholeBus ? _seats.toList() : null,
      busScheduleId: _schedule?.id,
      travelDate: _isBus ? _travelDate : null,
      travelClass: _schedule?.serviceClass,
      details: {
        if (!_isBus) 'passenger_count': _passengers,
        if (_isBus && !_wholeBus) 'passenger_count': _seats.length,
        if (_isBus) 'company': _schedule?.company,
        if (_isBus) 'departure_time': _schedule?.departureTime,
        if (_isBus) 'arrival_time': _schedule?.arrivalTime,
        if (_isBus) 'duration_minutes': _schedule?.durationMinutes,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      },
    ),
  );

  Widget _busBooking(BuildContext context) => FutureBuilder<List<BusSchedule>>(
    future: _schedules,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          children: [
            const SizedBox(height: 16),
            const _Message(
              'Could not load departures. Check your connection and try again.',
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _schedules = _loadSchedules();
                });
              },
              child: const Text('Try again'),
            ),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(30),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final schedules = snapshot.data!
          .where((s) => s.serviceClass == _classFilter)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Arua → Kampala',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  '${_travelDate.day}/${_travelDate.month}/${_travelDate.year}',
                ),
              ),
            ],
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ordinary', label: Text('Ordinary')),
              ButtonSegment(value: 'executive', label: Text('Executive')),
            ],
            selected: {_classFilter},
            onSelectionChanged: (v) => setState(() {
              _classFilter = v.first;
              _schedule = null;
              _seats.clear();
            }),
          ),
          const SizedBox(height: 12),
          if (schedules.isEmpty)
            const _Message(
              'No departures available for this travel class. Try another class or check back later.',
            )
          else ...[
            Text(
              'Choose company and travel hours',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...schedules.map(
              (s) => _ScheduleTile(
                schedule: s,
                selected: _schedule?.id == s.id,
                time:
                    '${_time(s.departureTime)} – ${_time(s.arrivalTime)} • ${_duration(s.durationMinutes)}',
                onTap: () => setState(() {
                  _schedule = s;
                  _seats.clear();
                }),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Seat ticket'),
                icon: Icon(Icons.event_seat_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Whole bus'),
                icon: Icon(Icons.directions_bus_outlined),
              ),
            ],
            selected: {_wholeBus},
            onSelectionChanged: (v) => setState(() => _wholeBus = v.first),
          ),
          const SizedBox(height: 12),
          if (_wholeBus)
            const _Message(
              'Reserve the full bus for your group. The operator confirms final availability and price.',
            )
          else ...[
            Text(
              'Select 1 or more seats (${_seats.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_schedule == null)
              const _Message('Choose a departure to see its seat layout.')
            else
              _SeatGrid(
                selected: _seats,
                onToggle: _toggleSeat,
                capacity: _schedule!.totalSeats,
              ),
            const SizedBox(height: 8),
            const Text(
              'Seat requests are confirmed by the operator. This is not a paid ticket.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      );
    },
  );

  Future<void> _pickDate() async {
    final chosen = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: _travelDate,
    );
    if (chosen != null && mounted) setState(() => _travelDate = chosen);
  }

  void _toggleSeat(String seat) => setState(() {
    if (_seats.contains(seat)) {
      _seats.remove(seat);
    } else {
      _seats.add(seat);
    }
  });
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.selected,
    required this.time,
    required this.onTap,
  });
  final BusSchedule schedule;
  final bool selected;
  final String time;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE2F4FF) : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.blueDeep : AppColors.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.directions_bus_outlined,
              color: AppColors.blueDeep,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.company,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              schedule.serviceClass == 'executive' ? 'Executive' : 'Ordinary',
              style: const TextStyle(
                color: AppColors.blueDeep,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SeatGrid extends StatelessWidget {
  const _SeatGrid({
    required this.selected,
    required this.onToggle,
    required this.capacity,
  });
  final int capacity;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  @override
  Widget build(BuildContext context) {
    final seats = busSeatLabels(capacity);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: seats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (_, i) {
        final seat = seats[i];
        final on = selected.contains(seat);
        return InkWell(
          onTap: () => onToggle(seat),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.blueDeep : const Color(0xFFEAF6FD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: on ? AppColors.blueDeep : AppColors.hairline,
              ),
            ),
            child: Text(
              seat,
              style: TextStyle(
                color: on ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF6FD),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text),
  );
}
