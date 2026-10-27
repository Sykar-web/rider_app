import 'package:supabase_flutter/supabase_flutter.dart';

List<String> busSeatLabels(int capacity) => List.generate(
  capacity.clamp(0, 80),
  (i) => '${i ~/ 4 + 1}${'ABCD'[i % 4]}',
);

class BusSchedule {
  const BusSchedule({
    required this.id,
    required this.company,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationMinutes,
    required this.serviceClass,
    required this.totalSeats,
  });
  final String id;
  final String company;
  final String departureTime;
  final String arrivalTime;
  final int durationMinutes;
  final String serviceClass;
  final int totalSeats;

  factory BusSchedule.fromMap(Map<String, dynamic> row) {
    final companyData = row['bus_companies'] as Map<String, dynamic>?;
    return BusSchedule(
      id: row['id'] as String,
      company: companyData?['name'] as String? ?? 'Bus operator',
      departureTime: row['departure_time'] as String,
      arrivalTime: row['arrival_time'] as String,
      durationMinutes: row['duration_minutes'] as int,
      serviceClass: row['service_class'] as String,
      totalSeats: row['total_seats'] as int,
    );
  }
}

class BusService {
  final SupabaseClient _client = Supabase.instance.client;
  Future<List<BusSchedule>> aruaSchedules() async {
    final rows = await _client
        .from('bus_schedules')
        .select(
          'id, departure_time, arrival_time, duration_minutes, service_class, total_seats, bus_companies(name)',
        )
        .eq('origin', 'Arua')
        .eq('is_active', true)
        .order('departure_time');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(BusSchedule.fromMap)
        .toList();
  }
}
