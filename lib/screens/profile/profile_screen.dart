import 'package:flutter/material.dart';

import '../account/payment_methods_screen.dart';

import '../../app/theme.dart';
import '../../app/profile_photo.dart';
import '../../app/board_widgets.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';

import 'package:provider/provider.dart';

import '../../core/mode_manager/mode_manager.dart';
import '../../fast_driver/screens/onboarding/driver_application_form.dart';
import '../account/customer_pages.dart';
import '../admin/admin_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onBack});
  final VoidCallback? onBack;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await AuthService().getCurrentProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      /* Cached auth identity remains visible. */
    }
  }

  void _personal() =>
      Navigator.push(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => const PersonalInformationScreen(),
        ),
      ).then((saved) {
        if (saved == true && mounted) _load();
      });

  Future<void> _logout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BoardDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in to access your bookings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay signed in'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (result != true) return;
    try {
      await AuthService().signOut();
    } catch (_) {
      if (mounted) boardInfo(context, 'Could not log out', 'Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final name =
        _profile?['full_name'] as String? ??
        user?.userMetadata?['full_name'] as String? ??
        'FastRide member';
    final phone = _profile?['phone'] as String? ?? user?.phone ?? '';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          children: [
            Row(
              children: [
                const ProfilePhoto(radius: 34, editable: true),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone.isNotEmpty
                            ? phone
                            : user?.email ?? 'Your FastRide account',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _personal,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          side: const BorderSide(color: AppColors.blueDeep),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Edit profile',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Driver mode toggle button
            Consumer<ModeManager>(
              builder: (context, modeManager, _) {
                final currentUser = Supabase.instance.client.auth.currentUser;
                if (currentUser == null) return const SizedBox.shrink();
                final meta = currentUser.appMetadata;
                final isApproved = meta['driver_approved'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton.icon(
                    icon: Icon(isApproved ? Icons.swap_horiz : Icons.drive_eta),
                    onPressed: () async {
                      if (!isApproved) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DriverApplicationForm(),
                          ),
                        );
                        return;
                      }
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Switch to Driver mode'),
                          content: const Text(
                            'Open your driver dashboard using this same account?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Switch'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await modeManager.switchTo(AppMode.driver);
                      }
                    },
                    label: Text(
                      isApproved ? 'Switch to Driver' : 'Become a Driver',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const AdminDashboardEntry(),
            BoardAction(
              icon: Icons.person_outline,
              title: 'Personal Information',
              onTap: _personal,
            ),
            const Divider(height: 1),
            BoardAction(
              icon: Icons.credit_card,
              title: 'Payment Methods',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const PaymentMethodsScreen(),
                ),
              ),
            ),
            const Divider(height: 1),
            BoardAction(
              icon: Icons.favorite_border,
              title: 'Favourite Places',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const FavouritePlacesScreen(),
                ),
              ),
            ),
            const Divider(height: 1),
            BoardAction(
              icon: Icons.notifications_none,
              title: 'Notifications',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}
