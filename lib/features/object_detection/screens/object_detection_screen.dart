import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_service.dart';
import '../../../core/utils/audio_feedback.dart';
import '../services/object_detector_service.dart';
import '../models/detection_result.dart';
import '../../voice/services/voice_service.dart';

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  final _tts = TTSService();
  final _detector = ObjectDetectorService();
  final _voice = VoiceService();

  CameraController? _camera;
  bool _isInitialized = false;
  bool _isProcessing = false;
  List<DetectionResult> _results = [];
  String _statusMessage = 'Initializing camera...';
  int? _imageWidth;
  int? _imageHeight;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    AudioFeedback.initialize();
    _initialize();
  }

  Future<void> _initialize() async {
    await _initCamera();
    await _initDetector();
    await _initVoice();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusMessage = 'No camera available');
        await _tts.speak('No camera found on this device');
        return;
      }

      _camera = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _camera!.initialize();
      await _camera!.setFocusMode(FocusMode.auto);
      await _camera!.setExposureMode(ExposureMode.auto);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Ready. Say "scan" to detect objects.';
        });
        await _tts.speak('Object detection ready. Say scan to detect, or back to exit.');
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      setState(() => _statusMessage = 'Camera error');
      await _tts.speak('Failed to initialize camera');
    }
  }

  Future<void> _initDetector() async {
    try {
      await _detector.initialize();
    } catch (e) {
      debugPrint('Detector init error: $e');
      setState(() => _statusMessage = 'Detection model failed to load');
      await _tts.speak('Object detection model failed to load. Please restart the app.');
    }
  }

  Future<void> _initVoice() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        await _tts.speak('Microphone permission denied. Voice commands unavailable.');
        return;
      }

      final ok = await _voice.initialize();
      if (ok) _startListening();

      _tts.addOnStartListener(_onTtsStart);
      _tts.addOnCompleteListener(_onTtsComplete);
    } catch (e) {
      debugPrint('Voice init error: $e');
    }
  }

  void _onTtsStart() {
    if (mounted) setState(() => _isListening = false);
    _voice.cancelListening();
  }

  void _onTtsComplete() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_isListening) _startListening();
    });
  }

  Future<void> _startListening() async {
    if (_isListening || !mounted) return;
    setState(() => _isListening = true);

    await _voice.startListening(
      onResult: (text) async {
        if (!mounted) return;
        setState(() => _isListening = false);
        await _handleVoiceCommand(text);
      },
      onPartialResult: (_) {},
      continuous: true,
    );
  }

  Future<void> _handleVoiceCommand(String text) async {
    final cmd = text.toLowerCase().trim();

    // Object Detection commands: scan, back/exit
    if (cmd.contains('scan')) {
      AudioFeedback.success();
      await _captureAndDetect();
    } else if (cmd.contains('back') || cmd.contains('exit')) {
      AudioFeedback.success();
      await _tts.speak('Going back');
      if (mounted) Navigator.pop(context);
    } else {
      AudioFeedback.error();
      await _tts.speak('Unknown command. Say scan or back.');
    }
  }

  Future<void> _captureAndDetect() async {
    if (!_isInitialized || _isProcessing || _camera == null) {
      await _tts.speak('Camera not ready. Please wait.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Scanning...';
      _results = [];
    });

    await _tts.speak('Scanning');

    try {
      final xFile = await _camera!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('Failed to decode image');
      }

      _imageWidth = decoded.width;
      _imageHeight = decoded.height;

      final resized = img.copyResize(decoded, width: 320, height: 320);
      final results = await _detector.detectObjects(resized);

      // Clean up temp file
      File(xFile.path).delete().catchError((_) => File(xFile.path));

      setState(() {
        _results = results;
        _isProcessing = false;
      });

      await _announceResults(results);
    } catch (e) {
      debugPrint('Detection error: $e');
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Detection failed';
        _results = [];
      });
      await _tts.speak('Detection failed. Please try again.');
    }
  }

  Future<void> _announceResults(List<DetectionResult> results) async {
    if (results.isEmpty) {
      setState(() => _statusMessage = 'No objects detected');
      await _tts.speak('No objects detected.');
      return;
    }

    final confident = results.where((r) => r.confidence > 0.5).toList();

    if (confident.isEmpty) {
      setState(() => _statusMessage = 'Objects unclear');
      await _tts.speak('Objects unclear. Try again.');
      return;
    }

    final count = confident.length;
    final objectWord = count == 1 ? 'object' : 'objects';
    final labels = confident.map((r) => r.label).toSet().take(5).toList();
    final labelText = labels.join(', ');

    setState(() => _statusMessage = '$count $objectWord: ${labels.take(3).join(", ")}');
    await _tts.speak('Found $count $objectWord: $labelText.');
  }

  @override
  void dispose() {
    _tts.removeOnStartListener(_onTtsStart);
    _tts.removeOnCompleteListener(_onTtsComplete);
    _voice.stopListening();
    _camera?.dispose();
    AudioFeedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Object Detection'),
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          iconSize: 35,
          onPressed: () async {
            await _tts.speak('Going back');
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          // Camera preview
          if (_isInitialized && _camera != null)
            GestureDetector(
              onTap: () async {
                if (!_isProcessing) await _captureAndDetect();
              },
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _camera!.value.previewSize!.height,
                    height: _camera!.value.previewSize!.width,
                    child: Stack(
                      children: [
                        CameraPreview(_camera!),
                        if (_results.isNotEmpty && _imageWidth != null && _imageHeight != null)
                          CustomPaint(
                            size: Size.infinite,
                            painter: _DetectionPainter(_results, _imageWidth!, _imageHeight!),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: AppTheme.accentColor)),

          // Status bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      'Say "scan" or "back". Tap screen to scan.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isProcessing)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: AppTheme.accentColor, strokeWidth: 2),
                          )
                        else if (_results.isNotEmpty)
                          const Icon(Icons.check_circle, color: AppTheme.successColor, size: 20)
                        else
                          const Icon(Icons.center_focus_strong, color: AppTheme.accentColor, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _statusMessage,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (_results.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _results.where((r) => r.confidence > 0.5).map((r) => r.label).toSet().take(3).join(', '),
                          style: const TextStyle(color: AppTheme.accentColor, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
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

class _DetectionPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final int imageWidth;
  final int imageHeight;

  _DetectionPainter(this.detections, this.imageWidth, this.imageHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppTheme.successColor;

    final bgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppTheme.successColor.withValues(alpha: 0.8);

    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    for (final det in detections) {
      if (det.confidence < 0.5) continue;

      final box = det.boundingBox;
      final rect = Rect.fromLTRB(
        box.left * scaleX,
        box.top * scaleY,
        box.right * scaleX,
        box.bottom * scaleY,
      );

      canvas.drawRect(rect, boxPaint);

      final label = '${det.label} ${(det.confidence * 100).toInt()}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRect = Rect.fromLTWH(rect.left, rect.top - 18, textPainter.width + 8, 18);
      canvas.drawRect(labelRect, bgPaint);
      textPainter.paint(canvas, Offset(rect.left + 4, rect.top - 16));
    }
  }

  @override
  bool shouldRepaint(_DetectionPainter old) => detections != old.detections;
}
