import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../app/board_widgets.dart';
import '../../services/admin_service.dart';

class AdminDashboardEntry extends StatelessWidget {
  const AdminDashboardEntry({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, _) => AdminService().allowedAccount
        ? ListTile(
            leading: const Icon(
              Icons.admin_panel_settings_outlined,
              color: AppColors.blueDeep,
            ),
            title: const Text('Admin Dashboard'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
            ),
          )
        : const SizedBox.shrink(),
  );
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, this.service});
  final AdminService? service;
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminService service = widget.service ?? AdminService();
  final pin = TextEditingController(), search = TextEditingController();
  Timer? expiry, debounce;
  StreamSubscription<bool>? auth;
  bool unlocked = false, busy = false;
  int page = 0, revision = 0;
  String section = 'overview';
  String? error;
  Map<String, dynamic> content = {};
  static const sections = {
    'overview': 'Overview',
    'applications': 'Driver applications',
    'people': 'People & driver access',
    'rides': 'Rides',
    'deliveries': 'Deliveries',
    'companies': 'Bus companies',
    'schedules': 'Bus departures',
    'support': 'Support inbox',
    'audit': 'Admin activity',
  };
  @override
  void initState() {
    super.initState();
    auth = service.accountChanges.listen((allowed) {
      if (!allowed && mounted) _lock();
    });
  }

  @override
  void dispose() {
    expiry?.cancel();
    debounce?.cancel();
    auth?.cancel();
    pin.dispose();
    search.dispose();
    unawaited(service.lock().catchError((Object _) {}));
    super.dispose();
  }

  void _lock({String? message}) {
    expiry?.cancel();
    debounce?.cancel();
    revision++;
    final dashboardRoute = ModalRoute.of(context);
    if (dashboardRoute != null) {
      Navigator.of(context).popUntil((r) => r == dashboardRoute);
    }
    setState(() {
      unlocked = false;
      busy = false;
      content = {};
      error = message;
      pin.clear();
      search.clear();
    });
    unawaited(service.lock().catchError((Object _) {}));
  }

  String _message(Object e) =>
      e is FormatException ? e.message : 'Check your connection and try again.';
  Future<void> _unlock() async {
    if (busy || !RegExp(r'^\d{4}$').hasMatch(pin.text)) {
      setState(() => error = 'Enter your four-digit PIN.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await service.unlock(pin.text);
      pin.clear();
      if (!mounted) return;
      if (result['ok'] != true) {
        final seconds = (result['retry_after'] as num?)?.toInt() ?? 0;
        setState(
          () => error = seconds > 0
              ? 'Too many attempts. Try again in ${(seconds / 60).ceil()} minutes.'
              : 'PIN not accepted. Try again.',
        );
        return;
      }
      final until = DateTime.tryParse(result['expires_at']?.toString() ?? '');
      if (until == null || until.isBefore(DateTime.now())) {
        throw AdminAccessExpired();
      }
      expiry = Timer(until.difference(DateTime.now()), () {
        if (mounted) {
          _lock(message: 'Your admin session expired. Enter your PIN again.');
        }
      });
      setState(() {
        unlocked = true;
        section = 'overview';
        page = 0;
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AdminAccessExpired
              ? 'Please unlock the dashboard again.'
              : _message(e),
        );
      }
    } finally {
      pin.clear();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _load() async {
    if (!unlocked) return;
    final request = ++revision;
    setState(() {
      busy = true;
      error = null;
      content = {};
    });
    try {
      final result = await service.data(
        section,
        search: search.text.trim(),
        page: page,
      );
      if (mounted && unlocked && request == revision) {
        setState(() => content = result);
      }
    } on AdminAccessExpired {
      if (mounted) _lock(message: 'Enter your PIN to continue.');
    } catch (e) {
      if (mounted && request == revision) setState(() => error = _message(e));
    } finally {
      if (mounted && request == revision) setState(() => busy = false);
    }
  }

  Future<bool> _action(
    String name, {
    String? target,
    Map<String, dynamic> details = const {},
  }) async {
    if (!unlocked || busy) return false;
    setState(() => busy = true);
    try {
      await service.action(name, target: target, details: details);
      if (!mounted || !unlocked) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Change saved')));
      await _load();
      return true;
    } on AdminAccessExpired {
      if (mounted) _lock(message: 'Enter your PIN to continue.');
    } catch (e) {
      if (mounted) boardInfo(context, 'Change not saved', _message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
    return false;
  }

  Future<void> _document(String bucket, String path) async {
    if (!unlocked) return;
    try {
      final uri = Uri.parse(await service.documentUrl(bucket, path));
      if (!mounted || !unlocked) return;
      final image = !path.toLowerCase().endsWith('.pdf');
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Application document'),
          content: SizedBox(
            width: 400,
            height: 360,
            child: image
                ? Image.network(
                    uri.toString(),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Center(
                      child: Text(
                        'The preview has expired. Close and open it again.',
                      ),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.picture_as_pdf_outlined, size: 70),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                if (!await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    ) &&
                    c.mounted) {
                  ScaffoldMessenger.of(c).showSnackBar(
                    const SnackBar(content: Text('Could not open document.')),
                  );
                }
              },
              child: const Text('Open document'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        boardInfo(
          context,
          'Document unavailable',
          'Unlock again if your session expired, then retry.',
        );
      }
    }
  }

  Future<String?> _reason(String title) => _form(
    title,
    {'reason': ''},
    labels: {'reason': 'Reason (required)'},
    multiline: const {'reason'},
  ).then((v) => v?['reason']);
  Future<Map<String, String>?> _form(
    String title,
    Map<String, String> initial, {
    Map<String, String> labels = const {},
    Set<String> multiline = const {},
    Map<String, List<String>> choices = const {},
  }) async {
    final controllers = {
      for (final e in initial.entries)
        e.key: TextEditingController(text: e.value),
    };
    final form = GlobalKey<FormState>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in controllers.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: choices.containsKey(e.key)
                          ? DropdownButtonFormField<String>(
                              initialValue:
                                  choices[e.key]!.contains(e.value.text)
                                  ? e.value.text
                                  : choices[e.key]!.first,
                              decoration: InputDecoration(
                                labelText: labels[e.key] ?? _label(e.key),
                              ),
                              items: [
                                for (final value in choices[e.key]!)
                                  DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                              ],
                              onChanged: (v) => e.value.text = v!,
                            )
                          : TextFormField(
                              controller: e.value,
                              minLines: multiline.contains(e.key) ? 3 : 1,
                              maxLines: multiline.contains(e.key) ? 5 : 1,
                              decoration: InputDecoration(
                                labelText: labels[e.key] ?? _label(e.key),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(c, {
                  for (final e in controllers.entries)
                    e.key: e.value.text.trim(),
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Controllers remain alive while the dialog closes.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final c in controllers.values) {
      c.dispose();
    }
    return result;
  }

  String _label(String s) => s
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
  Future<void> _company([Map<String, dynamic>? row]) async {
    final values = await _form(
      row == null ? 'Add bus company' : 'Edit bus company',
      {
        'name': row?['name'] ?? '',
        'is_active': (row?['is_active'] ?? true).toString(),
      },
      choices: {
        'is_active': ['true', 'false'],
      },
      labels: {'is_active': 'Available for booking'},
    );
    if (values != null) {
      await _action(
        'save_company',
        target: row?['id'],
        details: {
          'name': values['name'],
          'is_active': values['is_active'] == 'true',
        },
      );
    }
  }

  Future<void> _schedule([Map<String, dynamic>? row]) async {
    // Page through companies so the editor is not limited to the first 50.
    try {
      final companies = <Map<String, dynamic>>[];
      for (var i = 0; i < 1001; i++) {
        final batch =
            ((await service.data('companies', page: i))['rows'] as List)
                .cast<Map<String, dynamic>>();
        companies.addAll(batch);
        if (batch.length < 50) break;
      }
      if (!mounted || !unlocked) return;
      if (companies.isEmpty) {
        boardInfo(
          context,
          'Add a company first',
          'Create a bus company before adding its departure.',
        );
        return;
      }
      final names = {for (final c in companies) '${c['name']}': c['id']};
      final selected = companies
          .where((c) => c['id'] == row?['company_id'])
          .firstOrNull;
      final values = await _form(
        row == null ? 'Add bus departure' : 'Edit bus departure',
        {
          'company': selected?['name'] ?? companies.first['name'],
          'origin': row?['origin'] ?? 'Arua',
          'destination': row?['destination'] ?? '',
          'departure_time': row?['departure_time'] ?? '08:00',
          'arrival_time': row?['arrival_time'] ?? '16:00',
          'duration_minutes': '${row?['duration_minutes'] ?? 480}',
          'service_class': row?['service_class'] ?? 'ordinary',
          'total_seats': '${row?['total_seats'] ?? 40}',
          'is_active': '${row?['is_active'] ?? true}',
        },
        choices: {
          'company': names.keys.toList(),
          'service_class': ['ordinary', 'executive'],
          'is_active': ['true', 'false'],
        },
        labels: {
          'departure_time': 'Departure time (24-hour HH:mm)',
          'arrival_time': 'Arrival time (24-hour HH:mm)',
          'duration_minutes': 'Travel duration in minutes',
          'is_active': 'Available for booking',
        },
      );
      if (values == null || !mounted || !unlocked) return;
      final time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$');
      final seats = int.tryParse(values['total_seats']!),
          duration = int.tryParse(values['duration_minutes']!);
      if (!time.hasMatch(values['departure_time']!) ||
          !time.hasMatch(values['arrival_time']!) ||
          seats == null ||
          seats < 1 ||
          seats > 80 ||
          duration == null ||
          duration < 1) {
        boardInfo(
          context,
          'Check departure details',
          'Use 24-hour times, 1–80 seats, and a positive travel duration.',
        );
        return;
      }
      await _action(
        'save_schedule',
        target: row?['id'],
        details: {
          ...values,
          'company_id': names[values['company']],
          'total_seats': seats,
          'duration_minutes': duration,
          'is_active': values['is_active'] == 'true',
        },
      );
    } on AdminAccessExpired {
      if (mounted) _lock(message: 'Enter your PIN to continue.');
    } catch (e) {
      if (mounted) boardInfo(context, 'Departures unavailable', _message(e));
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final chosenSection = section;
    final details = row['details'] as Map? ?? {};
    final docs = details['documents'] as Map? ?? {};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            height: MediaQuery.sizeOf(c).height * .75,
            child: ListView(
              children: [
                Text(
                  _title(row),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                for (final e in row.entries.where(
                  (e) =>
                      !['details', 'avatar_path'].contains(e.key) &&
                      e.value != null,
                ))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_label(e.key)),
                    subtitle: SelectableText(e.value.toString()),
                  ),
                if (chosenSection == 'applications') ...[
                  for (final e in details.entries.where(
                    (e) => e.key != 'documents',
                  ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_label(e.key)),
                      subtitle: SelectableText(e.value.toString()),
                    ),
                  if (row['avatar_path'] is String)
                    TextButton.icon(
                      onPressed: () =>
                          _document('profile-photos', row['avatar_path']),
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Shared profile photo'),
                    ),
                  for (final e in docs.entries)
                    TextButton.icon(
                      onPressed: () =>
                          _document('driver-documents', e.value.toString()),
                      icon: const Icon(Icons.description_outlined),
                      label: Text(e.key.toString()),
                    ),
                  if (row['status'] == 'pending') ...[
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final yes = await boardConfirm(
                                context,
                                title: 'Approve driver?',
                                message: 'Confirm you have reviewed all documents and vehicle details.',
                                confirmLabel: 'Approve',
                              );
                              if (yes && mounted && unlocked) {
                                if (c.mounted) Navigator.pop(c);
                                await _action(
                                  'review_application',
                                  target: row['user_id'],
                                  details: {'approved': true},
                                );
                              }
                            },
                      child: const Text('Approve application'),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final reason = await _reason(
                                'Reject application',
                              );
                              if (reason != null && mounted && unlocked) {
                                if (c.mounted) Navigator.pop(c);
                                await _action(
                                  'review_application',
                                  target: row['user_id'],
                                  details: {
                                    'approved': false,
                                    'reason': reason,
                                  },
                                );
                              }
                            },
                      child: const Text('Reject application'),
                    ),
                  ],
                ],
                if (chosenSection == 'people')
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final approved = row['driver_approved'] != true;
                            final reason = await _reason(
                              approved
                                  ? 'Restore driver access'
                                  : 'Suspend driver access',
                            );
                            if (reason != null && mounted && unlocked) {
                              if (c.mounted) Navigator.pop(c);
                              await _action(
                                'driver_access',
                                target: row['id'],
                                details: {
                                  'approved': approved,
                                  'reason': reason,
                                },
                              );
                            }
                          },
                    child: Text(
                      row['driver_approved'] == true
                          ? 'Suspend driver access'
                          : 'Restore approved driver access',
                    ),
                  ),
                if (['rides', 'deliveries'].contains(chosenSection) &&
                    !['completed', 'cancelled'].contains(row['status']))
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final reason = await _reason('Cancel booking');
                            if (reason != null && mounted && unlocked) {
                              if (c.mounted) Navigator.pop(c);
                              await _action(
                                'cancel_booking',
                                target: row['id'],
                                details: {
                                  'kind': chosenSection,
                                  'reason': reason,
                                },
                              );
                            }
                          },
                    child: const Text('Cancel booking'),
                  ),
                if (chosenSection == 'support')
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final response = await _form(
                              'Reply to request',
                              {
                                'response': row['response'] ?? '',
                                'status': row['status'] ?? 'open',
                              },
                              multiline: {'response'},
                              choices: {
                                'status': ['open', 'in_review', 'resolved'],
                              },
                            );
                            if (response != null && mounted && unlocked) {
                              if (c.mounted) Navigator.pop(c);
                              await _action(
                                'support_reply',
                                target: row['id'],
                                details: response,
                              );
                            }
                          },
                    child: const Text('Reply & update status'),
                  ),
                if (chosenSection == 'companies')
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(c);
                      _company(row);
                    },
                    child: const Text('Edit company'),
                  ),
                if (chosenSection == 'schedules')
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(c);
                      _schedule(row);
                    },
                    child: const Text('Edit departure'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _title(Map<String, dynamic> row) => switch (section) {
    'applications' =>
      (row['details'] as Map?)?['full_name']?.toString() ??
          row['email']?.toString() ??
          'Driver application',
    'people' =>
      row['full_name']?.toString() ?? row['email']?.toString() ?? 'Account',
    'companies' => row['name']?.toString() ?? 'Bus company',
    'schedules' =>
      '${row['company_name']} · ${row['origin']} → ${row['destination']}',
    'support' => _label(row['category']?.toString() ?? 'Support request'),
    'audit' => _label(row['action']?.toString() ?? 'Admin activity'),
    _ =>
      '${row['pickup_address'] ?? 'Pickup'} → ${row['dropoff_address'] ?? 'Destination'}',
  };
  @override
  Widget build(BuildContext context) {
    if (!service.allowedAccount) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: const Center(
          child: Text('This dashboard is restricted to the administrator.'),
        ),
      );
    }
    final rows = (content['rows'] as List? ?? []).cast<Map<String, dynamic>>();
    final stats = content['stats'] as Map? ?? {};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          if (unlocked)
            IconButton(
              tooltip: 'Lock dashboard',
              onPressed: () => _lock(),
              icon: const Icon(Icons.lock_outline),
            ),
        ],
      ),
      body: !unlocked
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.blueTint,
                        child: Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 34,
                          color: AppColors.blueDeep,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Administrator access',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your PIN to manage FastRide.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: pin,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Admin PIN',
                        ),
                        onSubmitted: (_) => _unlock(),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            error!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy ? null : _unlock,
                        child: Text(busy ? 'Checking…' : 'Unlock dashboard'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'FastRide operations',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: section,
                    decoration: const InputDecoration(labelText: 'Manage'),
                    items: [
                      for (final e in sections.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            debounce?.cancel();
                            setState(() {
                              section = v!;
                              page = 0;
                              search.clear();
                            });
                            _load();
                          },
                  ),
                  if (section != 'overview') ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search this section',
                      ),
                      onChanged: (_) {
                        debounce?.cancel();
                        debounce = Timer(const Duration(milliseconds: 350), () {
                          page = 0;
                          _load();
                        });
                      },
                    ),
                  ],
                  if (['companies', 'schedules'].contains(section))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => section == 'companies'
                                  ? _company()
                                  : _schedule(),
                        icon: const Icon(Icons.add),
                        label: Text(
                          section == 'companies'
                              ? 'Add bus company'
                              : 'Add departure',
                        ),
                      ),
                    ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(error!),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  if (section == 'overview') ...[
                    for (final e in stats.entries)
                      Card(
                        child: ListTile(
                          title: Text(_label(e.key)),
                          trailing: Text(
                            '${e.value}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Recorded fares are completed trip amounts. Payments currently use cash.',
                      ),
                    ),
                  ],
                  if (section != 'overview' &&
                      !busy &&
                      error == null &&
                      rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No records found.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final row in rows)
                    Card(
                      child: ListTile(
                        title: Text(_title(row)),
                        subtitle: Text(
                          '${row['status'] ?? row['email'] ?? row['created_at'] ?? (row['is_active'] == true ? 'Available' : 'Paused')}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(row),
                      ),
                    ),
                  if (section != 'overview')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: busy || page == 0
                              ? null
                              : () {
                                  page--;
                                  _load();
                                },
                          child: const Text('Previous'),
                        ),
                        Text('Page ${page + 1}'),
                        TextButton(
                          onPressed: busy || rows.length < 50
                              ? null
                              : () {
                                  page++;
                                  _load();
                                },
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}
