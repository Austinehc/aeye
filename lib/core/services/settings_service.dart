import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../utils/tts_service.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _settingsKey = 'app_settings';
  AppSettings _settings = const AppSettings();
  final TTSService _tts = TTSService();

  AppSettings get settings => _settings;

  // Initialize and load settings
  Future<void> initialize() async {
    await loadSettings();
  }

  // Load settings from storage
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      
      if (settingsJson != null) {
        final Map<String, dynamic> json = jsonDecode(settingsJson);
        _settings = AppSettings.fromJson(json);
      }
      
      // Always apply TTS settings (either loaded or defaults)
      await _applyTTSSettings();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      // Still apply default settings on error
      await _applyTTSSettings();
    }
  }

  // Save settings to storage
  Future<void> saveSettings(AppSettings newSettings) async {
    try {
      _settings = newSettings;
      
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(_settings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
      
      // Apply TTS settings immediately
      await _applyTTSSettings();
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  // Apply TTS settings
  Future<void> _applyTTSSettings() async {
    await _tts.setSpeechRate(_settings.speechRate);
    await _tts.setPitch(_settings.pitch);
    await _tts.setVolume(_settings.volume);
  }

  // Update specific settings
  Future<void> updateSpeechRate(double rate) async {
    await saveSettings(_settings.copyWith(speechRate: rate));
  }

  Future<void> updatePitch(double pitch) async {
    await saveSettings(_settings.copyWith(pitch: pitch));
  }

  Future<void> updateVolume(double volume) async {
    await saveSettings(_settings.copyWith(volume: volume));
  }

  Future<void> updateVibrationEnabled(bool enabled) async {
    await saveSettings(_settings.copyWith(vibrationEnabled: enabled));
  }

  Future<void> updateVibrationIntensity(int intensity) async {
    await saveSettings(_settings.copyWith(vibrationIntensity: intensity));
  }

  Future<void> updateBatterySaverMode(bool enabled) async {
    await saveSettings(_settings.copyWith(batterySaverMode: enabled));
  }

  Future<void> updateAutoStopCamera(bool enabled) async {
    await saveSettings(_settings.copyWith(autoStopCamera: enabled));
  }

  Future<void> updateReducedGPSAccuracy(bool enabled) async {
    await saveSettings(_settings.copyWith(reducedGPSAccuracy: enabled));
  }

  Future<void> updateHeadsetButtonEnabled(bool enabled) async {
    await saveSettings(_settings.copyWith(headsetButtonEnabled: enabled));
  }

  // Get vibration duration based on intensity
  int getVibrationDuration(int baseDuration) {
    if (!_settings.vibrationEnabled) return 0;
    
    switch (_settings.vibrationIntensity) {
      case 1: // Low
        return (baseDuration * 0.7).round();
      case 2: // Medium
        return baseDuration;
      case 3: // High
        return (baseDuration * 1.3).round();
      default:
        return baseDuration;
    }
  }
}
