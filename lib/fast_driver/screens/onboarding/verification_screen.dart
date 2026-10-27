import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/onboarding_widgets.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final vehicleForm = GlobalKey<FormState>();
  final make = TextEditingController();
  final model = TextEditingController();
  final year = TextEditingController();
  final colour = TextEditingController();
  final plate = TextEditingController();
  final documents = <String, PlatformFile>{};
  static const documentTypes = [
    'Profile Photo',
    'National ID',
    'Driving License',
  ];
  String fullName = '';
  String phoneNumber = '';
  String vehicleType = 'Car';
  int step = 0;
  bool busy = false;
  bool submitted = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final metadata =
        Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
    fullName = metadata['full_name']?.toString() ?? '';
    phoneNumber = metadata['phone']?.toString() ?? '';
    submitted = metadata['driver_application_status'] == 'pending';
  }

  @override
  void dispose() {
    for (final controller in [make, model, year, colour, plate]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> pick(String type) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: type == 'Profile Photo'
            ? ['jpg', 'jpeg', 'png']
            : ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.size > 10 * 1024 * 1024 || file.bytes == null) {
        setState(() => error = 'Choose a file smaller than 10 MB.');
        return;
      }
      setState(() => documents[type] = file);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not open the file. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void next() {
    if (step == 0 && documents.length != 3) {
      setState(() => error = 'Please add all three documents to continue.');
      return;
    }
    if (step == 1 && !vehicleForm.currentState!.validate()) return;
    setState(() {
      step++;
      error = null;
    });
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser!;
      final uploaded = <String, String>{};
      for (final entry in documents.entries) {
        final extension = entry.value.extension?.toLowerCase() ?? 'jpg';
        final path =
            '${user.id}/${entry.key.toLowerCase().replaceAll(' ', '_')}.$extension';
        await client.storage
            .from('driver-documents')
            .uploadBinary(
              path,
              entry.value.bytes!,
              fileOptions: FileOptions(
                upsert: true,
                contentType: extension == 'pdf'
                    ? 'application/pdf'
                    : extension == 'png'
                    ? 'image/png'
                    : 'image/jpeg',
              ),
            );
        uploaded[entry.key] = path;
      }
      // This is an application only. Approval must be granted by a trusted server/admin.
      await client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': fullName,
            'phone': phoneNumber,
            'driver_onboarding_required': true,
            'driver_application_status': 'pending',
            'driver_application': {
              'vehicle_type': vehicleType,
              'make': make.text.trim(),
              'model': model.text.trim(),
              'year': int.parse(year.text.trim()),
              'colour': colour.text.trim(),
              'registration_number': plate.text.trim().toUpperCase(),
              'documents': uploaded,
              'submitted_at': DateTime.now().toUtc().toIso8601String(),
            },
          },
        ),
      );
      if (mounted) setState(() => submitted = true);
    } on StorageException catch (_) {
      if (mounted) {
        setState(
          () => error = 'Documents could not be saved. Please try again or contact support.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Submission failed. Your details are still here; please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editPersonal() async {
    final nameController = TextEditingController(text: fullName);
    final phoneController = TextEditingController(text: phoneNumber);
    final personalForm = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Personal Information'),
        content: Form(
          key: personalForm,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter your full name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
                validator: (v) =>
                    !RegExp(r'^\+?[0-9\s]{9,16}$').hasMatch(v?.trim() ?? '')
                    ? 'Enter a valid phone number'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (personalForm.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        fullName = nameController.text.trim();
        phoneNumber = phoneController.text.trim();
      });
    }
    // Dialog route animations can still reference these controllers until unmounted.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    nameController.dispose();
    phoneController.dispose();
  }

  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      text,
      style: const TextStyle(
        color: onboardingNavy,
        fontWeight: FontWeight.w700,
        fontSize: 17,
      ),
    ),
  );
  Widget field(
    String label,
    TextEditingController controller, {
    bool isYear = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      keyboardType: isYear ? TextInputType.number : TextInputType.text,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Enter $label';
        if (isYear) {
          final number = int.tryParse(value.trim());
          if (number == null ||
              number < 1980 ||
              number > DateTime.now().year + 1) {
            return 'Enter a valid year';
          }
        }
        return null;
      },
    ),
  );
  Widget reviewCard(
    String title,
    IconData icon,
    List<String> lines,
    int editStep,
  ) => Card(
    elevation: 0,
    color: const Color(0xFFF6FAFF),
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFFEAF0F8)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: heading(title)),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        if (editStep < 0) {
                          editPersonal();
                        } else {
                          setState(() => step = editStep);
                        }
                      },
                child: const Text('Edit'),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 34, color: onboardingBlue),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(line),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (submitted) {
      return OnboardingPage(
        title: 'Application Submitted',
        back: false,
        subtitle: 'Your driver application is awaiting review.',
        children: [
          const SizedBox(height: 35),
          const Icon(Icons.task_alt, size: 88, color: onboardingBlue),
          const SizedBox(height: 24),
          const Text(
            'Your documents and vehicle details have been submitted. You can start accepting rides once your application is approved.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      await Supabase.instance.client.auth.signOut();
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => error = 'Could not sign out. Please try again.',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: const Text('Sign out'),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && step > 0 && !busy) {
          setState(() {
            step--;
            error = null;
          });
        }
      },
      child: OnboardingPage(
        back: false,
        title: [
          'Verify Your Account',
          'Vehicle Details',
          'Review & Submit',
        ][step],
        subtitle: step == 2
            ? 'Make sure your information is correct'
            : 'A few steps before you hit the road',
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: i <= step
                            ? onboardingBlue
                            : const Color(0xFFEAF3FF),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: i <= step ? Colors.white : onboardingBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ['Documents', 'Vehicle', 'Review'][i],
                        style: TextStyle(
                          fontSize: 12,
                          color: i <= step ? onboardingBlue : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 30),
          if (step == 0) ...[
            heading('Upload Documents'),
            const Text(
              'JPG, PNG or PDF · Up to 10 MB each\nProfile photo must be a JPG or PNG.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < documentTypes.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Material(
                  color: const Color(0xFFF6FAFF),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    leading: Icon(
                      i == 0 ? Icons.person : Icons.badge_outlined,
                      color: onboardingBlue,
                      size: 32,
                    ),
                    title: Text(
                      documentTypes[i],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: documents[documentTypes[i]] == null
                        ? null
                        : Text(
                            documents[documentTypes[i]]!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: Icon(
                      documents.containsKey(documentTypes[i])
                          ? Icons.check_circle
                          : Icons.add_circle_outline,
                      color: onboardingBlue,
                    ),
                    onTap: busy ? null : () => pick(documentTypes[i]),
                  ),
                ),
              ),
          ],
          if (step == 1) ...[
            const Icon(
              Icons.directions_car_rounded,
              size: 110,
              color: onboardingBlue,
            ),
            const SizedBox(height: 20),
            Form(
              key: vehicleForm,
              child: Column(
                children: [
                  Image.asset(
                    'assets/vehicles/car.png',
                    height: 110,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: vehicleType,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Type',
                    ),
                    items: ['Car', 'Motorcycle', 'Van']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(() => vehicleType = v!),
                  ),
                  const SizedBox(height: 16),
                  field('Make', make),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: field('Model', model)),
                      const SizedBox(width: 12),
                      Expanded(child: field('Year', year, isYear: true)),
                    ],
                  ),
                  field('Vehicle Colour', colour),
                  field('Registration Number', plate),
                ],
              ),
            ),
          ],
          if (step == 2) ...[
            reviewCard('Personal Information', Icons.person, [
              fullName,
              phoneNumber,
              user?.email ?? '',
            ], -1),
            reviewCard('Vehicle Information', Icons.directions_car, [
              '$vehicleType · ${make.text} ${model.text} (${year.text})',
              plate.text.toUpperCase(),
              colour.text,
            ], 1),
            reviewCard(
              'Documents',
              Icons.fact_check_outlined,
              documentTypes
                  .map((type) => '$type: ${documents[type]!.name}')
                  .toList(),
              0,
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy
                ? null
                : step == 2
                ? submit
                : next,
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(step == 2 ? 'Submit' : 'Next'),
          ),
          if (step > 0)
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      step--;
                      error = null;
                    }),
              child: const Text('Back'),
            ),
        ],
      ),
    );
  }
}
