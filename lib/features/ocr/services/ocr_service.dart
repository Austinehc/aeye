import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
import '../models/text_detection_result.dart';

class OCRService {
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // Initialize OCR service
  Future<void> initialize() async {
    _isInitialized = true;
    print('OCR Service initialized');
  }

  // Recognize text from image
  Future<TextDetectionResult> recognizeText(XFile imageFile) async {
    if (!_isInitialized) {
      print('🔄 OCR not initialized, initializing now...');
      await initialize();
    }

    try {
      print('📸 Processing image: ${imageFile.path}');
      final inputImage = InputImage.fromFilePath(imageFile.path);
      
      print('🔍 Running text recognition...');
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      print('✅ Text recognition completed');
      print('   Blocks found: ${recognizedText.blocks.length}');
      print('   Full text length: ${recognizedText.text.length}');
      
      if (recognizedText.blocks.isEmpty) {
        print('⚠️ No text blocks detected in image');
      } else {
        print('📝 Sample text: ${recognizedText.text.substring(0, recognizedText.text.length > 50 ? 50 : recognizedText.text.length)}...');
      }

      return _parseRecognizedText(recognizedText);
    } catch (e, stackTrace) {
      print('❌ Error recognizing text: $e');
      print('📋 Stack trace: $stackTrace');
      return TextDetectionResult(
        fullText: '',
        blocks: [],
        hasText: false,
      );
    }
  }

  // Parse recognized text and sort naturally (top-to-bottom, left-to-right)
  TextDetectionResult _parseRecognizedText(RecognizedText recognizedText) {
    final blocks = <TextBlockResult>[];
    
    // Collect all blocks with their positions
    final blocksList = <Map<String, dynamic>>[];
    
    for (final block in recognizedText.blocks) {
      final lines = <String>[];
      
      for (final line in block.lines) {
        lines.add(line.text);
      }

      blocksList.add({
        'block': TextBlockResult(
          text: block.text,
          lines: lines,
          boundingBox: block.boundingBox,
          confidence: _calculateConfidence(block),
        ),
        'y': block.boundingBox.top,
        'x': block.boundingBox.left,
      });
    }

    // Sort blocks naturally: top-to-bottom, then left-to-right
    blocksList.sort((a, b) {
      final yDiff = (a['y'] as double) - (b['y'] as double);
      
      // If blocks are on roughly the same line (within 20 pixels), sort by x
      if (yDiff.abs() < 20) {
        return ((a['x'] as double) - (b['x'] as double)).round();
      }
      
      // Otherwise sort by y (top to bottom)
      return yDiff.round();
    });

    // Extract sorted blocks
    for (final item in blocksList) {
      blocks.add(item['block'] as TextBlockResult);
    }

    // Build full text in natural reading order with proper spacing
    final textParts = <String>[];
    double? lastY;
    
    for (final block in blocks) {
      final currentY = block.boundingBox.top;
      
      // Add line break if this block is on a new line (significant Y difference)
      if (lastY != null && (currentY - lastY).abs() > 20) {
        textParts.add('\n');
      }
      
      textParts.add(block.text);
      lastY = currentY;
    }
    
    final naturalText = textParts.join(' ').replaceAll(' \n ', '\n');

    return TextDetectionResult(
      fullText: naturalText,
      blocks: blocks,
      hasText: naturalText.isNotEmpty,
    );
  }

  // Calculate confidence (simplified)
  double _calculateConfidence(TextBlock block) {
    // Google ML Kit doesn't provide confidence directly
    // We can estimate based on text quality
    if (block.text.isEmpty) return 0.0;
    
    // Basic heuristic: longer blocks with proper formatting get higher confidence
    double confidence = 0.5;
    
    if (block.text.length > 10) confidence += 0.2;
    if (block.lines.length > 1) confidence += 0.1;
    if (RegExp(r'[A-Z]').hasMatch(block.text)) confidence += 0.1;
    if (RegExp(r'[a-z]').hasMatch(block.text)) confidence += 0.1;
    
    return confidence.clamp(0.0, 1.0);
  }

  // Dispose resources
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}