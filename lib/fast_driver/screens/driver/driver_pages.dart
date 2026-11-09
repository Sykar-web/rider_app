import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/mode_manager/mode_manager.dart';
import '../../../app/profile_photo.dart';
import '../../app/theme.dart';
import '../../services/driver_account_service.dart';
import '../../widgets/driver_board.dart';
import 'driver_vehicle_information.dart';
import '../../../screens/admin/admin_dashboard_screen.dart';
import '../../../screens/account/customer_pages.dart'
    show PersonalInformationScreen;

class DriverHistory extends StatefulWidget {
  const DriverHistory({
    super.key,
    required this.jobs,
    required this.onRefresh,
    required this.onOpen,
  });
  final List<Map<String, dynamic>> jobs;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic>) onOpen;
  @override
  State<DriverHistory> createState() => _DriverHistoryState();
}

class _DriverHistoryState extends State<DriverHistory> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final rows = widget.jobs
        .where((j) => filter == 'All' || j['status'] == filter.toLowerCase())
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              for (final label in ['All', 'Completed', 'Cancelled'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Asap',
                          fontSize: 13,
                          color: filter == label
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                      ),
                      selected: filter == label,
                      onSelected: (_) => setState(() => filter = label),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (rows.isEmpty)
                  const DriverEmpty(
                    title: 'No trips yet',
                    message: 'Your rides and deliveries will appear here.',
                  ),
                for (final job in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => widget.onOpen(job),
                      child: DriverCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              jobDate(job),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            DriverRouteRows(job: job),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    money(job['fare_ugx']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    (job['status'] ?? '').toString().replaceAll(
                                      '_',
                                      ' ',
                                    ),
                                  ),
                                  backgroundColor: job['status'] == 'completed'
                                      ? const Color(0xFFE8FAF4)
                                      : AppColors.blueTint,
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DriverEarnings extends StatefulWidget {
  const DriverEarnings({
    super.key,
    required this.jobs,
    required this.onRefresh,
  });
  final List<Map<String, dynamic>> jobs;
  final Future<void> Function() onRefresh;
  @override
  State<DriverEarnings> createState() => _DriverEarningsState();
}

class _DriverEarningsState extends State<DriverEarnings> {
  int days = 1;
  @override
  Widget build(BuildContext context) {
    final totals = DriverTotals(widget.jobs, days: days),
        today = DateUtils.dateOnly(DateTime.now());
    final values = [
      for (var i = 6; i >= 0; i--)
        totals.byDay[today.subtract(Duration(days: i))] ?? 0.0,
    ];
    final max = values.fold<double>(1, (a, b) => a > b ? a : b);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              for (final period in [(1, 'Day'), (7, 'Week'), (30, 'Month')])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: Text(
                        period.$2,
                        style: TextStyle(
                          fontFamily: 'Asap',
                          fontSize: 13,
                          color: days == period.$1
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                      ),
                      selected: days == period.$1,
                      onSelected: (_) => setState(() => days = period.$1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Recorded trip fares',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
          Text(
            money(totals.gross),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Asap',
              fontWeight: FontWeight.w800,
              fontSize: 32,
              color: AppColors.blueDeep,
            ),
          ),
          const SizedBox(height: 20),
          DriverCard(
            child: Row(
              children: [
                stat(totals.count.toString(), 'Trips'),
                stat('${totals.seconds ~/ 60} min', 'Trip time'),
                stat(
                  totals.pricedCount == 0
                      ? '—'
                      : money(totals.gross / totals.pricedCount),
                  'Average fare',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          DriverCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last seven days in selected period',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 130,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < values.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  height: values[i] == 0
                                      ? 2
                                      : values[i] / max * 85,
                                  decoration: BoxDecoration(
                                    color: AppColors.blueDeep,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  today
                                      .subtract(Duration(days: 6 - i))
                                      .day
                                      .toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Gross fares before fees or expenses. Cash is collected directly. These figures are not a wallet balance. Pull down to refresh.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if (totals.pricedCount < totals.count)
            const Text(
              'Trips without a recorded fare are excluded from fare totals.',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          const SizedBox(height: 24),
          const Text(
            'Recent Trips',
            style: TextStyle(
              fontFamily: 'Asap',
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final job
              in widget.jobs
                  .where((j) {
                    final date = DateTime.tryParse(
                      (j['completed_at'] ?? '').toString(),
                    )?.toLocal();
                    return j['status'] == 'completed' &&
                        date != null &&
                        !date.isBefore(
                          today.subtract(Duration(days: days - 1)),
                        ) &&
                        !date.isAfter(DateTime.now());
                  })
                  .take(10))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.route, color: AppColors.blueDeep),
              title: Text(
                job['dropoff_address'] ?? 'Destination',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(jobDate(job)),
              trailing: Text(
                money(job['fare_ugx']),
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DriverJobReceipt(job: job)),
              ),
            ),
        ],
      ),
    );
  }

  Widget stat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    ),
  );
}

class DriverJobReceipt extends StatelessWidget {
  const DriverJobReceipt({super.key, required this.job});
  final Map<String, dynamic> job;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trip details')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DriverCard(child: DriverRouteRows(job: job)),
        const SizedBox(height: 16),
        DriverCard(
          child: Column(
            children: [
              ListTile(
                title: const Text('Fare'),
                trailing: Text(
                  money(job['fare_ugx']),
                  style: const TextStyle(
                    color: AppColors.blueDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                title: const Text('Status'),
                trailing: Text(
                  (job['status'] ?? '').toString().replaceAll('_', ' '),
                ),
              ),
              ListTile(title: const Text('Date'), subtitle: Text(jobDate(job))),
              const ListTile(
                title: Text('Payment method'),
                trailing: Text('Cash'),
              ),
              if (job['booking_reference'] != null)
                ListTile(
                  title: const Text('Booking reference'),
                  subtitle: Text(job['booking_reference'].toString()),
                ),
              if (job['seat_numbers'] != null)
                ListTile(
                  title: const Text('Seats'),
                  subtitle: Text(job['seat_numbers'].toString()),
                ),
              if (job['distance_km'] != null)
                ListTile(
                  title: const Text('Distance'),
                  trailing: Text('${job['distance_km']} km'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class DriverWallet extends StatelessWidget {
  const DriverWallet({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Wallet')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DriverCard(
          color: AppColors.blueDeep,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available balance',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 8),
              Text(
                'Not enabled',
                style: TextStyle(
                  fontFamily: 'Asap',
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Cash fares are collected directly.',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => driverInfo(
                  context,
                  'Withdrawals unavailable',
                  'No payment provider is connected yet. Cash is paid directly by your customer.',
                ),
                child: const Text('Withdraw'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => driverInfo(
                  context,
                  'No transactions',
                  'Completed trip fares appear in Earnings. No electronic wallet transactions have been processed.',
                ),
                child: const Text('Transactions'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 35),
        const DriverEmpty(
          title: 'Cash payments are active',
          message: 'Mobile Money, cards and wallet transfers need a payment provider before they can be enabled.',
          icon: Icons.payments_outlined,
        ),
      ],
    ),
  );
}

class DriverProfile extends StatefulWidget {
  const DriverProfile({
    super.key,
    required this.profile,
    required this.onChanged,
    required this.onLogout,
  });
  final Map<String, dynamic> profile;
  final Future<void> Function() onChanged, onLogout;
  @override
  State<DriverProfile> createState() => _DriverProfileState();
}

class _DriverProfileState extends State<DriverProfile> {
  late Map<String, dynamic> profile;
  Future<void> Function() get onChanged => widget.onChanged;
  Future<void> Function() get onLogout => widget.onLogout;
  @override
  void initState() {
    super.initState();
    profile = Map<String, dynamic>.from(widget.profile);
  }

  @override
  void didUpdateWidget(covariant DriverProfile oldWidget) {
    super.didUpdateWidget(oldWidget);
    profile = Map<String, dynamic>.from(widget.profile);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Center(child: ProfilePhoto(radius: 44, editable: true)),
        const SizedBox(height: 8),
        const SizedBox(height: 12),
        Text(
          profile['full_name'] ?? 'FastDriver',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Asap',
            fontWeight: FontWeight.w800,
            fontSize: 23,
          ),
        ),
        Text(
          profile['email'] ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(
            Icons.settings_outlined,
            color: AppColors.blueDeep,
          ),
          title: const Text('Settings'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverSettings(onLogout: onLogout),
              ),
            );
            if (mounted) await onChanged();
          },
        ),
        const AdminDashboardEntry(),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: AppColors.blueDeep,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.swap_horiz_rounded, size: 26),
          label: const Text(
            'Switch to passenger',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Switch to Passenger Mode'),
                content: const Text('Switch to FastRide passenger view?'),
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
            if (confirm == true && context.mounted) {
              await context.read<ModeManager>().switchTo(AppMode.passenger);
            }
          },
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: onLogout,
          child: const Text('Logout', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }
}

class DriverNotifications extends StatelessWidget {
  const DriverNotifications.fromFuture({super.key, required this.jobs});
  final Future<List<Map<String, dynamic>>> jobs;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: jobs,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const DriverEmpty(
            title: 'Updates unavailable',
            message: 'Check your connection and try again.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 18),
              child: Text(
                'Trip activity from your account. Device push notifications are not enabled yet.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
            if (snapshot.data!.isEmpty)
              const DriverEmpty(
                title: 'No updates yet',
                message: 'Your trip activity will appear here.',
              ),
            for (final job in snapshot.data!)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DriverCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      job['status'] == 'completed'
                          ? Icons.check_circle
                          : Icons.route,
                      color: AppColors.blueDeep,
                    ),
                    title: Text(
                      'Trip ${(job['status'] ?? 'updated').toString().replaceAll('_', ' ')}',
                    ),
                    subtitle: Text(
                      '${job['dropoff_address'] ?? 'Destination'}\n${jobDate(job)}',
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class DriverSettings extends StatefulWidget {
  const DriverSettings({super.key, required this.onLogout});
  final Future<void> Function() onLogout;
  @override
  State<DriverSettings> createState() => _DriverSettingsState();
}

class _DriverSettingsState extends State<DriverSettings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          item(
            Icons.person_outline,
            'Personal Information',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PersonalInformationScreen(),
              ),
            ),
          ),
          item(
            Icons.directions_car_outlined,
            'Vehicle Information',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DriverVehicleInformation(),
              ),
            ),
          ),
          item(
            Icons.credit_card_outlined,
            'Payment Methods',
            () => driverInfo(
              context,
              'Cash payments',
              'Cash is active. Mobile Money, cards and wallet payments are not connected yet.',
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: widget.onLogout,
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget item(IconData icon, String title, VoidCallback onTap) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AppColors.blueDeep),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right, size: 20),
    onTap: onTap,
  );
}

class DriverSupport extends StatefulWidget {
  const DriverSupport({super.key});
  @override
  State<DriverSupport> createState() => _DriverSupportState();
}

class _DriverSupportState extends State<DriverSupport> {
  final message = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> report() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: TextField(
          controller: message,
          maxLines: 5,
          maxLength: 2000,
          decoration: const InputDecoration(
            hintText: 'Describe your issue and include the trip reference if available.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (sent != true || busy || !mounted) return;
    if (message.text.trim().length < 10) {
      driverInfo(
        context,
        'Add more detail',
        'Describe your issue using at least 10 characters.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      await Supabase.instance.client.from('driver_support_tickets').insert({
        'driver_id': Supabase.instance.client.auth.currentUser!.id,
        'message': message.text.trim(),
      });
      message.clear();
      if (mounted) {
        driverInfo(
          context,
          'Report received',
          'Your report was saved for review. This is not live chat or an emergency service.',
        );
      }
    } catch (_) {
      if (mounted) {
        driverInfo(
          context,
          'Report not sent',
          'Check your connection and try again. The support database setup must be enabled.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & Support')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final entry in [
          (
            Icons.quiz_outlined,
            'FAQ',
            'Go online to receive requests. Accept one job at a time. Confirm arrival, start your trip and end it after reaching the destination.',
          ),
          (
            Icons.shield_outlined,
            'Safety Tips',
            'Confirm your customer and destination. Keep your phone mounted, wear a helmet when riding and stop safely before using the app.',
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DriverCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(entry.$1, color: AppColors.blueDeep),
                title: Text(entry.$2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => driverInfo(context, entry.$2, entry.$3),
              ),
            ),
          ),
        DriverCard(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.blueDeep,
                ),
                title: const Text('Contact Support'),
                subtitle: const Text('Send an issue report'),
                onTap: busy ? null : report,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.report_outlined,
                  color: AppColors.blueDeep,
                ),
                title: const Text('Report an Issue'),
                onTap: busy ? null : report,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const DriverCard(
          color: Color(0xFFFFEFF1),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.emergency_outlined, color: AppColors.error),
            title: Text('Emergency'),
            subtitle: Text(
              'Use your phone’s emergency calling feature or contact local emergency services directly. FastDriver support is not an emergency service.',
            ),
          ),
        ),
      ],
    ),
  );
}
