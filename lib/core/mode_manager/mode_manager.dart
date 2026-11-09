import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

enum AppMode { passenger, driver }

class ModeManager extends ChangeNotifier {
  static const _prefKey = 'selected_app_mode';
  static const _platformChannel = MethodChannel('com.smart_ride/launcher_mode');

  AppMode _currentMode = AppMode.passenger;
  AppMode get currentMode => _currentMode;
  Future<bool> Function()? beforeLeavingDriver;

  ModeManager() {
    _init();
  }

  Future<void> _init() async {
    // 1️⃣ Load persisted mode
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      _currentMode = saved == 'driver' ? AppMode.driver : AppMode.passenger;
    }
    // 2️⃣ Verify driver approval when we think we are in driver mode
    if (_currentMode == AppMode.driver) {
      final approved = await _isDriverApproved();
      if (!approved) {
        // fall back to passenger if not approved
        _currentMode = AppMode.passenger;
        await prefs.setString(_prefKey, 'passenger');
      }
    }
    // 3️⃣ Apply launcher alias
    await _applyLauncherAlias();
    notifyListeners();
  }

  Future<bool> _isDriverApproved() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    final meta = user.appMetadata as Map<String, dynamic>?;
    return meta?['driver_approved'] == true;
  }

  Future<void> switchTo(AppMode mode) async {
    if (mode == _currentMode) return;
    if (_currentMode == AppMode.driver &&
        mode == AppMode.passenger &&
        beforeLeavingDriver != null) {
      if (!await beforeLeavingDriver!()) return;
    }
    // If switching to driver, ensure approval first
    if (mode == AppMode.driver) {
      final approved = await _isDriverApproved();
      if (!approved) {
        throw Exception('Driver not approved');
      }
    }
    _currentMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefKey,
      mode == AppMode.driver ? 'driver' : 'passenger',
    );
    await _applyLauncherAlias();
    notifyListeners();
  }

  Future<void> _applyLauncherAlias() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _platformChannel.invokeMethod('setMode', {
        'driverMode': _currentMode == AppMode.driver,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Launcher alias call failed: $e');
      }
    }
  }
}
