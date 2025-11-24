import 'dart:ui';

class TextDetectionResult {
  final String fullText;
  final List<TextBlockResult> blocks;
  final bool hasText;

  TextDetectionResult({
    required this.fullText,
    required this.blocks,
    required this.hasText,
  });

  int get blockCount => blocks.length;
  int get wordCount => fullText.split(' ').where((w) => w.isNotEmpty).length;
  int get lineCount => fullText.split('\n').where((l) => l.isNotEmpty).length;
}

class TextBlockResult {
  final String text;
  final List<String> lines;
  final Rect boundingBox;
  final double confidence;

  TextBlockResult({
    required this.text,
    required this.lines,
    required this.boundingBox,
    required this.confidence,
  });

  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';
}