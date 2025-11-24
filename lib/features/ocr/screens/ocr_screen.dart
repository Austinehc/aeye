import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:vibration/vibration.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_service.dart';
import '../../../core/utils/vibration_helper.dart';
import '../../../core/utils/audio_feedback.dart';
import '../services/ocr_service.dart';
import '../models/text_detection_result.dart';
import '../../voice/services/voice_service.dart';

class OCRScreen extends StatefulWidget {
  const OCRScreen({Key? key}) : super(key: key);

  @override
  State<OCRScreen> createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  final TTSService _tts = TTSService();
  final OCRService _ocrService = OCRService();
  final VoiceService _voiceService = VoiceService();
  
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  TextDetectionResult? _detectionResult;
  String _statusMessage = 'Initializing camera...';
  bool _isReading = false;
  bool _isListening = false;
  String _recognizedText = '';
  int? _srcW;
  int? _srcH;

  @override
  void initState() {
    super.initState();
    AudioFeedback.initialize(); // ✅ Initialize audio feedback
    _initializeCamera();
    _initializeVoice(); // REMOVED: _announceScreen() - no startup feedback
    _tts.addOnStartListener(_onTtsStart);
    _tts.addOnCompleteListener(_onTtsComplete);
  }

  Future<void> _initializeVoice() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      
      if (status.isDenied) {
        setState(() {
          _statusMessage = 'Microphone permission denied';
        });
        await _tts.speak(
          'Microphone permission is required for voice commands. '
          'Voice commands will not work without it.'
        );
        return;
      }
      
      if (status.isPermanentlyDenied) {
        setState(() {
          _statusMessage = 'Microphone permission permanently denied';
        });
        await _tts.speak(
          'Microphone permission is permanently denied. '
          'Please enable it in app settings to use voice commands.'
        );
        return;
      }
      
      // Initialize voice service
      print(' Initializing voice service...');
      final ok = await _voiceService.initialize();
      
      if (ok) {
        print(' Voice service initialized successfully');
        _startListening();
      } else {
        print(' Voice service initialization failed');
        setState(() {
          _statusMessage = 'Voice recognition not available';
        });
        await _tts.speak(
          'Voice recognition is not available on this device. '
          'Voice commands will not work.'
        );
      }
    } catch (e) {
      print(' Error initializing voice: $e');
      setState(() {
        _statusMessage = 'Voice initialization error';
      });
      await _tts.speak('Failed to initialize voice commands');
    }
  }

  void _onTtsStart() {
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
    _voiceService.cancelListening();
  }

  void _onTtsComplete() {
    // Wait a bit before restarting listening to avoid conflicts
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_isListening) {
        _startListening();
      }
    });
  }

  Future<void> _startListening() async {
    if (_isListening) return;
    setState(() {
      _isListening = true;
      _recognizedText = '';
    });
    await _voiceService.startListening(
      onResult: (text) async {
        setState(() {
          _isListening = false;
          _recognizedText = text;
        });
        await _handleVoiceResult(text);
        if (mounted) {
          _startListening();
        }
      },
      onPartialResult: (text) {
        setState(() {
          _recognizedText = text;
        });
      },
    );
  }

  Future<void> _handleVoiceResult(String text) async {
    final t = text.toLowerCase();
    if (t.contains('scan') || t.contains('detect') || t.contains('recognize') || t.contains('again')) {
      AudioFeedback.success(); // SUCCESS BEEP: Audio feedback for successful voice command
      await _captureAndRecognize();
      return;
    }
    if (t.contains('read') || t.contains('play')) {
      AudioFeedback.success(); // SUCCESS BEEP: Audio feedback for successful voice command
      await _readText();
      return;
    }
    if (t.contains('stop') || t.contains('pause')) {
      AudioFeedback.success(); // SUCCESS BEEP: Audio feedback for successful voice command
      if (_isReading) {
        await _tts.stop();
        setState(() { _isReading = false; });
        await _tts.speak('Stopped');
      } else {
        await _tts.speak('Nothing is being read');
      }
      return;
    }
    if (t.contains('help')) {
      AudioFeedback.success(); // SUCCESS BEEP: Audio feedback for successful voice command
      await _tts.speak('Text is scanned automatically. Say scan to scan again, read to read it aloud, stop to stop reading, or back to go back.');
      return;
    }
    if (t.contains('back')) {
      AudioFeedback.success(); // SUCCESS BEEP: Audio feedback for successful voice command
      await _tts.speak('Going back');
      if (mounted) Navigator.pop(context);
      return;
    }
    
    AudioFeedback.error(); // ERROR BEEP: Audio feedback for failed voice command
    await _tts.speak('Command not recognized. Try: scan, read, stop, help, or back.');
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _statusMessage = 'No camera available';
        });
        await _tts.speak('No camera found on device');
        return;
      }

      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      
      // Set camera to maximum FPS for smooth video
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);
      
      await _ocrService.initialize();

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Ready to scan text';
      });

      await _tts.speak('Camera ready. Scanning text automatically.');
      
      // Auto-scan after a short delay
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted && _isInitialized) {
        await _captureAndRecognize();
      }
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() {
        _statusMessage = 'Camera error';
      });
      await _tts.speak('Failed to initialize camera');
    }
  }

  Future<void> _captureAndRecognize() async {
    if (!_isInitialized || _isProcessing || _cameraController == null) {
      print('⚠️ Cannot capture: initialized=$_isInitialized, processing=$_isProcessing, camera=${_cameraController != null}');
      return;
    }

    print('📸 Starting capture and recognize...');
    
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Scanning text...';
    });

    // Vibrate for feedback
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }

    await _tts.speak('Scanning text');

    try {
      // Capture image
      print('📷 Taking picture...');
      final image = await _cameraController!.takePicture();
      print('✅ Picture captured: ${image.path}');
      
      try {
        final bytes = await File(image.path).readAsBytes();
        print('📊 Image size: ${bytes.length} bytes');
        final decoded = img.decodeImage(bytes);
          if (decoded != null) {
            // ✅ FIX: Check EXIF orientation for correct dimensions
            // Orientation 5, 6, 7, 8 means the image is rotated 90 or 270 degrees
            // so we need to swap width and height for the coordinate system.
            final orientation = decoded.exif.imageIfd.orientation ?? 1;
            if (orientation >= 5 && orientation <= 8) {
              _srcW = decoded.height;
              _srcH = decoded.width;
            } else {
              _srcW = decoded.width;
              _srcH = decoded.height;
            }
            print('🖼️ Image dimensions (adjusted for EXIF $orientation): ${_srcW}x${_srcH}');
          }
      } catch (e) {
        print('⚠️ Error decoding image for dimensions: $e');
      }
      
      // Recognize text
      print('🔍 Starting text recognition...');
      final result = await _ocrService.recognizeText(image);
      print('✅ Text recognition completed');

      setState(() {
        _detectionResult = result;
        _isProcessing = false;
        _statusMessage = result.hasText 
            ? '${result.wordCount} words detected' 
            : 'No text detected';
      });

      // Announce results
      await _announceResults(result);
    } catch (e) {
      print('Error recognizing text: $e');
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Recognition failed';
      });
      await _tts.speak('Text recognition failed. Please try again.');
    }
  }

  Future<void> _announceResults(TextDetectionResult result) async {
    print('📢 Announcing results: hasText=${result.hasText}, words=${result.wordCount}, blocks=${result.blockCount}');
    
    if (!result.hasText) {
      print('⚠️ No text detected');
      await _tts.speak('No text detected. Try better lighting or closer distance.');
      return;
    }

    String message = 'Found ${result.wordCount} word';
    if (result.wordCount != 1) message += 's';
    message += ' in ${result.blockCount} block';
    if (result.blockCount != 1) message += 's';
    message += '. Say read to hear the text.';

    print('📢 Announcement: $message');
    await _tts.speak(message);
  }

  Future<void> _readText() async {
    if (_detectionResult == null || !_detectionResult!.hasText) {
      await _tts.speak('No text to read. Say scan to recognize text first.');
      return;
    }

    if (_isReading) {
      await _tts.stop();
      setState(() {
        _isReading = false;
      });
      return;
    }

    setState(() {
      _isReading = true;
    });

    // Vibrate for feedback
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 150);
    }

    // Read the full text naturally in one continuous flow
    // The text is already sorted in natural reading order by the OCR service
    final fullText = _detectionResult!.fullText;
    
    if (fullText.isNotEmpty) {
      // Read everything continuously like a human would read
      await _tts.speak(fullText);
    } else {
      await _tts.speak('No text detected.');
    }

    setState(() {
      _isReading = false;
    });
  }

  // Sort text blocks for natural reading order (top to bottom, left to right)
  List<TextBlockResult> _sortBlocksForReading(List<TextBlockResult> blocks) {
    final sortedBlocks = List<TextBlockResult>.from(blocks);
    
    sortedBlocks.sort((a, b) {
      // Group blocks on same line (within 30 pixels vertically)
      final yDiff = (a.boundingBox.top - b.boundingBox.top).abs();
      if (yDiff < 30) {
        // Same line - sort by X (left to right)
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      }
      // Different lines - sort by Y (top to bottom)
      return a.boundingBox.top.compareTo(b.boundingBox.top);
    });
    
    return sortedBlocks;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _tts.stop();
    _voiceService.stopListening();
    _tts.removeOnStartListener(_onTtsStart);
    _tts.removeOnCompleteListener(_onTtsComplete);
    AudioFeedback.dispose(); // ✅ Cleanup audio feedback
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Reader'),
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          iconSize: 35,
          onPressed: () async {
            await _tts.stop();
            await _tts.speak('Going back');
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_detectionResult != null && _detectionResult!.hasText)
            IconButton(
              icon: Icon(_isReading ? Icons.stop : Icons.volume_up),
              iconSize: 35,
              onPressed: _readText,
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview - Full screen without stretching
          if (_isInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: Stack(
                    children: [
                      CameraPreview(_cameraController!),
                      if (_detectionResult != null && _detectionResult!.hasText && _srcW != null && _srcH != null)
                        CustomPaint(
                          size: Size.infinite,
                          painter: TextBlockPainter(_detectionResult!.blocks, _srcW!, _srcH!),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: AppTheme.accentColor,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

          

          // Status Bar with Controls - SafeArea to prevent overflow
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),  // Reduced padding
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ REMOVED: Control buttons - rely solely on voice commands
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Auto-scan enabled. Voice: "scan again", "read", "stop", "help", "back"',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Status Message
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isProcessing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppTheme.accentColor,
                            strokeWidth: 2,
                          ),
                        )
                      else if (_isReading)
                        const Icon(
                          Icons.volume_up,
                          size: 20,
                          color: AppTheme.successColor,
                        )
                      else
                        const Icon(
                          Icons.text_fields,
                          size: 20,
                          color: AppTheme.accentColor,
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusMessage,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_detectionResult != null && _detectionResult!.hasText)
                              Text(
                                '${_detectionResult!.wordCount} words • ${_detectionResult!.blockCount} blocks',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.accentColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),  // Close SafeArea
          ),
        ],
      ),
    );
  }

}

// Custom painter for text blocks
class TextBlockPainter extends CustomPainter {
  final List<TextBlockResult> blocks;
  final int srcWidth;
  final int srcHeight;

  TextBlockPainter(this.blocks, this.srcWidth, this.srcHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = AppTheme.successColor;

    final scaleX = size.width / srcWidth;
    final scaleY = size.height / srcHeight;

    for (final block in blocks) {
      final rect = Rect.fromLTRB(
        block.boundingBox.left * scaleX,
        block.boundingBox.top * scaleY,
        block.boundingBox.right * scaleX,
        block.boundingBox.bottom * scaleY,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(TextBlockPainter oldDelegate) => true;
}