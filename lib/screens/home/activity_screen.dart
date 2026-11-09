import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../app/board_widgets.dart';
import '../../models/booking_summary.dart';
import '../../services/location_service.dart';
import 'searching_screen.dart';
import 'delivery_searching_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    this.refreshRevision = 0,
    this.loadBookings,
    this.onBookRide,
  });
  final int refreshRevision;
  final Future<List<Map<String, dynamic>>> Function()? loadBookings;
  final VoidCallback? onBookRide;
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late Future<List<Map<String, dynamic>>> _bookings;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _bookings = _load();
  }

  @override
  void didUpdateWidget(covariant ActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshRevision != oldWidget.refreshRevision) {
      _bookings = _load();
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    if (widget.loadBookings != null) return widget.loadBookings!();
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    await client.rpc('expire_my_requests');
    final results = await Future.wait([
      client
          .from('rides')
          .select()
          .eq('passenger_id', userId)
          .order('requested_at', ascending: false)
          .limit(100),
      client
          .from('deliveries')
          .select()
          .eq('sender_id', userId)
          .order('requested_at', ascending: false)
          .limit(100),
    ]);
    final rows = [
      for (final row in results[0]) {...row, '_delivery': false},
      for (final row in results[1]) {...row, '_delivery': true},
    ];
    rows.sort(
      (a, b) => (b['requested_at']?.toString() ?? '').compareTo(
        a['requested_at']?.toString() ?? '',
      ),
    );
    return rows;
  }

  Future<void> _refresh() async {
    setState(() {
      _bookings = _load();
    });
    try {
      await _bookings;
    } catch (_) {
      /* FutureBuilder presents retry. */
    }
  }

  void _open(Map<String, dynamic> row) {
    final pickup = row['pickup_address'] as String? ?? 'Pickup';
    final dropoff = row['dropoff_address'] as String? ?? 'Destination';
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => row['_delivery'] == true
                ? DeliverySearchingScreen(
                    deliveryId: row['id'] as String,
                    pickupAddress: pickup,
                    dropoffAddress: dropoff,
                  )
                : SearchingScreen(
                    rideId: row['id'] as String,
                    pickupAddress: pickup,
                    dropoffAddress: dropoff,
                  ),
          ),
        )
        .then((_) {
          if (mounted) _refresh();
        });
  }

  bool _matches(Map<String, dynamic> row) => switch (_filter) {
    'Upcoming' => BookingSummary.isActive(row),
    'Completed' => row['status'] == 'completed',
    'Cancelled' => row['status'] == 'cancelled',
    _ => true,
  };

  String _date(Map<String, dynamic> row) {
    final value = DateTime.tryParse(
      (row['travel_date'] ?? row['scheduled_at'] ?? row['requested_at'] ?? '')
          .toString(),
    )?.toLocal();
    if (value == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  Widget _bookingCard(Map<String, dynamic> row) {
    final status = row['status']?.toString();
    final color = status == 'completed'
        ? AppColors.success
        : status == 'cancelled'
        ? AppColors.error
        : AppColors.blueDeep;
    final type = row['_delivery'] == true
        ? 'Package delivery'
        : row['vehicle_type']?.toString() ?? 'Ride';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(row),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.blueTint,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        row['_delivery'] == true
                            ? Icons.inventory_2_outlined
                            : type == 'bus'
                            ? Icons.directions_bus_outlined
                            : Icons.directions_car_outlined,
                        size: 18,
                        color: AppColors.blueDeep,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        type[0].toUpperCase() + type.substring(1),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        ugx(row['fare_ugx']),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _address(row['pickup_address'], false),
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Container(
                    width: 1,
                    height: 12,
                    color: AppColors.hairline,
                  ),
                ),
                _address(row['dropoff_address'], true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        BookingSummary.statusLabel(status),
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _date(row),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 19,
                    ),
                  ],
                ),
                if (row['booking_reference'] != null ||
                    BookingSummary.reservation(row).isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(
                    [
                      if (row['booking_reference'] != null)
                        row['booking_reference'].toString(),
                      BookingSummary.reservation(row),
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: const TextStyle(
                      color: AppColors.blueDeep,
                      fontSize: 12,
                    ),
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: BookingSummary.text(row)),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Booking details copied.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined, size: 15),
                    label: const Text(
                      'Copy details',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _address(Object? value, bool destination) => Row(
    children: [
      Icon(
        destination ? Icons.location_on_rounded : Icons.radio_button_checked,
        color: destination ? AppColors.error : AppColors.blueDeep,
        size: 16,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          readablePlaceLabel(
            value?.toString() ?? '',
            fallback: destination ? 'Destination' : 'Pickup',
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.field,
    body: SafeArea(
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'My Rides',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh bookings',
                      onPressed: _refresh,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.blueDeep,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Your journeys, deliveries and bus reservations.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (_, i) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final label = [
                        'All',
                        'Upcoming',
                        'Completed',
                        'Cancelled',
                      ][i];
                      final selected = label == _filter;
                      return Semantics(
                        selected: selected,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(11),
                          onTap: () => setState(() => _filter = label),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.blueDeep
                                  : AppColors.field,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _bookings,
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = (snapshot.data ?? []).where(_matches).toList();
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (snapshot.hasError)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 70),
                          child: StatusMessage(
                            message: 'Could not load bookings. Check your connection.',
                            onRetry: _refresh,
                          ),
                        )
                      else if (rows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 60,
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.blueTint,
                                ),
                                child: const Icon(
                                  Icons.route_rounded,
                                  size: 42,
                                  color: AppColors.blueDeep,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                _filter == 'All'
                                    ? 'Your next journey starts here'
                                    : 'No ${_filter.toLowerCase()} bookings',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Asap',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Your rides, deliveries and bus reservations will appear here when you book.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  height: 1.5,
                                ),
                              ),
                              if (widget.onBookRide != null) ...[
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: widget.onBookRide,
                                  child: const Text('Book a Ride'),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        ...rows.map(_bookingCard),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
