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

  /// Recognize text from image - optimized for speed
  Future<TextDetectionResult> recognizeText(XFile imageFile) async {
    if (!_isInitialized) await initialize();

    try {
      final stopwatch = Stopwatch()..start();
      
     
      final processedPath = await _quickPreprocess(imageFile.path);
      debugPrint('Preprocess: ${stopwatch.elapsedMilliseconds}ms');
      
      final inputImage = InputImage.fromFilePath(processedPath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      debugPrint(' OCR: ${stopwatch.elapsedMilliseconds}ms');
      
      // Clean up preprocessed file
      if (processedPath != imageFile.path) {
        File(processedPath).delete().catchError((_) => File(processedPath));
      }

      final result = _parseRecognizedText(recognizedText);
      debugPrint(' Total: ${stopwatch.elapsedMilliseconds}ms, ${result.wordCount} words');
      
      return result;
    } catch (e) {
      debugPrint('Error recognizing text: $e');
      return TextDetectionResult(fullText: '', blocks: [], hasText: false);
    }
  }

  /// Quick preprocessing - minimal operations for speed
  Future<String> _quickPreprocess(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      var image = img.decodeImage(bytes);

      if (image == null) return imagePath;

      // Only auto-rotate based on EXIF - this is fast
      image = img.bakeOrientation(image);

      // Resize if too large (speeds up OCR significantly)
      if (image.width > 1500 || image.height > 1500) {
        final scale = 1500 / (image.width > image.height ? image.width : image.height);
        image = img.copyResize(
          image,
          width: (image.width * scale).toInt(),
          height: (image.height * scale).toInt(),
          interpolation: img.Interpolation.linear,
        );
      }

      // Save with moderate quality
      final tempDir = Directory.systemTemp;
      final processedPath = '${tempDir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(processedPath).writeAsBytes(img.encodeJpg(image, quality: 85));

      return processedPath;
    } catch (e) {
      debugPrint('Preprocessing failed: $e');
      return imagePath;
    }
  }

  /// Parse and sort text for natural reading order
  TextDetectionResult _parseRecognizedText(RecognizedText recognizedText) {
    final blocks = <TextBlockResult>[];
    final allLines = <_LineInfo>[];
    
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        allLines.add(_LineInfo(
          text: line.text,
          y: line.boundingBox.top,
          x: line.boundingBox.left,
          bottom: line.boundingBox.bottom,
          height: line.boundingBox.height,
        ));
      }
      
      blocks.add(TextBlockResult(
        text: block.text,
        lines: block.lines.map((l) => l.text).toList(),
        boundingBox: block.boundingBox,
        confidence: 0.8,
      ));
    }

    final sortedText = _buildReadingOrder(allLines);

    return TextDetectionResult(
      fullText: sortedText,
      blocks: blocks,
      hasText: sortedText.trim().isNotEmpty,
    );
  }

  /// Build text in natural reading order (top-to-bottom, left-to-right)
  String _buildReadingOrder(List<_LineInfo> lines) {
    if (lines.isEmpty) return '';
    
    // Calculate average line height for row grouping
    final avgHeight = lines.map((l) => l.height).reduce((a, b) => a + b) / lines.length;
    final rowThreshold = avgHeight * 0.5;
    
    // Sort by Y position
    lines.sort((a, b) => a.y.compareTo(b.y));
    
    // Group into rows
    final rows = <List<_LineInfo>>[];
    for (final line in lines) {
      bool added = false;
      for (final row in rows) {
        if ((line.y - row.first.y).abs() < rowThreshold) {
          row.add(line);
          added = true;
          break;
        }
      }
      if (!added) rows.add([line]);
    }
    
    // Sort rows top-to-bottom, lines left-to-right within rows
    rows.sort((a, b) => a.first.y.compareTo(b.first.y));
    for (final row in rows) {
      row.sort((a, b) => a.x.compareTo(b.x));
    }
    
    // Build text
    final result = StringBuffer();
    double? lastBottom;
    
    for (final row in rows) {
      // Add space or paragraph break
      if (lastBottom != null) {
        if (row.first.y - lastBottom > avgHeight * 1.2) {
          result.write('. ');
        } else if (result.isNotEmpty) {
          result.write(' ');
        }
      }
      
      result.write(row.map((l) => l.text).join(' '));
      lastBottom = row.map((l) => l.bottom).reduce((a, b) => a > b ? a : b);
    }
    
    // Clean up text
    var text = result.toString();
    text = text.replaceAll(RegExp(r' +'), ' ');
    text = text.replaceAll(RegExp(r'-\s+'), '');
    
    return text.trim();
  }

  Future<void> dispose() async {
    try {
      await _textRecognizer.close();
      _isInitialized = false;
    } catch (e) {
      debugPrint('Error disposing OCR service: $e');
    }
  }
}

// Ensure OCR service is disposed when app closes
// Call this in main app dispose or when OCR screen is permanently closed

class _LineInfo {
  final String text;
  final double y;
  final double x;
  final double bottom;
  final double height;
  
  _LineInfo({
    required this.text,
    required this.y,
    required this.x,
    required this.bottom,
    required this.height,
  });
}
