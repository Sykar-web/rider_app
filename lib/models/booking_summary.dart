/// Shared formatting for recovered bookings, tickets, and trip summaries.
class BookingSummary {
  static bool isActive(Map<String, dynamic> row) =>
      !['completed', 'cancelled'].contains(row['status']);

  static String statusLabel(String? status) => switch (status) {
    'requested' => 'Awaiting confirmation',
    'accepted' => 'Accepted',
    'arriving' => 'Driver arriving',
    'picked_up' => 'Package collected',
    'in_progress' => 'In progress',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _ => 'Updating',
  };

  static List<String> seats(Map<String, dynamic> row) {
    final values = row['seat_numbers'];
    if (values is List && values.isNotEmpty) {
      return values.map((value) => value.toString()).toList();
    }
    return row['seat_number'] == null ? [] : [row['seat_number'].toString()];
  }

  static String reservation(Map<String, dynamic> row) {
    if (row['reservation_type'] == 'whole_bus') return 'Whole bus';
    final selected = seats(row);
    return selected.isEmpty ? '' : 'Seats ${selected.join(', ')}';
  }

  static String text(Map<String, dynamic> row) {
    final details = row['booking_details'] is Map
        ? row['booking_details'] as Map
        : const {};
    return [
      'FastRide • ${statusLabel(row['status'] as String?)}',
      if (row['booking_reference'] != null)
        'Reference: ${row['booking_reference']}',
      '${row['pickup_address'] ?? 'Pickup'} → ${row['dropoff_address'] ?? 'Destination'}',
      if (details['company'] != null) 'Company: ${details['company']}',
      if (row['travel_date'] != null) 'Travel date: ${row['travel_date']}',
      if (row['travel_class'] != null) 'Class: ${row['travel_class']}',
      if (details['departure_time'] != null)
        'Departure: ${details['departure_time']} (Uganda time)',
      if (details['arrival_time'] != null)
        'Estimated arrival: ${details['arrival_time']}',
      if (reservation(row).isNotEmpty) reservation(row),
      if (details['passenger_count'] != null)
        'Passengers: ${details['passenger_count']}',
      if (details['notes'] != null) 'Notes: ${details['notes']}',
      'Booking status is shown above. This summary is not proof of payment.',
    ].join('\n');
  }
}
