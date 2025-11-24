import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

/// Global app state provider
class AppStateProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  AppSettings _settings = const AppSettings();
  bool _isLoading = false;
  String? _error;

  // Getters
  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize app state
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _settingsService.initialize();
      _settings = _settingsService.settings;
      _setError(null);
    } catch (e) {
      _setError('Failed to load settings: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update settings
  Future<void> updateSettings(AppSettings newSettings) async {
    _setLoading(true);
    try {
      await _settingsService.saveSettings(newSettings);
      _settings = newSettings;
      _setError(null);
      notifyListeners();
    } catch (e) {
      _setError('Failed to save settings: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update speech rate
  Future<void> updateSpeechRate(double rate) async {
    await updateSettings(_settings.copyWith(speechRate: rate));
  }

  /// Update pitch
  Future<void> updatePitch(double pitch) async {
    await updateSettings(_settings.copyWith(pitch: pitch));
  }

  /// Update volume
  Future<void> updateVolume(double volume) async {
    await updateSettings(_settings.copyWith(volume: volume));
  }

  /// Update vibration enabled
  Future<void> updateVibrationEnabled(bool enabled) async {
    await updateSettings(_settings.copyWith(vibrationEnabled: enabled));
  }

  /// Update battery saver mode
  Future<void> updateBatterySaverMode(bool enabled) async {
    await updateSettings(_settings.copyWith(batterySaverMode: enabled));
  }

  // Private helpers
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) {
      notifyListeners();
    }
  }
}
