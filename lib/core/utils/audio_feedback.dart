import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioFeedback {
  static bool _isInitialized = false;

  // Initialize audio system
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('✅ Audio feedback initialized');
  }

  // Play listening start beep - short click to indicate listening started
  static Future<void> listeningStart() async {
    try {
      if (Platform.isIOS) {
        await SystemSound.play(SystemSoundType.click);
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('⚠️ Could not play listening start feedback: $e');
    }
  }

  // Play success beep - pleasant confirmation sound (only for command recognition)
  static Future<void> success() async {
    try {
      if (Platform.isIOS) {
        await SystemSound.play(SystemSoundType.click);
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('⚠️ Could not play success audio feedback: $e');
    }
  }

  // Play error beep - distinctive error sound  
  static Future<void> error() async {
    try {
      if (Platform.isIOS) {
        await SystemSound.play(SystemSoundType.alert);
      } else {
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('⚠️ Could not play error audio feedback: $e');
    }
  }

  // Play confirmation beep - same as success
  static Future<void> confirmation() async {
    await success();
  }

  // Dispose resources (no-op for system sounds)
  static Future<void> dispose() async {
    debugPrint('✅ Audio feedback disposed');
  }
}
