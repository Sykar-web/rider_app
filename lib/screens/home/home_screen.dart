import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/board_widgets.dart';
import '../../app/profile_photo.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import 'home_ride_hero.dart';
import 'where_to_screen.dart';
import 'location_search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onProfile});
  final VoidCallback onProfile;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PlaceResult? _pickup;

  Future<void> _choosePickup() async {
    final selected = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSearchScreen(
          title: 'Enter pickup location',
          initialQuery: _pickup?.displayName ?? '',
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _pickup = selected);
    _book();
  }

  void _book() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => WhereToScreen(vehicleType: 'car', initialPickup: _pickup),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: EdgeInsets.zero,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onProfile,
                  tooltip: 'Open profile',
                  padding: EdgeInsets.zero,
                  icon: const ProfilePhoto(radius: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: _greeting()),
              ],
            ),
          ),
        ),
        const HomeRideHero(),
        Transform.translate(
          offset: const Offset(0, -24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
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
                    value: _pickup?.displayName ?? 'Enter pickup or use GPS',
                    onTap: _choosePickup,
                  ),
                  const Divider(height: 1, indent: 36),
                  RouteRow(
                    title: 'Where to?',
                    value: 'Enter destination',
                    destination: true,
                    onTap: _book,
                  ),
                ],
              ),
            ),
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
      // Local previews may not have a signed-in session.
    }
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting${name == null || name.trim().isEmpty ? '' : ', ${name.trim().split(' ').first}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Asap',
            color: AppColors.navy,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Where next?',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      ],
    );
  }
}
