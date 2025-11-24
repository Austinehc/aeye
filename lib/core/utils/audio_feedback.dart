import 'dart:io';
import 'package:flutter/services.dart';

class AudioFeedback {
  static bool _isInitialized = false;

  // Initialize audio system
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    print('✅ Audio feedback initialized');
  }

  // Play success beep - pleasant confirmation sound
  static Future<void> success() async {
    try {
      if (Platform.isIOS) {
        // iOS: Use system click sound
        await SystemSound.play(SystemSoundType.click);
      } else {
        // Android/Other: Use selection feedback
        HapticFeedback.selectionClick();
        // Add short delay for audio effect perception
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      print('⚠️ Could not play success audio feedback: $e');
    }
  }

  // Play error beep - distinctive error sound  
  static Future<void> error() async {
    try {
      if (Platform.isIOS) {
        // iOS: Use alert sound for errors
        await SystemSound.play(SystemSoundType.alert);
      } else {
        // Android/Other: Use heavy haptic for errors
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      print('⚠️ Could not play error audio feedback: $e');
    }
  }

  // Play confirmation beep - same as success
  static Future<void> confirmation() async {
    await success();
  }

  // Dispose resources (no-op for system sounds)
  static Future<void> dispose() async {
    // System sounds don't need cleanup
    print('✅ Audio feedback disposed');
  }
}
