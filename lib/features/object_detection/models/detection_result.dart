import 'dart:ui';

class DetectionResult {
  final String label;
  final double confidence;
  final BoundingBox boundingBox;

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  String get confidencePercentage => '${(confidence * 100).round()}%';

  @override
  String toString() {
    return 'DetectionResult(label: $label, confidence: $confidencePercentage)';
  }
}

class BoundingBox {
  final double left;
  final double top;
  final double right;
  final double bottom;

  BoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
  double get area => width * height;
  
  Offset get center => Offset(centerX, centerY);

  @override
  String toString() {
    return 'BoundingBox(left: $left, top: $top, right: $right, bottom: $bottom)';
  }
}