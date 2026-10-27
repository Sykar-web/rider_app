import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/profile_photo.dart';
import '../../app/board_widgets.dart';
import '../../services/customer_service.dart';
import '../../services/location_service.dart';
import '../../services/auth_service.dart';
import '../home/location_search_screen.dart';

class FavouritePlacesScreen extends StatefulWidget {
  const FavouritePlacesScreen({super.key});
  @override
  State<FavouritePlacesScreen> createState() => _FavouritePlacesScreenState();
}

class _FavouritePlacesScreenState extends State<FavouritePlacesScreen> {
  final _service = CustomerService();
  late Future<List<Map<String, dynamic>>> _places = _service.places();
  void _refresh() => setState(() {
    _places = _service.places();
  });
  Future<void> _add(String kind) async {
    final place = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationSearchScreen(title: 'Save a place'),
      ),
    );
    if (place == null || !mounted) return;
    try {
      await _service.savePlace(
        kind == 'home'
            ? 'Home'
            : kind == 'work'
            ? 'Work'
            : place.displayName.split(',').first,
        kind,
        place,
      );
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        boardInfo(
          context,
          'Could not save place',
          'Please check your connection and try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Favourite Places'),
      centerTitle: true,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.add, color: AppColors.blueDeep),
          onSelected: _add,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'home', child: Text('Set Home')),
            PopupMenuItem(value: 'work', child: Text('Set Work')),
            PopupMenuItem(value: 'favourite', child: Text('Add favourite')),
          ],
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _places,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: StatusMessage(
              message: 'Could not load saved places.',
              onRetry: _refresh,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(
            child: StatusMessage(
              icon: Icons.star_outline,
              message: 'Your everyday places, one tap away. Use + to save Home, Work or a favourite.',
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(18),
          itemCount: snapshot.data!.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final row = snapshot.data![i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                row['kind'] == 'home'
                    ? Icons.home_rounded
                    : row['kind'] == 'work'
                    ? Icons.work_rounded
                    : Icons.star_rounded,
                color: AppColors.blueDeep,
              ),
              title: Text(
                row['label'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                row['address'] as String,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                tooltip: 'Remove place',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () async {
                  try {
                    await _service.deletePlace(row['id'] as String);
                    if (mounted) _refresh();
                  } catch (_) {
                    if (context.mounted) {
                      boardInfo(
                        context,
                        'Could not remove place',
                        'Please try again.',
                      );
                    }
                  }
                },
              ),
            );
          },
        );
      },
    ),
  );
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.loadWallet});
  final Future<Map<String, dynamic>> Function()? loadWallet;
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Future<Map<String, dynamic>> _load() =>
      widget.loadWallet?.call() ?? CustomerService().wallet();
  late Future<Map<String, dynamic>> _data = _load();
  void _reload() => setState(() {
    _data = _load();
  });
  void _unavailable() => boardInfo(
    context,
    'Wallet payments',
    'Top ups, withdrawals and card payments are not available yet. You can continue booking rides with cash.',
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Wallet'), centerTitle: true),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: StatusMessage(
              message: 'Could not load your wallet.',
              onRetry: _reload,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final account = snapshot.data!['account'] as Map<String, dynamic>?;
        final transactions = snapshot.data!['transactions'] as List;
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            try {
              await _data;
            } catch (_) {}
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Balance',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            account == null
                                ? 'Not activated'
                                : ugx(account['balance_ugx']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _unavailable,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Top Up',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final action in [
                    (Icons.add_circle_outline, 'Top Up'),
                    (Icons.account_balance_wallet_outlined, 'Withdraw'),
                    (Icons.receipt_long_outlined, 'Transactions'),
                    (Icons.credit_card, 'Cards'),
                  ])
                    Expanded(
                      child: InkWell(
                        onTap: action.$2 == 'Transactions'
                            ? () => boardInfo(
                                context,
                                'Transactions',
                                transactions.isEmpty
                                    ? 'There are no wallet transactions yet.'
                                    : 'Your latest wallet transactions are listed below.',
                              )
                            : _unavailable,
                        child: Column(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.blueTint,
                              child: Icon(action.$1, color: AppColors.blueDeep),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              action.$2,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Recent Transactions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (transactions.isEmpty)
                const StatusMessage(
                  icon: Icons.receipt_long_outlined,
                  message: 'No transactions yet. Only confirmed wallet transactions will appear here.',
                ),
              for (final raw in transactions)
                Builder(
                  builder: (context) {
                    final row = raw as Map;
                    final amount = row['amount_ugx'] as num;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: amount >= 0
                            ? const Color(0xFFEAFBF0)
                            : AppColors.blueTint,
                        child: Icon(
                          amount >= 0 ? Icons.add : Icons.directions_car,
                          color: amount >= 0
                              ? AppColors.success
                              : AppColors.blueDeep,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        row['description'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        row['created_at'].toString().split('T').first,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text(
                        '${amount >= 0 ? '+' : '−'}${ugx(amount.abs())}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: amount >= 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    ),
  );
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  void _request(BuildContext context, String category, String title) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              SupportRequestScreen(category: category, title: title),
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Support'), centerTitle: true),
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        BoardAction(
          icon: Icons.chat_bubble_outline,
          title: 'Help Centre',
          subtitle: 'Find answers to common questions',
          onTap: () => boardInfo(
            context,
            'How can we help?',
            'Book a ride by choosing pickup and destination, then confirm your vehicle. Your rides and bus reservations are saved in My Rides. Bus requests need operator confirmation. Cash is currently the supported payment method.',
          ),
        ),
        const Divider(height: 1),
        BoardAction(
          icon: Icons.report_problem_outlined,
          title: 'Report an Issue',
          subtitle: 'Report a problem with a ride',
          onTap: () => _request(context, 'ride_issue', 'Report an Issue'),
        ),
        const Divider(height: 1),
        BoardAction(
          icon: Icons.work_outline,
          title: 'Lost Item',
          subtitle: 'Get help with lost items',
          onTap: () => _request(context, 'lost_item', 'Lost Item'),
        ),
        const Divider(height: 1),
        BoardAction(
          icon: Icons.shield_outlined,
          title: 'Safety',
          subtitle: 'Learn about travel safety',
          onTap: () => boardInfo(
            context,
            'Before every trip',
            'Check your driver and vehicle details before boarding. Wear a helmet for motorcycle rides and a seat belt where available. Share your trip details with someone you trust. For urgent help, contact local emergency services directly.',
          ),
        ),
        const Divider(height: 1),
        BoardAction(
          icon: Icons.headset_mic_outlined,
          title: 'Contact Us',
          subtitle: 'Send a message to the support team',
          onTap: () => _request(context, 'general', 'Contact Us'),
        ),
        const Divider(height: 1),
        BoardAction(
          icon: Icons.emergency_outlined,
          title: 'Emergency',
          subtitle: 'Know what to do in an emergency',
          danger: true,
          onTap: () => boardInfo(
            context,
            'Emergency help',
            'If you are in immediate danger, contact local emergency services or someone you trust directly. FastRide support messages are not monitored as an emergency dispatch service.',
          ),
        ),
        const Divider(height: 1),
        BoardAction(
          icon: Icons.forum_outlined,
          title: 'My support requests',
          subtitle: 'View responses and request status',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const SupportHistoryScreen(),
            ),
          ),
        ),
      ],
    ),
  );
}

class SupportRequestScreen extends StatefulWidget {
  const SupportRequestScreen({
    super.key,
    required this.category,
    required this.title,
  });
  final String category;
  final String title;
  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  final _message = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_message.text.trim().length < 10) {
      setState(() => _error = 'Please include at least 10 characters.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await CustomerService().support(widget.category, _message.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request submitted. Responses will appear in My support requests.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not submit your request. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Tell us what happened',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Include your ride reference if you have one. Never share passwords, PINs or card details.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _message,
          minLines: 5,
          maxLines: 10,
          maxLength: 2000,
          decoration: InputDecoration(
            hintText: 'How can we help?',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Sending...' : 'Submit request'),
        ),
      ],
    ),
  );
}

class SupportHistoryScreen extends StatefulWidget {
  const SupportHistoryScreen({super.key});
  @override
  State<SupportHistoryScreen> createState() => _SupportHistoryScreenState();
}

class _SupportHistoryScreenState extends State<SupportHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _requests = CustomerService()
      .supportRequests();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My support requests')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _requests,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StatusMessage(
            message: 'Could not load requests.',
            onRetry: () => setState(() {
              _requests = CustomerService().supportRequests();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (snapshot.data!.isEmpty)
              const StatusMessage(message: 'No support requests yet.'),
            for (final row in snapshot.data!)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BoardCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['category'].toString().replaceAll('_', ' '),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(row['message'] as String),
                      const SizedBox(height: 8),
                      Text(
                        row['status'] as String,
                        style: const TextStyle(color: AppColors.blueDeep),
                      ),
                      if (row['response'] != null) ...[
                        const Divider(),
                        Text(row['response'] as String),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true, _updates = true, _offers = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await CustomerService().preferences();
      if (mounted) {
        setState(() {
          _updates = row['trip_updates'] as bool? ?? true;
          _offers = row['offers'] as bool? ?? false;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load preferences.';
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await CustomerService().savePreferences(_updates, _offers);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Preferences saved.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save preferences. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Trip updates'),
                subtitle: const Text(
                  'Your preference for booking and journey updates',
                ),
                value: _updates,
                onChanged: (v) => setState(() => _updates = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Offers and news'),
                subtitle: const Text(
                  'Choose whether to receive promotional updates',
                ),
                value: _offers,
                onChanged: (v) => setState(() => _offers = v),
              ),
              const SizedBox(height: 16),
              const Text(
                'These preferences do not enable device push notifications. Delivery of updates depends on available notification services.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save preferences'),
              ),
            ],
          ),
  );
}

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});
  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final _name = TextEditingController(), _phone = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await AuthService().getCurrentProfile();
      if (!mounted) return;
      _name.text = row?['full_name'] as String? ?? '';
      _phone.text = row?['phone'] as String? ?? '';
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load your details.';
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService().updateProfile(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save changes. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Personal Information')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Center(child: ProfilePhoto(radius: 46, editable: true)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 2
                      ? 'Enter your registered name.'
                      : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) =>
                      RegExp(r'^\+?[0-9\s]{9,16}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Enter a valid phone number.',
                ),
                const SizedBox(height: 18),
                BoardCard(
                  child: Text(
                    AuthService().currentUser?.email ?? 'No email address',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save changes'),
                ),
              ],
            ),
          ),
  );
}
