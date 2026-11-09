import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/mode_manager/mode_manager.dart';
import 'main.dart' show FastRideApp;
import 'fast_driver/main.dart' show FastRideDriverApp;

/// One signed-in account with two approved experiences.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => ModeManager(),
    child: Consumer<ModeManager>(
      builder: (context, mode, _) => AnimatedSwitcher(
        duration: MediaQuery.maybeOf(context)?.disableAnimations == true
            ? Duration.zero
            : const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        child: mode.currentMode == AppMode.driver
            ? const FastRideDriverApp(key: ValueKey('driver'))
            : const FastRideApp(key: ValueKey('passenger')),
      ),
    ),
  );
}
