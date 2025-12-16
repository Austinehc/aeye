import 'package:flutter_test/flutter_test.dart';
import 'package:aeye/core/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    group('Default Values', () {
      test('should have correct default speech rate', () {
        const settings = AppSettings();
        expect(settings.speechRate, 0.5);
      });

      test('should have correct default pitch', () {
        const settings = AppSettings();
        expect(settings.pitch, 1.0);
      });

      test('should have correct default volume', () {
        const settings = AppSettings();
        expect(settings.volume, 1.0);
      });

      test('should have vibration enabled by default', () {
        const settings = AppSettings();
        expect(settings.vibrationEnabled, true);
      });

      test('should have medium vibration intensity by default', () {
        const settings = AppSettings();
        expect(settings.vibrationIntensity, 2);
      });

      test('should have battery saver mode disabled by default', () {
        const settings = AppSettings();
        expect(settings.batterySaverMode, false);
      });

      test('should have auto stop camera enabled by default', () {
        const settings = AppSettings();
        expect(settings.autoStopCamera, true);
      });

      test('should have headset button enabled by default', () {
        const settings = AppSettings();
        expect(settings.headsetButtonEnabled, true);
      });
    });

    group('copyWith', () {
      test('should create copy with updated speech rate', () {
        const original = AppSettings();
        final updated = original.copyWith(speechRate: 0.8);
        
        expect(updated.speechRate, 0.8);
        expect(updated.pitch, original.pitch);
        expect(updated.volume, original.volume);
      });

      test('should create copy with updated vibration settings', () {
        const original = AppSettings();
        final updated = original.copyWith(
          vibrationEnabled: false,
          vibrationIntensity: 1,
        );
        
        expect(updated.vibrationEnabled, false);
        expect(updated.vibrationIntensity, 1);
        expect(updated.speechRate, original.speechRate);
      });

      test('should create copy with multiple updated values', () {
        const original = AppSettings();
        final updated = original.copyWith(
          speechRate: 0.7,
          pitch: 1.2,
          volume: 0.9,
          batterySaverMode: true,
        );
        
        expect(updated.speechRate, 0.7);
        expect(updated.pitch, 1.2);
        expect(updated.volume, 0.9);
        expect(updated.batterySaverMode, true);
      });

      test('should preserve original values when no parameters passed', () {
        const original = AppSettings(
          speechRate: 0.6,
          pitch: 1.1,
          vibrationEnabled: false,
        );
        final copy = original.copyWith();
        
        expect(copy.speechRate, 0.6);
        expect(copy.pitch, 1.1);
        expect(copy.vibrationEnabled, false);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        const settings = AppSettings(
          speechRate: 0.7,
          pitch: 1.2,
          volume: 0.8,
          vibrationEnabled: false,
          vibrationIntensity: 3,
        );
        
        final json = settings.toJson();
        
        expect(json['speechRate'], 0.7);
        expect(json['pitch'], 1.2);
        expect(json['volume'], 0.8);
        expect(json['vibrationEnabled'], false);
        expect(json['vibrationIntensity'], 3);
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'speechRate': 0.6,
          'pitch': 1.3,
          'volume': 0.9,
          'vibrationEnabled': true,
          'vibrationIntensity': 1,
          'batterySaverMode': true,
          'autoStopCamera': false,
          'reducedGPSAccuracy': true,
          'offlineMapsEnabled': false,
          'maxCachedTiles': 300,
          'headsetButtonEnabled': false,
        };
        
        final settings = AppSettings.fromJson(json);
        
        expect(settings.speechRate, 0.6);
        expect(settings.pitch, 1.3);
        expect(settings.volume, 0.9);
        expect(settings.vibrationEnabled, true);
        expect(settings.vibrationIntensity, 1);
        expect(settings.batterySaverMode, true);
        expect(settings.autoStopCamera, false);
        expect(settings.headsetButtonEnabled, false);
      });

      test('should use defaults for missing JSON fields', () {
        final json = <String, dynamic>{};
        
        final settings = AppSettings.fromJson(json);
        
        expect(settings.speechRate, 0.5);
        expect(settings.pitch, 1.0);
        expect(settings.volume, 1.0);
        expect(settings.vibrationEnabled, true);
        expect(settings.vibrationIntensity, 2);
      });

      test('should round-trip serialize and deserialize', () {
        const original = AppSettings(
          speechRate: 0.75,
          pitch: 1.15,
          volume: 0.85,
          vibrationEnabled: false,
          vibrationIntensity: 3,
          batterySaverMode: true,
        );
        
        final json = original.toJson();
        final restored = AppSettings.fromJson(json);
        
        expect(restored.speechRate, original.speechRate);
        expect(restored.pitch, original.pitch);
        expect(restored.volume, original.volume);
        expect(restored.vibrationEnabled, original.vibrationEnabled);
        expect(restored.vibrationIntensity, original.vibrationIntensity);
        expect(restored.batterySaverMode, original.batterySaverMode);
      });
    });
  });
}
