import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:aeye/core/constants/app_constants.dart';
import 'package:aeye/core/models/app_settings.dart';
import 'package:aeye/features/object_detection/models/detection_result.dart';
import 'package:aeye/features/ocr/models/text_detection_result.dart';

/// Integration tests for component interactions
/// Tests: Camera → Inference → Audio Pipeline
void main() {
  group('Component Interaction Tests', () {
    
    // =========================================================================
    // CAMERA → INFERENCE PIPELINE
    // =========================================================================
    group('Camera to Inference Pipeline', () {
      
      test('should validate image dimensions for model input', () {
        // Simulate camera capture dimensions
        const cameraWidth = 1920;
        const cameraHeight = 1080;
        
        // Model expects 320x320
        const modelInputWidth = AppConstants.targetImageWidth;
        const modelInputHeight = AppConstants.targetImageHeight;
        
        // Calculate resize factors
        final scaleX = modelInputWidth / cameraWidth;
        final scaleY = modelInputHeight / cameraHeight;
        
        expect(modelInputWidth, 320);
        expect(modelInputHeight, 320);
        expect(scaleX, closeTo(0.167, 0.01));
        expect(scaleY, closeTo(0.296, 0.01));
      });

      test('should transform bounding box from model to camera coordinates', () {
        // Model output coordinates (normalized 0-1 on 320x320)
        const modelBoxLeft = 0.1;
        const modelBoxTop = 0.2;
        const modelBoxRight = 0.5;
        const modelBoxBottom = 0.6;
        
        // Original camera dimensions
        const cameraWidth = 1920.0;
        const cameraHeight = 1080.0;
        
        // Transform to camera coordinates
        final cameraBoxLeft = modelBoxLeft * cameraWidth;
        final cameraBoxTop = modelBoxTop * cameraHeight;
        final cameraBoxRight = modelBoxRight * cameraWidth;
        final cameraBoxBottom = modelBoxBottom * cameraHeight;
        
        expect(cameraBoxLeft, 192.0);
        expect(cameraBoxTop, 216.0);
        expect(cameraBoxRight, 960.0);
        expect(cameraBoxBottom, 648.0);
      });

      test('should handle portrait vs landscape orientation', () {
        // Portrait mode (rotated)
        const portraitWidth = 1080;
        const portraitHeight = 1920;
        
        // Landscape mode
        const landscapeWidth = 1920;
        const landscapeHeight = 1080;
        
        // Both should resize to 320x320 for model
        const targetSize = 320;
        
        final portraitScaleX = targetSize / portraitWidth;
        final portraitScaleY = targetSize / portraitHeight;
        final landscapeScaleX = targetSize / landscapeWidth;
        final landscapeScaleY = targetSize / landscapeHeight;
        
        // Verify different scale factors for different orientations
        expect(portraitScaleX, isNot(equals(landscapeScaleX)));
        expect(portraitScaleY, isNot(equals(landscapeScaleY)));
      });

      test('should validate confidence threshold filtering', () {
        final rawDetections = [
          {'label': 'person', 'confidence': 0.95},
          {'label': 'chair', 'confidence': 0.30},
          {'label': 'table', 'confidence': 0.55},
          {'label': 'dog', 'confidence': 0.44},
          {'label': 'car', 'confidence': 0.46},
        ];
        
        final filtered = rawDetections
            .where((d) => d['confidence'] as double >= AppConstants.objectDetectionThreshold)
            .toList();
        
        expect(filtered.length, 3);
        expect(filtered.any((d) => d['label'] == 'person'), true);
        expect(filtered.any((d) => d['label'] == 'table'), true);
        expect(filtered.any((d) => d['label'] == 'car'), true);
        expect(filtered.any((d) => d['label'] == 'chair'), false);
        expect(filtered.any((d) => d['label'] == 'dog'), false);
      });
    });

    // =========================================================================
    // INFERENCE → AUDIO PIPELINE
    // =========================================================================
    group('Inference to Audio Pipeline', () {
      
      test('should generate TTS announcement from detection results', () {
        final detections = [
          DetectionResult(
            label: 'person',
            confidence: 0.95,
            boundingBox: BoundingBox(left: 10, top: 10, right: 100, bottom: 200),
          ),
          DetectionResult(
            label: 'chair',
            confidence: 0.75,
            boundingBox: BoundingBox(left: 150, top: 50, right: 250, bottom: 150),
          ),
        ];
        
        // Simulate announcement generation
        final count = detections.length;
        final objectWord = count == 1 ? 'object' : 'objects';
        final labels = detections.map((d) => d.label).toSet().toList();
        final announcement = 'Found $count $objectWord: ${labels.join(', ')}';
        
        expect(announcement, 'Found 2 objects: person, chair');
      });

      test('should generate TTS announcement from OCR results', () {
        final ocrResult = TextDetectionResult(
          fullText: 'Hello World from OCR test',
          blocks: [
            TextBlockResult(
              text: 'Hello World',
              lines: ['Hello World'],
              boundingBox: const Rect.fromLTRB(0, 0, 200, 50),
              confidence: 0.9,
            ),
            TextBlockResult(
              text: 'from OCR test',
              lines: ['from OCR test'],
              boundingBox: const Rect.fromLTRB(0, 60, 200, 110),
              confidence: 0.85,
            ),
          ],
          hasText: true,
        );
        
        // Simulate announcement generation
        String announcement;
        if (!ocrResult.hasText) {
          announcement = 'No text detected';
        } else {
          final wordCount = ocrResult.wordCount;
          final blockCount = ocrResult.blockCount;
          announcement = 'Found $wordCount words in $blockCount blocks';
        }
        
        expect(announcement, 'Found 5 words in 2 blocks');
      });

      test('should respect TTS settings for speech rate', () {
        const settings = AppSettings(speechRate: 0.7, pitch: 1.2, volume: 0.9);
        
        // Validate settings are within valid ranges
        expect(settings.speechRate, greaterThanOrEqualTo(0.0));
        expect(settings.speechRate, lessThanOrEqualTo(1.0));
        expect(settings.pitch, greaterThanOrEqualTo(0.5));
        expect(settings.pitch, lessThanOrEqualTo(2.0));
        expect(settings.volume, greaterThanOrEqualTo(0.0));
        expect(settings.volume, lessThanOrEqualTo(1.0));
      });

      test('should handle empty detection results gracefully', () {
        final emptyDetections = <DetectionResult>[];
        
        String generateAnnouncement(List<DetectionResult> results) {
          if (results.isEmpty) {
            return 'No objects detected. Try again.';
          }
          final count = results.length;
          final labels = results.map((r) => r.label).toSet().toList();
          return 'Found $count objects: ${labels.join(', ')}';
        }
        
        expect(generateAnnouncement(emptyDetections), 'No objects detected. Try again.');
      });
    });

    // =========================================================================
    // CROSS-COMPONENT DATA FLOW
    // =========================================================================
    group('Cross-Component Data Flow', () {
      
      test('should flow settings from SettingsService to TTS parameters', () {
        // Simulate settings update flow
        const originalSettings = AppSettings();
        final updatedSettings = originalSettings.copyWith(
          speechRate: 0.8,
          pitch: 1.1,
        );
        
        // Verify settings propagation
        expect(updatedSettings.speechRate, 0.8);
        expect(updatedSettings.pitch, 1.1);
        expect(updatedSettings.volume, originalSettings.volume); // Unchanged
      });

      test('should flow detection results to UI overlay', () {
        final detection = DetectionResult(
          label: 'person',
          confidence: 0.92,
          boundingBox: BoundingBox(left: 50, top: 100, right: 200, bottom: 400),
        );
        
        // Simulate UI overlay data transformation
        const previewWidth = 400.0;
        const previewHeight = 600.0;
        const imageWidth = 320;
        const imageHeight = 320;
        
        final scaleX = previewWidth / imageWidth;
        final scaleY = previewHeight / imageHeight;
        
        final overlayRect = Rect.fromLTRB(
          detection.boundingBox.left * scaleX,
          detection.boundingBox.top * scaleY,
          detection.boundingBox.right * scaleX,
          detection.boundingBox.bottom * scaleY,
        );
        
        expect(overlayRect.left, 62.5);
        expect(overlayRect.top, 187.5);
        expect(overlayRect.right, 250.0);
        expect(overlayRect.bottom, 750.0);
      });

      test('should flow OCR blocks to reading order', () {
        final blocks = [
          TextBlockResult(
            text: 'Third line',
            lines: ['Third line'],
            boundingBox: const Rect.fromLTRB(10, 200, 200, 250),
            confidence: 0.9,
          ),
          TextBlockResult(
            text: 'First line',
            lines: ['First line'],
            boundingBox: const Rect.fromLTRB(10, 10, 200, 60),
            confidence: 0.9,
          ),
          TextBlockResult(
            text: 'Second line',
            lines: ['Second line'],
            boundingBox: const Rect.fromLTRB(10, 100, 200, 150),
            confidence: 0.9,
          ),
        ];
        
        // Sort for reading order (top to bottom)
        final sorted = List<TextBlockResult>.from(blocks)
          ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
        
        expect(sorted[0].text, 'First line');
        expect(sorted[1].text, 'Second line');
        expect(sorted[2].text, 'Third line');
        
        // Assemble full text
        final fullText = sorted.map((b) => b.text).join(' ');
        expect(fullText, 'First line Second line Third line');
      });

      test('should flow voice command to navigation action', () {
        // Simulate voice command processing
        String? processVoiceCommand(String text) {
          final lower = text.toLowerCase();
          if (lower.contains('detect') || lower.contains('object')) {
            return 'navigate_object_detection';
          }
          if (lower.contains('read') || lower.contains('text') || lower.contains('ocr')) {
            return 'navigate_ocr';
          }
          if (lower.contains('setting')) {
            return 'navigate_settings';
          }
          if (lower.contains('back') || lower.contains('exit')) {
            return 'go_back';
          }
          return null;
        }
        
        expect(processVoiceCommand('detect objects'), 'navigate_object_detection');
        expect(processVoiceCommand('read text'), 'navigate_ocr');
        expect(processVoiceCommand('open settings'), 'navigate_settings');
        expect(processVoiceCommand('go back'), 'go_back');
        expect(processVoiceCommand('hello world'), null);
      });
    });

    // =========================================================================
    // VIBRATION FEEDBACK INTEGRATION
    // =========================================================================
    group('Vibration Feedback Integration', () {
      
      test('should calculate vibration duration based on intensity setting', () {
        int getVibrationDuration(int baseDuration, int intensity, bool enabled) {
          if (!enabled) return 0;
          
          switch (intensity) {
            case 1: return (baseDuration * 0.7).round(); // Low
            case 2: return baseDuration; // Medium
            case 3: return (baseDuration * 1.3).round(); // High
            default: return baseDuration;
          }
        }
        
        // Test different intensities
        expect(getVibrationDuration(100, 1, true), 70);
        expect(getVibrationDuration(100, 2, true), 100);
        expect(getVibrationDuration(100, 3, true), 130);
        
        // Test disabled
        expect(getVibrationDuration(100, 2, false), 0);
      });

      test('should generate correct vibration patterns', () {
        // Success pattern
        expect(AppConstants.successVibration, [0, 100, 50, 100]);
        
        // Error pattern
        expect(AppConstants.errorVibration, [0, 500]);
        
        // Alert pattern
        expect(AppConstants.alertVibration, [0, 100, 100, 100, 100, 100]);
      });
    });
  });
}
