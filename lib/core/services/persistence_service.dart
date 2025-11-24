import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Data persistence service for app state
/// Uses SharedPreferences for simple key-value storage
/// For complex data, consider using Hive or SQLite
class PersistenceService {
  static final PersistenceService _instance = PersistenceService._internal();
  factory PersistenceService() => _instance;
  PersistenceService._internal();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Generic methods

  Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(key, value) ?? false;
  }

  String? getString(String key) {
    return _prefs?.getString(key);
  }

  Future<bool> setInt(String key, int value) async {
    return await _prefs?.setInt(key, value) ?? false;
  }

  int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  Future<bool> setBool(String key, bool value) async {
    return await _prefs?.setBool(key, value) ?? false;
  }

  bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  Future<bool> setDouble(String key, double value) async {
    return await _prefs?.setDouble(key, value) ?? false;
  }

  double? getDouble(String key) {
    return _prefs?.getDouble(key);
  }

  Future<bool> setStringList(String key, List<String> value) async {
    return await _prefs?.setStringList(key, value) ?? false;
  }

  List<String>? getStringList(String key) {
    return _prefs?.getStringList(key);
  }

  // JSON methods

  Future<bool> setJson(String key, Map<String, dynamic> value) async {
    try {
      final jsonString = jsonEncode(value);
      return await setString(key, jsonString);
    } catch (e) {
      print('Error saving JSON: $e');
      return false;
    }
  }

  Map<String, dynamic>? getJson(String key) {
    try {
      final jsonString = getString(key);
      if (jsonString == null) return null;
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading JSON: $e');
      return null;
    }
  }

  // App-specific persistence

  /// Save last used feature
  Future<void> saveLastFeature(String featureName) async {
    await setString('last_feature', featureName);
    await setString('last_feature_time', DateTime.now().toIso8601String());
  }

  /// Get last used feature
  String? getLastFeature() {
    return getString('last_feature');
  }

  /// Save detection history
  Future<void> saveDetectionHistory(List<Map<String, dynamic>> history) async {
    try {
      final jsonString = jsonEncode(history);
      await setString('detection_history', jsonString);
    } catch (e) {
      print('Error saving detection history: $e');
    }
  }

  /// Get detection history
  List<Map<String, dynamic>> getDetectionHistory() {
    try {
      final jsonString = getString('detection_history');
      if (jsonString == null) return [];
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading detection history: $e');
      return [];
    }
  }

  /// Save OCR history
  Future<void> saveOCRHistory(List<Map<String, dynamic>> history) async {
    try {
      final jsonString = jsonEncode(history);
      await setString('ocr_history', jsonString);
    } catch (e) {
      print('Error saving OCR history: $e');
    }
  }

  /// Get OCR history
  List<Map<String, dynamic>> getOCRHistory() {
    try {
      final jsonString = getString('ocr_history');
      if (jsonString == null) return [];
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading OCR history: $e');
      return [];
    }
  }

  /// Save app state
  Future<void> saveAppState(Map<String, dynamic> state) async {
    await setJson('app_state', state);
  }

  /// Get app state
  Map<String, dynamic>? getAppState() {
    return getJson('app_state');
  }

  /// Clear specific key
  Future<bool> remove(String key) async {
    return await _prefs?.remove(key) ?? false;
  }

  /// Clear all data
  Future<bool> clearAll() async {
    return await _prefs?.clear() ?? false;
  }

  /// Check if key exists
  bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  /// Get all keys
  Set<String> getAllKeys() {
    return _prefs?.getKeys() ?? {};
  }
}
