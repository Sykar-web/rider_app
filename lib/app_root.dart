import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/mode_manager/mode_manager.dart';
import 'screens/auth/login_screen.dart';
import 'screens/connection_gate.dart';
import 'screens/home_router.dart';
import 'screens/splash_screen.dart';
import 'fast_driver/main.dart' show FastRideDriverApp; // Import driver app widget

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
            theme: ThemeData.light(), // Keep original theme import if needed.
            builder: (context, child) {
              if (MediaQuery.sizeOf(context).width <= 600) return child!;
              return ColoredBox(
                color: Colors.grey.shade200,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: child!,
                  ),
                ),
              );
            },
            home: const SplashScreen(child: ConnectionGate(child: AuthGate())),
          );
        },
      ),
    );
  }
}
