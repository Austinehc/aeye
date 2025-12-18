import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:vibration/vibration.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_service.dart';
import '../../../core/utils/audio_feedback.dart';
import '../services/ocr_service.dart';
import '../models/text_detection_result.dart';
import '../../voice/services/voice_service.dart';

class OCRScreen extends StatefulWidget {
  const OCRScreen({super.key});

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
  int? _srcW;
  int? _srcH;

  @override
  void initState() {
    super.initState();
    AudioFeedback.initialize();
    _initializeCamera();
    _initializeVoice();
    _tts.addOnStartListener(_onTtsStart);
    _tts.addOnCompleteListener(_onTtsComplete);
  }

  Future<void> _initializeVoice() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        setState(() => _statusMessage = 'Microphone permission denied');
        await _tts.speak('Microphone permission denied.');
        return;
      }
      final ok = await _voiceService.initialize();
      if (ok) _startListening();
    } catch (e) {
      debugPrint('Voice init error: $e');
    }
  }

  void _onTtsStart() {
    if (mounted) setState(() => _isListening = false);
    _voiceService.cancelListening();
  }

  void _onTtsComplete() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_isListening) _startListening();
    });
  }

  Future<void> _startListening() async {
    if (_isListening || !mounted) return;
    setState(() => _isListening = true);
    await _voiceService.startListening(
      onResult: (text) async {
        if (!mounted) return;
        setState(() => _isListening = false);
        await _handleVoiceResult(text);
      },
      onPartialResult: (_) {},
      continuous: true,
    );
  }

  Future<void> _handleVoiceResult(String text) async {
    final t = text.toLowerCase().trim();

    // Text Reader specific commands: scan, read, read again, stop, back/exit
    if (t.contains('scan')) {
      AudioFeedback.success();
      await _captureAndRecognize();
    } else if (t.contains('read again') || t.contains('again')) {
      // "read again" - re-read the last scanned text
      AudioFeedback.success();
      await _readText();
    } else if (t.contains('read')) {
      AudioFeedback.success();
      await _readText();
    } else if (t.contains('stop')) {
      AudioFeedback.success();
      if (_isReading) {
        await _tts.stop();
        setState(() => _isReading = false);
        await _tts.speak('Stopped');
      } else {
        await _tts.speak('Nothing is being read');
      }
    } else if (t.contains('back') || t.contains('exit')) {
      AudioFeedback.success();
      await _tts.speak('Going back');
      if (mounted) Navigator.pop(context);
    } else {
      // Unrecognized command - announce to user
      AudioFeedback.error();
      await _tts.speak('Unknown command. Say scan, read, read again, stop, or back.');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _statusMessage = 'No camera available');
        await _tts.speak('No camera found');
        return;
      }

      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);
      await _ocrService.initialize();

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Ready. Say scan to capture text.';
      });
      await _tts.speak('Text reader ready. Point camera at text and say scan.');
    } catch (e) {
      debugPrint('Camera init error: $e');
      setState(() => _statusMessage = 'Camera error');
      await _tts.speak('Failed to initialize camera');
    }
  }

  Future<void> _captureAndRecognize() async {
    if (!_isInitialized || _isProcessing || _cameraController == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Scanning...';
    });
    if (await Vibration.hasVibrator() == true) Vibration.vibrate(duration: 100);
    await _tts.speak('Scanning');

    try {
      final image = await _cameraController!.takePicture();

      // Get image dimensions for overlay
      try {
        final bytes = await File(image.path).readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final orientation = decoded.exif.imageIfd.orientation ?? 1;
          if (orientation >= 5 && orientation <= 8) {
            _srcW = decoded.height;
            _srcH = decoded.width;
          } else {
            _srcW = decoded.width;
            _srcH = decoded.height;
          }
        }
      } catch (_) {}

      final result = await _ocrService.recognizeText(image);

      // Clean up temp file
      File(image.path).delete().catchError((_) => File(image.path));

      setState(() {
        _detectionResult = result;
        _isProcessing = false;
        _statusMessage = result.hasText ? '${result.wordCount} words found' : 'No text detected';
      });

      await _announceResults(result);
    } catch (e) {
      debugPrint('Recognition error: $e');
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Scan failed';
      });
      await _tts.speak('Recognition failed. Please try again.');
    }
  }

  Future<void> _announceResults(TextDetectionResult result) async {
    if (!result.hasText) {
      await _tts.speak('No text detected. Try moving closer or adjusting angle.');
      return;
    }
    await _tts.speak('Found ${result.wordCount} words. Say read to hear the text.');
  }

  Future<void> _readText() async {
    if (_detectionResult == null || !_detectionResult!.hasText) {
      await _tts.speak('No text available. Say scan first.');
      return;
    }
    if (_isReading) {
      await _tts.stop();
      setState(() => _isReading = false);
      return;
    }
    setState(() => _isReading = true);
    if (await Vibration.hasVibrator() == true) Vibration.vibrate(duration: 150);

    final fullText = _detectionResult!.fullText;
    if (fullText.isNotEmpty) {
      await _tts.speak(fullText);
    }
    setState(() => _isReading = false);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _tts.stop();
    _voiceService.stopListening();
    _tts.removeOnStartListener(_onTtsStart);
    _tts.removeOnCompleteListener(_onTtsComplete);
    AudioFeedback.dispose();
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
            if (mounted) Navigator.pop(context);
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
          // Camera preview
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
                      // Text block overlay
                      if (_detectionResult != null &&
                          _detectionResult!.hasText &&
                          _srcW != null &&
                          _srcH != null)
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
                    const CircularProgressIndicator(color: AppTheme.accentColor),
                    const SizedBox(height: 20),
                    Text(_statusMessage, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ),

          // Status bar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Say "scan", "read", "read again", "stop", or "back"',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
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
                          const Icon(Icons.volume_up, size: 20, color: AppTheme.successColor)
                        else
                          const Icon(Icons.text_fields, size: 20, color: AppTheme.accentColor),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _statusMessage,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
