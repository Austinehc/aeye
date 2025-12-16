import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:aeye/features/ocr/models/text_detection_result.dart';

void main() {
  group('TextBlockResult', () {
    test('should store text correctly', () {
      final block = TextBlockResult(
        text: 'Hello World',
        lines: ['Hello World'],
        boundingBox: const Rect.fromLTRB(0, 0, 100, 50),
        confidence: 0.95,
      );
      expect(block.text, 'Hello World');
    });

    test('should store multiple lines correctly', () {
      final block = TextBlockResult(
        text: 'Line 1\nLine 2\nLine 3',
        lines: ['Line 1', 'Line 2', 'Line 3'],
        boundingBox: const Rect.fromLTRB(0, 0, 100, 150),
        confidence: 0.88,
      );
      expect(block.lines.length, 3);
      expect(block.lines[0], 'Line 1');
      expect(block.lines[1], 'Line 2');
      expect(block.lines[2], 'Line 3');
    });

    test('should format confidence as percentage', () {
      final block = TextBlockResult(
        text: 'Test',
        lines: ['Test'],
        boundingBox: const Rect.fromLTRB(0, 0, 50, 20),
        confidence: 0.756,
      );
      expect(block.confidencePercentage, '75.6%');
    });

    test('should store bounding box correctly', () {
      final block = TextBlockResult(
        text: 'Sample',
        lines: ['Sample'],
        boundingBox: const Rect.fromLTRB(10, 20, 110, 70),
        confidence: 0.9,
      );
      expect(block.boundingBox.left, 10);
      expect(block.boundingBox.top, 20);
      expect(block.boundingBox.right, 110);
      expect(block.boundingBox.bottom, 70);
    });
  });

  group('TextDetectionResult', () {
    test('should indicate hasText when text is present', () {
      final result = TextDetectionResult(
        fullText: 'Some text here',
        blocks: [
          TextBlockResult(
            text: 'Some text here',
            lines: ['Some text here'],
            boundingBox: const Rect.fromLTRB(0, 0, 200, 50),
            confidence: 0.9,
          ),
        ],
        hasText: true,
      );
      expect(result.hasText, true);
    });

    test('should indicate no text when empty', () {
      final result = TextDetectionResult(
        fullText: '',
        blocks: [],
        hasText: false,
      );
      expect(result.hasText, false);
    });

    test('should count blocks correctly', () {
      final result = TextDetectionResult(
        fullText: 'Block 1 Block 2 Block 3',
        blocks: [
          TextBlockResult(
            text: 'Block 1',
            lines: ['Block 1'],
            boundingBox: const Rect.fromLTRB(0, 0, 100, 50),
            confidence: 0.9,
          ),
          TextBlockResult(
            text: 'Block 2',
            lines: ['Block 2'],
            boundingBox: const Rect.fromLTRB(0, 60, 100, 110),
            confidence: 0.85,
          ),
          TextBlockResult(
            text: 'Block 3',
            lines: ['Block 3'],
            boundingBox: const Rect.fromLTRB(0, 120, 100, 170),
            confidence: 0.88,
          ),
        ],
        hasText: true,
      );
      expect(result.blockCount, 3);
    });

    test('should count words correctly', () {
      final result = TextDetectionResult(
        fullText: 'The quick brown fox jumps',
        blocks: [
          TextBlockResult(
            text: 'The quick brown fox jumps',
            lines: ['The quick brown fox jumps'],
            boundingBox: const Rect.fromLTRB(0, 0, 300, 50),
            confidence: 0.92,
          ),
        ],
        hasText: true,
      );
      expect(result.wordCount, 5);
    });

    test('should count lines correctly', () {
      final result = TextDetectionResult(
        fullText: 'Line one\nLine two\nLine three',
        blocks: [
          TextBlockResult(
            text: 'Line one\nLine two\nLine three',
            lines: ['Line one', 'Line two', 'Line three'],
            boundingBox: const Rect.fromLTRB(0, 0, 200, 150),
            confidence: 0.9,
          ),
        ],
        hasText: true,
      );
      expect(result.lineCount, 3);
    });

    test('should handle empty blocks list', () {
      final result = TextDetectionResult(
        fullText: '',
        blocks: [],
        hasText: false,
      );
      expect(result.blockCount, 0);
      expect(result.wordCount, 0);
    });

    test('should handle single word', () {
      final result = TextDetectionResult(
        fullText: 'Hello',
        blocks: [
          TextBlockResult(
            text: 'Hello',
            lines: ['Hello'],
            boundingBox: const Rect.fromLTRB(0, 0, 50, 20),
            confidence: 0.95,
          ),
        ],
        hasText: true,
      );
      expect(result.wordCount, 1);
      expect(result.blockCount, 1);
    });

    test('should handle text with extra spaces', () {
      final result = TextDetectionResult(
        fullText: 'Word1  Word2   Word3',
        blocks: [],
        hasText: true,
      );
      // Split by space filters empty strings
      expect(result.wordCount, 3);
    });
  });
}
