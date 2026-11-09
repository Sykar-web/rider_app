import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/profile_photo.dart';
import '../../../core/mode_manager/mode_manager.dart';
import '../../../services/auth_service.dart' as shared;
import '../../app/theme.dart';
import '../../services/driver_application_service.dart';

class DriverApplicationForm extends StatefulWidget {
  const DriverApplicationForm({super.key, this.service});
  final DriverApplicationService? service;
  @override
  State<DriverApplicationForm> createState() => _DriverApplicationFormState();
}

class _DriverApplicationFormState extends State<DriverApplicationForm> {
  late final DriverApplicationService service;
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  void top() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && scroll.hasClients) scroll.jumpTo(0);
  });
  final fields = {
    for (final key in [
      'full_name',
      'phone',
      'email',
      'home_area',
      'licence_number',
      'licence_expiry',
      'make',
      'model',
      'year',
      'colour',
      'registration_number',
    ])
      key: TextEditingController(),
  };
  final documents = <String, String>{};
  Map<String, dynamic> profile = {};
  String vehicle = 'Car', status = 'draft';
  int step = 0;
  bool loading = true, busy = false, consent = false, viewing = false;
  String? error;
  bool get pending => status == 'pending' || status == 'approved';
  bool get hasPhoto =>
      [
        'avatar_path',
        'avatar_url',
        'picture',
        'driver_profile_photo',
      ].any((key) => (profile[key]?.toString() ?? '').isNotEmpty) ||
      documents.containsKey('Profile Photo');

  @override
  void initState() {
    super.initState();
    service = widget.service ?? DriverApplicationService();
    load();
  }

  @override
  void dispose() {
    scroll.dispose();
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await service.load();
      if (!mounted) return;
      profile = Map<String, dynamic>.from(result['profile'] as Map);
      final data = Map<String, dynamic>.from(result['data'] as Map);
      for (final entry in fields.entries) {
        final existing = profile[entry.key]?.toString().trim() ?? '';
        entry.value.text = existing.isNotEmpty
            ? existing
            : (data[entry.key] ?? '').toString();
      }
      documents.addAll(
        Map<String, String>.from(data['documents'] as Map? ?? {}),
      );
      vehicle =
          ['Car', 'Motorcycle', 'Van', 'Bus'].contains(data['vehicle_type'])
          ? data['vehicle_type'] as String
          : 'Car';
      status = result['status'].toString();
      step = (data['step'] as num? ?? 0).toInt().clamp(0, 3);
      if (status == 'rejected') error = 'Your application needs an update. Review your details and submit again.';
    } catch (_) {
      error = 'We could not load your application. Check your connection and try again.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Map<String, dynamic> details() => {
    for (final e in fields.entries) e.key: e.value.text.trim(),
    'vehicle_type': vehicle,
    'documents': Map<String, String>.from(documents),
    'uses_shared_photo': hasPhoto,
    'step': step,
    'consent': consent,
  };

  Future<void> save({bool submit = false, bool exit = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Only fill absent shared fields. Applying must never overwrite an existing profile.
      if (submit) {
        await shared.AuthService().updateProfile(
          fullName: (profile['full_name']?.toString() ?? '').isEmpty
              ? fields['full_name']!.text.trim()
              : null,
          phone: (profile['phone']?.toString() ?? '').isEmpty
              ? fields['phone']!.text.trim()
              : null,
        );
      }
      await service.save(details(), submit: submit);
      if (!mounted) return;
      if (submit) {
        setState(() {
          status = 'pending';
          viewing = false;
        });
      } else if (exit) {
        leave();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not save your application. Your entries are still here. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void leave() {
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    } else {
      context.read<ModeManager>().switchTo(AppMode.passenger);
    }
  }

  Future<void> checkApproval() async {
    setState(() => busy = true);
    try {
      await service.client.auth.refreshSession();
      if (!mounted) return;
      if (service.client.auth.currentUser?.appMetadata['driver_approved'] ==
          true) {
        await context.read<ModeManager>().switchTo(AppMode.driver);
      } else {
        await load();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not check your application status. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick(String label) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final imageOnly = label == 'Vehicle Photo' || label == 'Profile Photo';
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: imageOnly
            ? ['jpg', 'jpeg', 'png']
            : ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      if (result == null || !mounted) return;
      if (label == 'Profile Photo') {
        final file = result.files.single;
        if (file.bytes == null) {
          throw const FormatException('Please choose another file.');
        }
        await shared.AuthService().uploadAvatar(file.bytes!);
        profile = {
          ...profile,
          ...?await shared.AuthService().getCurrentProfile(),
        };
      } else {
        documents[label] = await service.upload(label, result.files.single);
      }
      await service.save(details());
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not save the file. Choose JPG, PNG or PDF under 5 MB and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> next() async {
    if (!(form.currentState?.validate() ?? false)) return;
    if (step == 1 &&
        (!hasPhoto ||
            ![
              'National ID front',
              'National ID back',
              'Driving License',
            ].every(documents.containsKey))) {
      setState(() => error = 'Add the missing documents to continue.');
      top();
      return;
    }
    if (step == 2 && !documents.containsKey('Vehicle Photo')) {
      setState(() => error = 'Add a vehicle photo to continue.');
      top();
      return;
    }
    await save();
    if (mounted && error == null) {
      setState(() {
        step++;
        error = null;
      });
      top();
    }
  }

  Widget field(String key, String label, {bool missingOnly = false}) {
    if (missingOnly && (profile[key]?.toString().trim() ?? '').isNotEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey(key),
        controller: fields[key],
        enabled: !pending && !busy,
        keyboardType: key == 'phone'
            ? TextInputType.phone
            : key == 'email'
            ? TextInputType.emailAddress
            : key == 'year'
            ? TextInputType.number
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Enter $label';
          if (key == 'phone' && !RegExp(r'^\+?[0-9\s]{9,16}$').hasMatch(text)) {
            return 'Enter a valid phone number';
          }
          if (key == 'email' &&
              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
            return 'Enter a valid email';
          }
          if (key == 'year' &&
              ((int.tryParse(text) ?? 0) < 1980 ||
                  (int.tryParse(text) ?? 9999) > DateTime.now().year + 1)) {
            return 'Enter a valid year';
          }
          if (key == 'licence_expiry') {
            final date = DateTime.tryParse(text);
            if (date == null ||
                date.isBefore(DateUtils.dateOnly(DateTime.now()))) {
              return 'Use YYYY-MM-DD, with a future expiry';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.hairline),
    ),
    child: child,
  );
  Widget upload(String label) => card(
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        documents.containsKey(label)
            ? Icons.check_circle
            : Icons.upload_file_outlined,
        color: documents.containsKey(label)
            ? AppColors.success
            : AppColors.blueDeep,
      ),
      title: Text(label),
      subtitle: Text(
        documents.containsKey(label)
            ? 'Saved to your application'
            : 'JPG, PNG or PDF · up to 5 MB',
      ),
      trailing: pending
          ? null
          : TextButton(
              onPressed: busy ? null : () => pick(label),
              child: Text(documents.containsKey(label) ? 'Replace' : 'Upload'),
            ),
    ),
  );
  Widget sharedProfile() => card(
    Row(
      children: [
        const ProfilePhoto(radius: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fields['full_name']!.text.isEmpty
                    ? 'Your shared profile'
                    : fields['full_name']!.text,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(fields['phone']!.text),
              Text(fields['email']!.text),
              const Text(
                'Reused from your passenger profile',
                style: TextStyle(color: AppColors.success, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Personal details',
      'Driver documents',
      'Vehicle details',
      'Review & submit',
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF2FAFC),
      appBar: AppBar(
        title: Text(pending ? 'Your application' : 'Apply to drive'),
        leading: IconButton(
          onPressed: busy ? null : leave,
          icon: const Icon(Icons.close),
        ),
        actions: [
          if (!pending && !loading)
            TextButton(
              onPressed: busy ? null : () => save(exit: true),
              child: const Text('Save & exit'),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (error != null)
                      card(
                        Column(
                          children: [
                            Text(
                              error!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                            if (profile.isEmpty)
                              TextButton(
                                onPressed: load,
                                child: const Text('Try again'),
                              ),
                          ],
                        ),
                      ),
                    if (profile.isNotEmpty && pending && !viewing) ...[
                      const SizedBox(height: 28),
                      const Icon(
                        Icons.schedule_rounded,
                        size: 82,
                        color: AppColors.blueDeep,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        status == 'approved'
                            ? 'Application approved'
                            : 'Application under review',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your passenger account and photo stay the same. You can continue using FastRide while your application is reviewed.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      sharedProfile(),
                      OutlinedButton(
                        onPressed: busy ? null : checkApproval,
                        child: Text(
                          status == 'approved'
                              ? 'Open driver mode'
                              : 'Check approval status',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setState(() => viewing = true);
                          top();
                        },
                        child: const Text('View application'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: leave,
                        child: const Text('Continue as passenger'),
                      ),
                    ] else if (profile.isNotEmpty) ...[
                      if (!pending)
                        Row(
                          children: [
                            for (var i = 0; i < 4; i++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: i <= step
                                            ? AppColors.blueDeep
                                            : AppColors.blueTint,
                                        foregroundColor: i <= step
                                            ? Colors.white
                                            : AppColors.textMuted,
                                        child: i < step
                                            ? const Icon(Icons.check)
                                            : Text('${i + 1}'),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        [
                                          'Profile',
                                          'Documents',
                                          'Vehicle',
                                          'Review',
                                        ][i],
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      Text(
                        pending ? 'Application details' : titles[step],
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'One account. Only add what is missing.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 24),
                      Form(
                        key: form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (step == 0 && !pending) ...[
                              sharedProfile(),
                              field(
                                'full_name',
                                'Full name',
                                missingOnly: true,
                              ),
                              field('phone', 'Phone number', missingOnly: true),
                              field('email', 'Email', missingOnly: true),
                              field(
                                'home_area',
                                'Home area',
                                missingOnly: true,
                              ),
                            ],
                            if (step == 1 && !pending) ...[
                              sharedProfile(),
                              if (!hasPhoto)
                                OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => pick('Profile Photo'),
                                  icon: const Icon(Icons.add_a_photo),
                                  label: const Text(
                                    'Add missing profile photo',
                                  ),
                                ),
                              upload('National ID front'),
                              upload('National ID back'),
                              upload('Driving License'),
                              field('licence_number', 'Driving licence number'),
                              field(
                                'licence_expiry',
                                'Licence expiry (YYYY-MM-DD)',
                              ),
                            ],
                            if (step == 2 && !pending) ...[
                              DropdownButtonFormField<String>(
                                initialValue: vehicle,
                                decoration: const InputDecoration(
                                  labelText: 'Vehicle type',
                                ),
                                items: ['Motorcycle', 'Car', 'Van', 'Bus']
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v),
                                      ),
                                    )
                                    .toList(),
                                onChanged: busy
                                    ? null
                                    : (v) => setState(() => vehicle = v!),
                              ),
                              const SizedBox(height: 16),
                              for (final key in [
                                'make',
                                'model',
                                'year',
                                'colour',
                                'registration_number',
                              ])
                                field(
                                  key,
                                  {
                                    'make': 'Make',
                                    'model': 'Model',
                                    'year': 'Year',
                                    'colour': 'Colour',
                                    'registration_number': 'Plate number',
                                  }[key]!,
                                ),
                              upload('Vehicle Photo'),
                            ],
                            if (step == 3 || pending) ...[
                              sharedProfile(),
                              card(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Application summary',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    for (final e in fields.entries.where(
                                      (e) => ![
                                        'full_name',
                                        'phone',
                                        'email',
                                      ].contains(e.key),
                                    ))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(
                                          '${e.key.replaceAll('_', ' ')}: ${e.value.text}',
                                        ),
                                      ),
                                    Text('Vehicle: $vehicle'),
                                    for (final doc in documents.keys)
                                      ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.check_circle,
                                          color: AppColors.success,
                                        ),
                                        title: Text(doc),
                                      ),
                                  ],
                                ),
                              ),
                              if (!pending)
                                CheckboxListTile(
                                  value: consent,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: busy
                                      ? null
                                      : (v) => setState(() => consent = v!),
                                  title: const Text(
                                    'I confirm my information and documents are accurate.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!pending)
                        FilledButton(
                          onPressed: busy || (step == 3 && !consent)
                              ? null
                              : step == 3
                              ? () => save(submit: true)
                              : next,
                          child: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  step == 3
                                      ? 'Submit for approval'
                                      : 'Continue',
                                ),
                        ),
                      if (!pending && step > 0)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  step--;
                                  error = null;
                                }),
                          child: const Text('Back'),
                        ),
                      if (pending)
                        TextButton(
                          onPressed: () {
                            setState(() => viewing = false);
                            top();
                          },
                          child: const Text('Back to status'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
