import 'package:vibration/vibration.dart';
import '../services/settings_service.dart';

class VibrationHelper {
  static final SettingsService _settings = SettingsService();

  // Vibrate with settings-aware duration
  static Future<void> vibrate({int duration = 100}) async {
    if (!_settings.settings.vibrationEnabled) return;
    
    if (await Vibration.hasVibrator() ?? false) {
      final adjustedDuration = _settings.getVibrationDuration(duration);
      if (adjustedDuration > 0) {
        Vibration.vibrate(duration: adjustedDuration);
      }
    }
  }

  // Vibrate with pattern
  static Future<void> vibratePattern(List<int> pattern) async {
    if (!_settings.settings.vibrationEnabled) return;
    
    if (await Vibration.hasVibrator() ?? false) {
      // Adjust pattern based on intensity
      final adjustedPattern = pattern.map((duration) {
        return _settings.getVibrationDuration(duration);
      }).toList();
      
      Vibration.vibrate(pattern: adjustedPattern);
    }
  }

  // Quick vibration for selection
  static Future<void> selection() async {
    await vibrate(duration: 50);
  }

  // Medium vibration for activation
  static Future<void> activation() async {
    await vibrate(duration: 100);
  }
  
  // Medium vibrate (alias for activation)
  static Future<void> mediumVibrate() async {
    await vibrate(duration: 100);
  }

  // Strong vibration for important actions
  static Future<void> important() async {
    await vibrate(duration: 150);
  }

  // Success pattern
  static Future<void> success() async {
    await vibratePattern([0, 100, 50, 100]);
  }

  // Error pattern
  static Future<void> error() async {
    await vibratePattern([0, 500]);
  }

  // Alert pattern
  static Future<void> alert() async {
    await vibratePattern([0, 100, 100, 100, 100, 100]);
  }

  // Emergency pattern
  static Future<void> emergency() async {
    await vibratePattern([0, 200, 100, 200, 100, 200]);
  }
}
