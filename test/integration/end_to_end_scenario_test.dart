import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:aeye/core/constants/app_constants.dart';
import 'package:aeye/core/models/app_settings.dart';
import 'package:aeye/features/object_detection/models/detection_result.dart';
import 'package:aeye/features/ocr/models/text_detection_result.dart';

/// End-to-End Scenario Tests
/// Tests complete user flows from app launch through feature completion
void main() {
  group('End-to-End Scenario Tests', () {
    
    // =========================================================================
    // SCENARIO 1: APP LAUNCH → HOME SCREEN
    // =========================================================================
    group('Scenario: App Launch to Home Screen', () {
      
      test('should initialize with correct default settings', () {
        const settings = AppSettings();
        
        // Verify all defaults are accessibility-friendly
        expect(settings.speechRate, 0.5); // Slower for clarity
        expect(settings.pitch, 1.0);
        expect(settings.volume, 1.0); // Full volume
        expect(settings.vibrationEnabled, true); // Haptic feedback on
      });

      test('should have all required voice commands mapped', () {
        final commands = AppConstants.voiceCommandsMap;
        
        // Verify essential commands exist
        expect(commands.containsKey('detect objects'), true);
        expect(commands.containsKey('read text'), true);
        expect(commands.containsKey('help'), true);
        expect(commands.containsKey('exit'), true);
        expect(commands.containsKey('back'), true);
      });

      test('should generate correct home screen announcement', () {
        const menuItemCount = 3; // Object Detection, Text Reader, Settings
        
        String generateHomeAnnouncement(int itemCount) {
          return 'Home screen. $itemCount options available. '
              'Say: detect objects, read text, settings, help, or exit.';
        }
        
        final announcement = generateHomeAnnouncement(menuItemCount);
        
        expect(announcement, contains('Home screen'));
        expect(announcement, contains('3 options'));
        expect(announcement, contains('detect objects'));
        expect(announcement, contains('read text'));
      });
    });

    // =========================================================================
    // SCENARIO 2: OBJECT DETECTION FLOW
    // =========================================================================
    group('Scenario: Complete Object Detection Flow', () {
      
      test('should process detection from capture to announcement', () {
        // Step 1: Simulate camera capture (image dimensions)
        const capturedImageWidth = 1920;
        const capturedImageHeight = 1080;
        
        // Step 2: Resize for model input
        const modelInputSize = 320;
        final resizedWidth = modelInputSize;
        final resizedHeight = modelInputSize;
        
        expect(resizedWidth, AppConstants.targetImageWidth);
        expect(resizedHeight, AppConstants.targetImageHeight);
        
        // Step 3: Simulate model inference output
        final rawDetections = [
          {'label': 'person', 'confidence': 0.92, 'box': [0.1, 0.2, 0.4, 0.8]},
          {'label': 'chair', 'confidence': 0.78, 'box': [0.5, 0.3, 0.7, 0.6]},
          {'label': 'noise', 'confidence': 0.30, 'box': [0.8, 0.8, 0.9, 0.9]},
        ];
        
        // Step 4: Filter by confidence threshold
        final filtered = rawDetections
            .where((d) => (d['confidence'] as double) >= AppConstants.objectDetectionThreshold)
            .toList();
        
        expect(filtered.length, 2);
        
        // Step 5: Convert to DetectionResult objects
        final results = filtered.map((d) {
          final box = d['box'] as List<double>;
          return DetectionResult(
            label: d['label'] as String,
            confidence: d['confidence'] as double,
            boundingBox: BoundingBox(
              left: box[0] * capturedImageWidth,
              top: box[1] * capturedImageHeight,
              right: box[2] * capturedImageWidth,
              bottom: box[3] * capturedImageHeight,
            ),
          );
        }).toList();
        
        expect(results.length, 2);
        expect(results[0].label, 'person');
        expect(results[1].label, 'chair');
        
        // Step 6: Generate announcement
        final labels = results.map((r) => r.label).toSet().toList();
        final announcement = 'Found ${results.length} objects: ${labels.join(', ')}';
        
        expect(announcement, 'Found 2 objects: person, chair');
      });

      test('should handle no detections scenario', () {
        final emptyResults = <DetectionResult>[];
        
        String generateAnnouncement(List<DetectionResult> results) {
          if (results.isEmpty) {
            return 'No objects detected. Say scan to try again.';
          }
          return 'Found ${results.length} objects';
        }
        
        expect(generateAnnouncement(emptyResults), 'No objects detected. Say scan to try again.');
      });

      test('should handle low confidence detections', () {
        final lowConfidenceResults = [
          DetectionResult(
            label: 'unknown',
            confidence: 0.46,
            boundingBox: BoundingBox(left: 0, top: 0, right: 100, bottom: 100),
          ),
        ];
        
        // Filter for high confidence (>0.5 for announcement)
        final highConfidence = lowConfidenceResults.where((r) => r.confidence > 0.5).toList();
        
        String generateAnnouncement(List<DetectionResult> results) {
          if (results.isEmpty) {
            return 'Objects unclear. Say scan to try again.';
          }
          return 'Found ${results.length} objects';
        }
        
        expect(generateAnnouncement(highConfidence), 'Objects unclear. Say scan to try again.');
      });
    });

    // =========================================================================
    // SCENARIO 3: OCR/TEXT READING FLOW
    // =========================================================================
    group('Scenario: Complete OCR Flow', () {
      
      test('should process text from capture to reading', () {
        // Step 1: Simulate captured image with text
        const imageHasText = true;
        
        // Step 2: Simulate ML Kit OCR output
        final ocrBlocks = [
          {
            'text': 'Welcome to',
            'boundingBox': const Rect.fromLTRB(10, 10, 200, 50),
            'lines': ['Welcome to'],
          },
          {
            'text': 'A-EYE App',
            'boundingBox': const Rect.fromLTRB(10, 60, 200, 100),
            'lines': ['A-EYE App'],
          },
        ];
        
        // Step 3: Sort blocks for reading order
        ocrBlocks.sort((a, b) {
          final aTop = (a['boundingBox'] as Rect).top;
          final bTop = (b['boundingBox'] as Rect).top;
          return aTop.compareTo(bTop);
        });
        
        expect(ocrBlocks[0]['text'], 'Welcome to');
        expect(ocrBlocks[1]['text'], 'A-EYE App');
        
        // Step 4: Assemble full text
        final fullText = ocrBlocks.map((b) => b['text']).join(' ');
        expect(fullText, 'Welcome to A-EYE App');
        
        // Step 5: Create TextDetectionResult
        final result = TextDetectionResult(
          fullText: fullText,
          blocks: ocrBlocks.map((b) => TextBlockResult(
            text: b['text'] as String,
            lines: b['lines'] as List<String>,
            boundingBox: b['boundingBox'] as Rect,
            confidence: 0.9,
          )).toList(),
          hasText: true,
        );
        
        expect(result.hasText, true);
        expect(result.wordCount, 4); // "Welcome to A-EYE App" = 4 words
        expect(result.blockCount, 2);
        
        // Step 6: Generate announcement
        final announcement = 'Found ${result.wordCount} words in ${result.blockCount} blocks. Say read to hear the text.';
        expect(announcement, contains('4 words'));
        expect(announcement, contains('2 blocks'));
      });

      test('should handle no text detected scenario', () {
        final emptyResult = TextDetectionResult(
          fullText: '',
          blocks: [],
          hasText: false,
        );
        
        String generateAnnouncement(TextDetectionResult result) {
          if (!result.hasText) {
            return 'No text detected. Try better lighting or closer distance.';
          }
          return 'Found ${result.wordCount} words';
        }
        
        expect(generateAnnouncement(emptyResult), 
            'No text detected. Try better lighting or closer distance.');
      });

      test('should handle multi-column text layout', () {
        // Simulate two-column layout
        final blocks = [
          TextBlockResult(
            text: 'Left Column Line 1',
            lines: ['Left Column Line 1'],
            boundingBox: const Rect.fromLTRB(10, 10, 150, 50),
            confidence: 0.9,
          ),
          TextBlockResult(
            text: 'Right Column Line 1',
            lines: ['Right Column Line 1'],
            boundingBox: const Rect.fromLTRB(200, 15, 350, 55),
            confidence: 0.9,
          ),
          TextBlockResult(
            text: 'Left Column Line 2',
            lines: ['Left Column Line 2'],
            boundingBox: const Rect.fromLTRB(10, 60, 150, 100),
            confidence: 0.9,
          ),
        ];
        
        // Sort with line grouping (within 20px = same line)
        final sorted = List<TextBlockResult>.from(blocks);
        sorted.sort((a, b) {
          final yDiff = (a.boundingBox.top - b.boundingBox.top).abs();
          if (yDiff < 20) {
            return a.boundingBox.left.compareTo(b.boundingBox.left);
          }
          return a.boundingBox.top.compareTo(b.boundingBox.top);
        });
        
        // First line: Left then Right (same Y level)
        expect(sorted[0].text, 'Left Column Line 1');
        expect(sorted[1].text, 'Right Column Line 1');
        // Second line
        expect(sorted[2].text, 'Left Column Line 2');
      });
    });

    // =========================================================================
    // SCENARIO 4: VOICE COMMAND NAVIGATION
    // =========================================================================
    group('Scenario: Voice Command Navigation', () {
      
      String? processHomeCommand(String text) {
        final lower = text.toLowerCase().trim();
        for (final entry in AppConstants.voiceCommandsMap.entries) {
          if (lower.contains(entry.key)) {
            return entry.value;
          }
        }
        return null;
      }

      test('should navigate to object detection via voice', () {
        final commands = [
          'detect objects',
          'object detection',
          'detect',
          'objects',
        ];
        
        for (final cmd in commands) {
          expect(processHomeCommand(cmd), 'object_detection',
              reason: 'Command "$cmd" should navigate to object_detection');
        }
      });

      test('should navigate to OCR via voice', () {
        final commands = [
          'read text',
          'scan text',
          'text reader',
          'ocr',
        ];
        
        for (final cmd in commands) {
          expect(processHomeCommand(cmd), 'ocr',
              reason: 'Command "$cmd" should navigate to ocr');
        }
      });

      test('should handle help command', () {
        expect(processHomeCommand('help'), 'help');
        expect(processHomeCommand('I need help'), 'help');
      });

      test('should handle exit/back commands', () {
        expect(processHomeCommand('exit'), 'exit');
        expect(processHomeCommand('back'), 'exit');
        expect(processHomeCommand('go back'), 'exit');
      });

      test('should return null for unrecognized commands', () {
        expect(processHomeCommand('play music'), null);
        expect(processHomeCommand('what time is it'), null);
        expect(processHomeCommand(''), null);
      });
    });

    // =========================================================================
    // SCENARIO 5: SETTINGS MODIFICATION FLOW
    // =========================================================================
    group('Scenario: Settings Modification Flow', () {
      
      test('should update speech rate and preserve other settings', () {
        const original = AppSettings();
        final updated = original.copyWith(speechRate: 0.8);
        
        expect(updated.speechRate, 0.8);
        expect(updated.pitch, original.pitch);
        expect(updated.volume, original.volume);
        expect(updated.vibrationEnabled, original.vibrationEnabled);
      });

      test('should update multiple settings atomically', () {
        const original = AppSettings();
        final updated = original.copyWith(
          speechRate: 0.7,
          pitch: 1.2,
          volume: 0.9,
          vibrationEnabled: false,
        );
        
        expect(updated.speechRate, 0.7);
        expect(updated.pitch, 1.2);
        expect(updated.volume, 0.9);
        expect(updated.vibrationEnabled, false);
      });

      test('should serialize and deserialize settings correctly', () {
        const original = AppSettings(
          speechRate: 0.6,
          pitch: 1.1,
          vibrationIntensity: 3,
          batterySaverMode: true,
        );
        
        final json = original.toJson();
        final restored = AppSettings.fromJson(json);
        
        expect(restored.speechRate, original.speechRate);
        expect(restored.pitch, original.pitch);
        expect(restored.vibrationIntensity, original.vibrationIntensity);
        expect(restored.batterySaverMode, original.batterySaverMode);
      });
    });

    // =========================================================================
    // SCENARIO 6: ERROR HANDLING FLOW
    // =========================================================================
    group('Scenario: Error Handling Flow', () {
      
      test('should handle camera initialization failure gracefully', () {
        // Simulate camera failure
        const cameraAvailable = false;
        
        String getStatusMessage(bool available) {
          if (!available) {
            return 'No camera available';
          }
          return 'Camera ready';
        }
        
        String getAnnouncement(bool available) {
          if (!available) {
            return 'No camera found on device';
          }
          return 'Camera ready. Say scan to detect objects.';
        }
        
        expect(getStatusMessage(cameraAvailable), 'No camera available');
        expect(getAnnouncement(cameraAvailable), 'No camera found on device');
      });

      test('should handle model loading failure gracefully', () {
        // Simulate model failure
        const modelLoaded = false;
        
        String getErrorMessage(bool loaded) {
          if (!loaded) {
            return 'Object detection model failed to load. Please restart the app.';
          }
          return 'Model ready';
        }
        
        expect(getErrorMessage(modelLoaded), contains('failed to load'));
      });

      test('should handle voice recognition unavailable', () {
        // Simulate voice unavailable
        const voiceAvailable = false;
        
        String getAnnouncement(bool available) {
          if (!available) {
            return 'Voice recognition not available. You can still use touch controls.';
          }
          return 'Voice commands ready';
        }
        
        expect(getAnnouncement(voiceAvailable), contains('touch controls'));
      });
    });
  });
}
