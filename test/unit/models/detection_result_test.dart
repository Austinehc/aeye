import 'package:flutter_test/flutter_test.dart';
import 'package:aeye/features/object_detection/models/detection_result.dart';

void main() {
  group('BoundingBox', () {
    test('should calculate width correctly', () {
      final box = BoundingBox(left: 10, top: 20, right: 110, bottom: 120);
      expect(box.width, 100);
    });

    test('should calculate height correctly', () {
      final box = BoundingBox(left: 10, top: 20, right: 110, bottom: 120);
      expect(box.height, 100);
    });

    test('should calculate centerX correctly', () {
      final box = BoundingBox(left: 10, top: 20, right: 110, bottom: 120);
      expect(box.centerX, 60);
    });

    test('should calculate centerY correctly', () {
      final box = BoundingBox(left: 10, top: 20, right: 110, bottom: 120);
      expect(box.centerY, 70);
    });

    test('should calculate area correctly', () {
      final box = BoundingBox(left: 0, top: 0, right: 50, bottom: 40);
      expect(box.area, 2000);
    });

    test('should calculate center offset correctly', () {
      final box = BoundingBox(left: 0, top: 0, right: 100, bottom: 100);
      expect(box.center.dx, 50);
      expect(box.center.dy, 50);
    });

    test('should handle zero-size box', () {
      final box = BoundingBox(left: 50, top: 50, right: 50, bottom: 50);
      expect(box.width, 0);
      expect(box.height, 0);
      expect(box.area, 0);
    });

    test('should produce correct string representation', () {
      final box = BoundingBox(left: 10, top: 20, right: 30, bottom: 40);
      final str = box.toString();
      expect(str, contains('left: 10'));
      expect(str, contains('top: 20'));
      expect(str, contains('right: 30'));
      expect(str, contains('bottom: 40'));
    });
  });

  group('DetectionResult', () {
    test('should store label correctly', () {
      final result = DetectionResult(
        label: 'person',
        confidence: 0.95,
        boundingBox: BoundingBox(left: 0, top: 0, right: 100, bottom: 100),
      );
      expect(result.label, 'person');
    });

    test('should store confidence correctly', () {
      final result = DetectionResult(
        label: 'car',
        confidence: 0.87,
        boundingBox: BoundingBox(left: 0, top: 0, right: 100, bottom: 100),
      );
      expect(result.confidence, 0.87);
    });

    test('should format confidence as percentage', () {
      final result = DetectionResult(
        label: 'chair',
        confidence: 0.756,
        boundingBox: BoundingBox(left: 0, top: 0, right: 100, bottom: 100),
      );
      expect(result.confidencePercentage, '76%');
    });

    test('should round confidence percentage correctly', () {
      final result = DetectionResult(
        label: 'table',
        confidence: 0.994,
        boundingBox: BoundingBox(left: 0, top: 0, right: 100, bottom: 100),
      );
      expect(result.confidencePercentage, '99%');
    });

    test('should handle 100% confidence', () {
      final result = DetectionResult(
        label: 'door',
        confidence: 1.0,
        boundingBox: BoundingBox(left: 0, top: 0, right: 100, bottom: 100),
      );
      expect(result.confidencePercentage, '100%');
    });

    test('should handle low confidence', () {
      final result = DetectionResult(
        label: 'bicycle',
        confidence: 0.45,
        boundingBox: BoundingBox(left: 0, top: 0, right: 100, bottom: 100),
      );
      expect(result.confidencePercentage, '45%');
    });

    test('should produce correct string representation', () {
      final result = DetectionResult(
        label: 'person',
        confidence: 0.92,
        boundingBox: BoundingBox(left: 10, top: 20, right: 110, bottom: 120),
      );
      final str = result.toString();
      expect(str, contains('person'));
      expect(str, contains('92%'));
    });

    test('should store bounding box correctly', () {
      final box = BoundingBox(left: 15, top: 25, right: 115, bottom: 125);
      final result = DetectionResult(
        label: 'cat',
        confidence: 0.88,
        boundingBox: box,
      );
      expect(result.boundingBox.left, 15);
      expect(result.boundingBox.top, 25);
      expect(result.boundingBox.right, 115);
      expect(result.boundingBox.bottom, 125);
    });
  });
}
