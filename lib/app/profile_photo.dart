import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import 'board_widgets.dart';
import 'theme.dart';

class ProfilePhoto extends StatefulWidget {
  const ProfilePhoto({super.key, this.radius = 34, this.editable = false});
  final double radius;
  final bool editable;
  @override
  State<ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends State<ProfilePhoto> {
  String? _url;
  String _initial = '';
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    AuthService.avatarChanges.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AuthService.avatarChanges.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await AuthService().getCurrentProfile();
      final name =
          (profile?['full_name'] ??
                  AuthService().currentUser?.userMetadata?['full_name'] ??
                  '')
              .toString()
              .trim();
      if (mounted) {
        setState(() {
          _url = profile?['avatar_url'] as String?;
          _initial = name.isEmpty ? '' : name[0].toUpperCase();
        });
      }
    } catch (_) {
      /* Initials remain available offline. */
    }
  }

  Future<void> _choose() async {
    if (_busy) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Profile picture',
                style: TextStyle(
                  fontFamily: 'Asap',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              BoardAction(
                icon: Icons.photo_library_outlined,
                title: 'Choose from device',
                subtitle: 'JPG, PNG or WebP · maximum 5 MB',
                onTap: () => Navigator.pop(context, 'choose'),
              ),
              if (_url != null)
                BoardAction(
                  icon: Icons.delete_outline,
                  title: 'Remove picture',
                  danger: true,
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (action == 'remove') {
        await AuthService().removeAvatar();
      } else {
        final selected = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
          requestFullMetadata: false,
        );
        if (selected == null) return;
        final bytes = await selected.readAsBytes();
        await AuthService().uploadAvatar(bytes);
      }
      await _load();
    } on FormatException catch (e) {
      if (mounted) boardInfo(context, 'Choose another picture', e.message);
    } catch (_) {
      if (mounted) {
        boardInfo(
          context,
          'Picture could not be saved',
          'Check your connection and photo access, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.radius * 2;
    final fallback = Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      color: AppColors.blueTint,
      child: _initial.isEmpty
          ? Icon(
              Icons.person_outline,
              color: AppColors.blueDeep,
              size: widget.radius,
            )
          : Text(
              _initial,
              style: TextStyle(
                color: AppColors.blueDeep,
                fontSize: widget.radius * .7,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
    return Semantics(
      label: widget.editable ? 'Change profile picture' : 'Profile picture',
      button: widget.editable,
      child: InkWell(
        onTap: widget.editable && !_busy ? _choose : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: diameter + (widget.editable ? 8 : 0),
          height: diameter + (widget.editable ? 8 : 0),
          child: Stack(
            children: [
              ClipOval(
                child: _url == null
                    ? fallback
                    : Image.network(
                        _url!,
                        width: diameter,
                        height: diameter,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) => fallback,
                      ),
              ),
              if (_busy)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xAAFFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              if (widget.editable && !_busy)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.blueDeep,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
