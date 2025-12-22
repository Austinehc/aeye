import 'package:permission_handler/permission_handler.dart';
import 'tts_service.dart';

class PermissionsHandler {
  static final TTSService _tts = TTSService();

  // Check and request all required permissions
  static Future<bool> requestAllPermissions() async {
    final cameraGranted = await requestCameraPermission();
    final microphoneGranted = await requestMicrophonePermission();
    final speechGranted = await requestSpeechPermission();

    return cameraGranted && microphoneGranted && speechGranted;
  }

  // Camera Permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    
    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (result.isGranted) {
        await _tts.speak('Camera permission granted');
        return true;
      } else {
        await _tts.speak('Camera permission is required for object detection and text reading');
        return false;
      }
    }

    if (status.isPermanentlyDenied) {
      await _tts.speak('Please enable camera permission in settings');
      await openAppSettings();
      return false;
    }

    return false;
  }

  // Microphone Permission
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.status;
    
    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        await _tts.speak('Microphone permission granted');
        return true;
      } else {
        await _tts.speak('Microphone permission is required for voice commands');
        return false;
      }
    }

    if (status.isPermanentlyDenied) {
      await _tts.speak('Please enable microphone permission in settings');
      await openAppSettings();
      return false;
    }

    return false;
  }

 

  // Speech Recognition Permission
  static Future<bool> requestSpeechPermission() async {
    final status = await Permission.speech.status;
    
    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.speech.request();
      if (result.isGranted) {
        await _tts.speak('Speech recognition permission granted');
        return true;
      } else {
        await _tts.speak('Speech recognition permission is required for voice commands');
        return false;
      }
    }

    if (status.isPermanentlyDenied) {
      await _tts.speak('Please enable speech recognition permission in settings');
      await openAppSettings();
      return false;
    }

    return false;
  }

  // Check if all permissions are granted
  static Future<bool> checkAllPermissions() async {
    final camera = await Permission.camera.isGranted;
    final microphone = await Permission.microphone.isGranted;
    final speech = await Permission.speech.isGranted;

    return camera && microphone && speech;
  }
}