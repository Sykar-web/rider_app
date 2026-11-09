import 'package:flutter/material.dart';

import 'theme.dart';

class BoardCard extends StatelessWidget {
  const BoardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.hairline),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class BoardAction extends StatelessWidget {
  const BoardAction({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    leading: Icon(
      icon,
      size: 22,
      color: danger ? AppColors.error : AppColors.blueDeep,
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 14,
        color: danger ? AppColors.error : AppColors.navy,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
    trailing:
        trailing ??
        const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textMuted,
          size: 20,
        ),
    onTap: onTap,
  );
}

class RouteRow extends StatelessWidget {
  const RouteRow({
    super.key,
    required this.title,
    required this.value,
    this.destination = false,
    this.onTap,
  });
  final String title;
  final String value;
  final bool destination;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            size: 25,
            color: destination ? AppColors.error : AppColors.blueDeep,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: 18,
            ),
        ],
      ),
    ),
  );
}

class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.info_outline,
  });
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.blueDeep, size: 40),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

void boardInfo(BuildContext context, String title, String message) {
  showDialog<void>(
    context: context,
    builder: (context) => BoardDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class BoardDialog extends StatelessWidget {
  const BoardDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.icon = Icons.info_outline_rounded,
  });
  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    icon: Center(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: AppColors.blueTint,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.blueDeep, size: 28),
      ),
    ),
    title: title,
    content: content,
    contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
    actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
    actions: [
      for (var i = 0; i < actions.length; i++)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: SizedBox(
            width: double.infinity,
            child: TextButtonTheme(
              data: TextButtonThemeData(
                style: TextButton.styleFrom(
                  backgroundColor: i == actions.length - 1
                      ? AppColors.blueDeep
                      : AppColors.field,
                  foregroundColor: i == actions.length - 1
                      ? Colors.white
                      : AppColors.navy,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
              child: actions[i],
            ),
          ),
        ),
    ],
  );
}

Future<bool> boardConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Go back',
  IconData icon = Icons.help_outline_rounded,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => BoardDialog(
        icon: icon,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

String ugx(Object? amount) {
  if (amount == null) return 'To be confirmed';
  final value = (amount as num).round().toString();
  final formatted = value.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return 'UGX $formatted';
}
