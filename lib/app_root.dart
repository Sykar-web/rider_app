import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/theme.dart';
import 'core/mode_manager/mode_manager.dart';
import 'main.dart' show AuthGate;
import 'screens/connection_gate.dart';
import 'screens/splash_screen.dart';
import 'fast_driver/main.dart'
    show FastRideDriverApp; // Import driver app widget

/// Top‑level widget that provides the [ModeManager] and selects the appropriate
/// UI (passenger or driver) based on the persisted mode.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ModeManager>(
      create: (_) => ModeManager(),
      child: Consumer<ModeManager>(
        builder: (context, modeManager, _) {
          // Choose the widget tree based on the current mode.
          if (modeManager.currentMode == AppMode.driver) {
            // Driver mode – reuse the existing FastDriver app entry point.
            return FastRideDriverApp();
          }
          // Passenger mode – the original FastRide UI.
          return MaterialApp(
            title: 'FastRide',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            builder: (context, child) {
              if (MediaQuery.sizeOf(context).width <= 600) return child!;
              return ColoredBox(
                color: AppColors.field,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: child!,
                  ),
                ),
              );
            },
            home: SplashScreen(child: ConnectionGate(child: AuthGate())),
          );
        },
      ),
    );
  }
}
