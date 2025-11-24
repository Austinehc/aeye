import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'settings_service.dart';

class BatteryService {
  static final BatteryService _instance = BatteryService._internal();
  factory BatteryService() => _instance;
  BatteryService._internal();

  final Battery _battery = Battery();
  final SettingsService _settings = SettingsService();
  
  int? _batteryLevel;
  BatteryState? _batteryState;
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  Timer? _batteryCheckTimer;  // ✅ FIX: Store timer reference

  int? get batteryLevel => _batteryLevel;
  BatteryState? get batteryState => _batteryState;
  bool get isLowBattery => (_batteryLevel ?? 100) < 20;
  bool get isCriticalBattery => (_batteryLevel ?? 100) < 10;

  // Initialize battery monitoring
  Future<void> initialize() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;

      // Listen to battery state changes
      _batteryStateSubscription = _battery.onBatteryStateChanged.listen((state) {
        _batteryState = state;
        _checkBatteryOptimization();
      });

      // ✅ FIX: Store timer reference for proper cleanup
      _batteryCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
        _batteryLevel = await _battery.batteryLevel;
        _checkBatteryOptimization();
      });
    } catch (e) {
      print('Error initializing battery service: $e');
    }
  }

  // Check if battery optimization should be enabled
  void _checkBatteryOptimization() {
    // Auto-enable battery saver if battery is low and not already enabled
    if (isLowBattery && !_settings.settings.batterySaverMode) {
      print('Low battery detected. Consider enabling battery saver mode.');
    }
  }

  // Should reduce camera quality
  bool shouldReduceCameraQuality() {
    return _settings.settings.batterySaverMode || isCriticalBattery;
  }

  // Should reduce GPS accuracy
  bool shouldReduceGPSAccuracy() {
    return _settings.settings.batterySaverMode || 
           _settings.settings.reducedGPSAccuracy || 
           isLowBattery;
  }

  // Should auto-stop camera
  bool shouldAutoStopCamera() {
    return _settings.settings.autoStopCamera && isLowBattery;
  }

  // Get recommended camera timeout (in seconds)
  int getCameraTimeout() {
    if (isCriticalBattery) return 30;
    if (isLowBattery) return 60;
    if (_settings.settings.batterySaverMode) return 90;
    return 180; // 3 minutes default
  }

  // Get GPS update interval (in seconds)
  int getGPSUpdateInterval() {
    if (isCriticalBattery) return 10;
    if (isLowBattery) return 5;
    if (_settings.settings.batterySaverMode) return 5;
    return 3; // Default from constants
  }

  // Dispose
  void dispose() {
    _batteryStateSubscription?.cancel();
    _batteryCheckTimer?.cancel();  // ✅ FIX: Cancel timer to prevent leak
  }
}
