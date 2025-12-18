import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../models/text_detection_result.dart';

class OCRService {
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    _isInitialized = true;
    debugPrint('OCR Service initialized');
  }

  /// Recognize text from image with preprocessing for documents
  Future<TextDetectionResult> recognizeText(XFile imageFile) async {
    if (!_isInitialized) await initialize();

    try {
      // Preprocess image for better OCR
      final processedPath = await _preprocessImage(imageFile.path);
      final inputImage = InputImage.fromFilePath(processedPath);
      
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      // Clean up preprocessed file
      if (processedPath != imageFile.path) {
        File(processedPath).delete().catchError((_) => File(processedPath));
      }

      return _parseRecognizedText(recognizedText);
    } catch (e) {
      debugPrint('Error recognizing text: $e');
      return TextDetectionResult(fullText: '', blocks: [], hasText: false);
    }
  }

  /// Preprocess image for better document OCR with auto-alignment
  Future<String> _preprocessImage(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      var image = img.decodeImage(bytes);

      if (image == null) return imagePath;

      // Step 1: Auto-rotate based on EXIF orientation
      image = img.bakeOrientation(image);

      // Step 2: Detect and correct skew angle
      image = _deskewImage(image);

      // Step 3: Convert to grayscale
      image = img.grayscale(image);

      // Step 4: Increase contrast for printed text
      image = img.adjustColor(image, contrast: 1.4);

      // Step 5: Slight brightness boost for documents
      image = img.adjustColor(image, brightness: 1.1);

      // Save preprocessed image
      final tempDir = Directory.systemTemp;
      final processedPath = '${tempDir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(processedPath).writeAsBytes(img.encodeJpg(image, quality: 95));

      return processedPath;
    } catch (e) {
      debugPrint('Preprocessing failed: $e');
      return imagePath;
    }
  }

  /// Detect skew angle and rotate image to align text horizontally
  img.Image _deskewImage(img.Image image) {
    try {
      // Convert to grayscale for edge detection
      final gray = img.grayscale(img.copyResize(image, width: 500));

      // Detect skew angle using horizontal projection
      final skewAngle = _detectSkewAngle(gray);

      // Only correct if skew is significant but not too extreme
      if (skewAngle.abs() > 0.5 && skewAngle.abs() < 15) {
        debugPrint('Deskewing image by $skewAngle degrees');
        return img.copyRotate(image, angle: -skewAngle);
      }

      return image;
    } catch (e) {
      debugPrint('Deskew failed: $e');
      return image;
    }
  }

  /// Detect skew angle by analyzing horizontal text line patterns
  double _detectSkewAngle(img.Image grayImage) {
    // Apply edge detection to find text edges
    final edges = img.sobel(grayImage);

    // Sample angles from -10 to +10 degrees
    double bestAngle = 0;
    int maxScore = 0;

    for (double angle = -10; angle <= 10; angle += 0.5) {
      final score = _calculateProjectionScore(edges, angle);
      if (score > maxScore) {
        maxScore = score;
        bestAngle = angle;
      }
    }

    return bestAngle;
  }

  /// Calculate horizontal projection score for a given rotation angle
  /// Higher score = more horizontal alignment (text lines are straighter)
  int _calculateProjectionScore(img.Image edges, double angle) {
    final width = edges.width;
    final height = edges.height;

    // Create horizontal projection histogram
    final projection = List<int>.filled(height, 0);

    // Calculate rotation offset
    final radians = angle * 3.14159 / 180;
    final cos = _cos(radians);
    final sin = _sin(radians);

    final centerX = width / 2;
    final centerY = height / 2;

    // Project edge pixels onto horizontal axis
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = edges.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) ~/ 3;

        if (brightness > 50) {
          // Rotate point and get new Y position
          final dx = x - centerX;
          final dy = y - centerY;
          final newY = (dy * cos - dx * sin + centerY).toInt();

          if (newY >= 0 && newY < height) {
            projection[newY]++;
          }
        }
      }
    }

    // Calculate variance of projection (higher = better alignment)
    int sum = 0;
    int sumSq = 0;
    int count = 0;

    for (final val in projection) {
      if (val > 0) {
        sum += val;
        sumSq += val * val;
        count++;
      }
    }

    if (count == 0) return 0;

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);

    return variance.toInt();
  }

  // Simple trig functions to avoid dart:math import issues
  double _cos(double radians) {
    // Taylor series approximation
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= -radians * radians / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  double _sin(double radians) {
    // Taylor series approximation
    double result = radians;
    double term = radians;
    for (int i = 1; i <= 10; i++) {
      term *= -radians * radians / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  /// Parse and sort text for natural reading order (like a human reads)
  TextDetectionResult _parseRecognizedText(RecognizedText recognizedText) {
    final blocks = <TextBlockResult>[];
    
    // Collect all lines with their positions for proper sorting
    final allLines = <Map<String, dynamic>>[];
    
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        allLines.add({
          'text': line.text,
          'y': line.boundingBox.top,
          'x': line.boundingBox.left,
          'bottom': line.boundingBox.bottom,
          'height': line.boundingBox.height,
          'boundingBox': line.boundingBox,
        });
      }
      
      // Also store block info for overlay
      blocks.add(TextBlockResult(
        text: block.text,
        lines: block.lines.map((l) => l.text).toList(),
        boundingBox: block.boundingBox,
        confidence: _calculateConfidence(block),
      ));
    }

    // Sort lines for natural reading order
    final sortedText = _buildNaturalReadingOrder(allLines);

    return TextDetectionResult(
      fullText: sortedText,
      blocks: blocks,
      hasText: sortedText.trim().isNotEmpty,
    );
  }

  /// Sort lines and build text in natural human reading order
  /// Reads top-to-bottom, left-to-right like reading a document
  String _buildNaturalReadingOrder(List<Map<String, dynamic>> lines) {
    if (lines.isEmpty) return '';
    
    // Calculate average line height for row grouping
    final avgHeight = lines.map((l) => l['height'] as double).reduce((a, b) => a + b) / lines.length;
    
    // Row threshold: lines within 40% of avg height are considered same row
    // This handles multi-column layouts where text is side by side
    final rowThreshold = avgHeight * 0.4;
    
    // Group lines into rows (lines at similar Y positions)
    final rows = <List<Map<String, dynamic>>>[];
    
    // Sort by Y position first
    lines.sort((a, b) => (a['y'] as double).compareTo(b['y'] as double));
    
    for (final line in lines) {
      final lineY = line['y'] as double;
      bool addedToRow = false;
      
      // Check if this line belongs to an existing row (same horizontal level)
      for (final row in rows) {
        final rowY = row.first['y'] as double;
        if ((lineY - rowY).abs() < rowThreshold) {
          row.add(line);
          addedToRow = true;
          break;
        }
      }
      
      if (!addedToRow) {
        rows.add([line]);
      }
    }
    
    // Sort rows by Y position (top to bottom)
    rows.sort((a, b) => (a.first['y'] as double).compareTo(b.first['y'] as double));
    
    // Within each row, sort by X position (left to right)
    for (final row in rows) {
      row.sort((a, b) => (a['x'] as double).compareTo(b['x'] as double));
    }
    
    // Build the final text - read line by line like a document
    final result = StringBuffer();
    double? lastRowBottom;
    
    for (final row in rows) {
      final currentRowY = row.first['y'] as double;
      
      // Add paragraph break if there's a large vertical gap (new paragraph)
      if (lastRowBottom != null && currentRowY - lastRowBottom > avgHeight * 1.2) {
        result.write('. '); // Pause between paragraphs for TTS
      } else if (result.isNotEmpty) {
        result.write(' '); // Normal space between lines
      }
      
      // Join text fragments in this row (handles multi-column)
      final rowText = row.map((l) => l['text'] as String).join(' ');
      result.write(rowText);
      
      // Track bottom of this row
      lastRowBottom = row.map((l) => l['bottom'] as double).reduce((a, b) => a > b ? a : b);
    }
    
    // Clean up the text for natural reading
    var text = result.toString();
    text = text.replaceAll(RegExp(r' +'), ' '); // Multiple spaces to single
    text = text.replaceAll(RegExp(r'\. +\.'), '.'); // Multiple periods
    text = text.replaceAll(RegExp(r'-\s+'), ''); // Hyphenated line breaks
    text = text.replaceAll(RegExp(r'(\w)\s*-\s*(\w)'), r'$1$2'); // Hyphenated words
    
    return text.trim();
  }

  double _calculateConfidence(TextBlock block) {
    if (block.text.isEmpty) return 0.0;
    double confidence = 0.5;
    if (block.text.length > 10) confidence += 0.2;
    if (block.lines.length > 1) confidence += 0.1;
    if (RegExp(r'[A-Za-z]').hasMatch(block.text)) confidence += 0.2;
    return confidence.clamp(0.0, 1.0);
  }

  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
