import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'home_service_carousel.dart';
import '../../app/board_widgets.dart';
import '../../services/auth_service.dart';
import '../account/customer_pages.dart';
import 'where_to_screen.dart';
import 'schedule_ride_screen.dart';
import 'location_search_screen.dart';
import '../../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onProfile,
    required this.onSupport,
  });
  final VoidCallback onProfile;
  final VoidCallback onSupport;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _vehicle = 'car';
  static const _vehicles = [
    ('car', 'Car', 'car'),
    ('motorcycle', 'Moto', 'motorcycle'),
    ('van', 'Van', 'van'),
    ('bus', 'Bus', 'bus'),
    ('tuktuk', 'Tuk Tuk', 'tuktuk'),
    ('bicycle', 'Bicycle', 'bicycle'),
  ];
  void _book({bool delivery = false}) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => WhereToScreen(
        vehicleType: _vehicle,
        initialMode: delivery ? TripMode.delivery : TripMode.ride,
      ),
    ),
  );
  void _schedule() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ScheduleRideScreen(vehicleType: _vehicle),
    ),
  );
  void _shared() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => const SharedRideScreen()),
  );
  Future<void> _searchPopular(String query) async {
    final place = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSearchScreen(initialQuery: query),
      ),
    );
    if (place != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              WhereToScreen(vehicleType: _vehicle, initialDestination: place),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: EdgeInsets.zero,
      children: [
        HomeServiceCarousel(
          onProfile: widget.onProfile,
          onNotifications: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const NotificationSettingsScreen(),
            ),
          ),
          onService: (vehicle, delivery) {
            setState(() => _vehicle = vehicle);
            _book(delivery: delivery);
          },
        ),
        Align(
          alignment: Alignment.topCenter,
          heightFactor: .80,
          child: Transform.translate(
            offset: const Offset(0, -24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1000245C),
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    RouteRow(
                      title: 'Pickup location',
                      value: 'Current location',
                      onTap: () => _book(),
                    ),
                    const Divider(height: 1, indent: 36),
                    RouteRow(
                      title: 'Where to?',
                      value: 'Enter destination',
                      destination: true,
                      onTap: () => _book(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: _greeting(),
        ),
        SizedBox(
          height: 78,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            itemCount: _vehicles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final v = _vehicles[i];
              final selected = _vehicle == v.$1;
              return InkWell(
                onTap: () => setState(() => _vehicle = v.$1),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 78,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.blueTint : Colors.white,
                    border: Border.all(
                      color: selected ? AppColors.blueDeep : AppColors.hairline,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.asset(
                          'assets/vehicles/${v.$3}.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        v.$2,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              _quick(Icons.schedule, 'Schedule\na ride', _schedule),
              const SizedBox(width: 7),
              _quick(Icons.groups_rounded, 'Ride\nwith others', _shared),
              const SizedBox(width: 7),
              _quick(
                Icons.inventory_2,
                'Send\npackage',
                () => _book(delivery: true),
              ),
              const SizedBox(width: 7),
              _quick(
                Icons.star_rounded,
                'Favourite\nplaces',
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const FavouritePlacesScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: AppColors.blueTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reliable Rides\nAnytime, Anywhere',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Set your destination.\nWe’ll help you get there.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 9),
                      FilledButton(
                        onPressed: () => _book(),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text(
                          'Book a Ride →',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Image.asset('assets/vehicles/car.png', height: 105),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Popular Destinations',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              TextButton(
                onPressed: () => _searchPopular(''),
                child: const Text('See all ›'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Row(
            children: [
              for (final place in const [
                ('City Centre', Icons.location_city),
                ('Acacia Mall', Icons.storefront),
                ('Entebbe Airport', Icons.flight),
                ('Bus Park', Icons.directions_bus),
              ])
                Expanded(
                  child: InkWell(
                    onTap: () => _searchPopular(place.$1),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.blueTint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Icon(place.$2, color: AppColors.blueDeep, size: 30),
                          const SizedBox(height: 7),
                          Text(
                            place.$1,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Row(
            children: [
              Expanded(
                child: _feature(
                  Icons.directions_bus_rounded,
                  'Bus tickets',
                  'Seats or whole bus',
                  () {
                    setState(() => _vehicle = 'bus');
                    _book();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _feature(
                  Icons.local_shipping_outlined,
                  'Deliveries',
                  'From door to door',
                  () => _book(delivery: true),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _greeting() {
    String? name;
    try {
      name = AuthService().currentUser?.userMetadata?['full_name'] as String?;
    } catch (_) {
      /* Preview has no session. */
    }
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Text(
      '$greeting${name == null || name.trim().isEmpty ? '' : ', ${name.trim().split(' ').first}'}. Where next?',
      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
    );
  }

  Widget _quick(IconData icon, String label, VoidCallback tap) => Expanded(
    child: InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.blueTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.blueDeep, size: 26),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _feature(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback tap,
  ) => InkWell(
    onTap: tap,
    child: BoardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.blueDeep, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}
