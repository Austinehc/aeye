import 'package:flutter_test/flutter_test.dart';
import 'package:aeye/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    group('App Info', () {
      test('should have correct app name', () {
        expect(AppConstants.appName, 'Aeye');
      });

      test('should have correct app version', () {
        expect(AppConstants.appVersion, '1.0.0');
      });
    });

    group('Model Paths', () {
      test('should have correct object detection model path', () {
        expect(AppConstants.objectDetectionModel, 'assets/models/yolov8n.tflite');
      });

      test('should have correct labels path', () {
        expect(AppConstants.objectDetectionLabels, 'assets/models/labelmap.txt');
      });
    });

    group('Detection Thresholds', () {
      test('should have valid object detection threshold', () {
        expect(AppConstants.objectDetectionThreshold, 0.45);
        expect(AppConstants.objectDetectionThreshold, greaterThan(0));
        expect(AppConstants.objectDetectionThreshold, lessThanOrEqualTo(1));
      });

      test('should have valid NMS IoU threshold', () {
        expect(AppConstants.nmsIouThreshold, 0.45);
        expect(AppConstants.nmsIouThreshold, greaterThan(0));
        expect(AppConstants.nmsIouThreshold, lessThanOrEqualTo(1));
      });

      test('should have valid OCR confidence threshold', () {
        expect(AppConstants.ocrConfidenceThreshold, 0.7);
        expect(AppConstants.ocrConfidenceThreshold, greaterThan(0));
        expect(AppConstants.ocrConfidenceThreshold, lessThanOrEqualTo(1));
      });
    });

    group('TTS Settings', () {
      test('should have valid default speech rate', () {
        expect(AppConstants.defaultSpeechRate, 0.5);
        expect(AppConstants.defaultSpeechRate, greaterThan(0));
        expect(AppConstants.defaultSpeechRate, lessThanOrEqualTo(1));
      });

      test('should have valid default pitch', () {
        expect(AppConstants.defaultPitch, 1.0);
        expect(AppConstants.defaultPitch, greaterThanOrEqualTo(0.5));
        expect(AppConstants.defaultPitch, lessThanOrEqualTo(2.0));
      });

      test('should have valid default volume', () {
        expect(AppConstants.defaultVolume, 1.0);
        expect(AppConstants.defaultVolume, greaterThanOrEqualTo(0));
        expect(AppConstants.defaultVolume, lessThanOrEqualTo(1));
      });
    });

    group('Camera Settings', () {
      test('should have correct target image width', () {
        expect(AppConstants.targetImageWidth, 320);
      });

      test('should have correct target image height', () {
        expect(AppConstants.targetImageHeight, 320);
      });

      test('should have square input dimensions for YOLO', () {
        expect(AppConstants.targetImageWidth, AppConstants.targetImageHeight);
      });
    });

    group('Voice Commands', () {
      test('should have wake words defined', () {
        expect(AppConstants.wakeWords, isNotEmpty);
        expect(AppConstants.wakeWords, contains('hey vision'));
        expect(AppConstants.wakeWords, contains('hello vision'));
      });

      test('should have voice command timeout', () {
        expect(AppConstants.voiceCommandTimeout, isA<Duration>());
        expect(AppConstants.voiceCommandTimeout.inSeconds, greaterThan(0));
      });

      test('should have voice commands map', () {
        expect(AppConstants.voiceCommandsMap, isNotEmpty);
      });

      test('should map detect objects command', () {
        expect(AppConstants.voiceCommandsMap['detect objects'], 'object_detection');
        expect(AppConstants.voiceCommandsMap['object detection'], 'object_detection');
      });

      test('should map OCR commands', () {
        expect(AppConstants.voiceCommandsMap['read text'], 'ocr');
        expect(AppConstants.voiceCommandsMap['scan text'], 'ocr');
        expect(AppConstants.voiceCommandsMap['ocr'], 'ocr');
      });

      test('should map help command', () {
        expect(AppConstants.voiceCommandsMap['help'], 'help');
      });

      test('should map exit commands', () {
        expect(AppConstants.voiceCommandsMap['exit'], 'exit');
        expect(AppConstants.voiceCommandsMap['back'], 'exit');
      });
    });

    group('Vibration Patterns', () {
      test('should have success vibration pattern', () {
        expect(AppConstants.successVibration, isNotEmpty);
        expect(AppConstants.successVibration, [0, 100, 50, 100]);
      });

      test('should have error vibration pattern', () {
        expect(AppConstants.errorVibration, isNotEmpty);
        expect(AppConstants.errorVibration, [0, 500]);
      });

      test('should have alert vibration pattern', () {
        expect(AppConstants.alertVibration, isNotEmpty);
        expect(AppConstants.alertVibration, [0, 100, 100, 100, 100, 100]);
      });

      test('vibration patterns should start with 0 (delay)', () {
        expect(AppConstants.successVibration.first, 0);
        expect(AppConstants.errorVibration.first, 0);
        expect(AppConstants.alertVibration.first, 0);
      });
    });
  });
}
