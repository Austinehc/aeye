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
  const ObjectDetectionScreen({Key? key}) : super(key: key);

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  // Services
  final _tts = TTSService();
  final _detector = ObjectDetectorService();
  final _voice = VoiceService();

  // Camera
  CameraController? _camera;
  bool _isInitialized = false;

  // Detection state
  bool _isProcessing = false;
  List<DetectionResult> _results = [];
  String _statusMessage = 'Initializing camera...';
  int? _imageWidth;
  int? _imageHeight;

  // Voice
  bool _isListening = false;
  
  // Detection loop control
  bool _detectionActive = false;

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
          _statusMessage = 'Ready. Say "scan" or tap to detect objects';
        });

        await _tts.speak('Camera ready. Say scan to detect objects.');
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
      if (ok) {
        _startListening();
      }

      // Pause listening when TTS starts speaking
      _tts.addOnStartListener(_onTtsStart);
      // Resume listening when TTS finishes
      _tts.addOnCompleteListener(_onTtsComplete);
    } catch (e) {
      debugPrint('Voice init error: $e');
    }
  }

  void _onTtsStart() {
    if (mounted) {
      setState(() => _isListening = false);
    }
    _voice.cancelListening();
  }

  void _onTtsComplete() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_isListening) {
        _startListening();
      }
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
        // Restart listening after command processed
        if (mounted && !_isListening) {
          _startListening();
        }
      },
      onPartialResult: (_) {},
      continuous: false, // We handle restart ourselves
    );
  }

  Future<void> _handleVoiceCommand(String text) async {
    final cmd = text.toLowerCase();

    if (cmd.contains('start') || cmd.contains('scan') || cmd.contains('detect') || cmd.contains('begin')) {
      AudioFeedback.success();
      _detectionActive = true;
      await _captureAndDetect();
    } else if (cmd.contains('stop') || cmd.contains('pause')) {
      AudioFeedback.success();
      _detectionActive = false;
      setState(() => _statusMessage = 'Detection paused. Say start to resume.');
      await _tts.speak('Detection paused. Say start to resume.');
    } else if (cmd.contains('what') || cmd.contains('see')) {
      AudioFeedback.success();
      await _announceCurrentResults();
    } else if (cmd.contains('help')) {
      AudioFeedback.success();
      await _tts.speak(
        'Say start to begin detection, stop to pause, what do you see for results, or back to go back.',
      );
    } else if (cmd.contains('back') || cmd.contains('exit')) {
      AudioFeedback.success();
      _detectionActive = false;
      await _tts.speak('Going back');
      if (mounted) Navigator.pop(context);
    } else {
      AudioFeedback.error();
      await _tts.speak('Command not recognized. Say help for options.');
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
      // Capture image
      final xFile = await _camera!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('Failed to decode image');
      }

      _imageWidth = decoded.width;
      _imageHeight = decoded.height;

      // Resize for model
      final resized = img.copyResize(decoded, width: 320, height: 320);

      // Run detection
      final results = await _detector.detectObjects(resized);

      // Clean up temp file
      File(xFile.path).delete().catchError((_) {});

      // Update state
      setState(() {
        _results = results;
        _isProcessing = false;
      });

      // Announce results with error handling
      await _announceResults(results);
    } catch (e) {
      debugPrint('Detection error: $e');
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Detection failed';
        _results = [];
      });

      // Error handling with helpful message
      String errorMessage = 'Detection failed. ';
      if (e.toString().contains('model') || e.toString().contains('interpreter')) {
        errorMessage += 'The detection model may not be loaded properly. Try restarting the app.';
      } else if (e.toString().contains('camera') || e.toString().contains('image')) {
        errorMessage += 'Could not capture image. Please try again.';
      } else {
        errorMessage += 'Please try again or check lighting conditions.';
      }

      await _tts.speak(errorMessage);
    }
  }

  Future<void> _announceResults(List<DetectionResult> results) async {
    // Reset detection active - user must initiate next scan
    _detectionActive = false;
    
    if (results.isEmpty) {
      setState(() => _statusMessage = 'No objects detected. Say scan to try again.');
      await _tts.speak('No objects detected. Say scan to try again.');
      return;
    }

    // Filter high confidence results
    final confident = results.where((r) => r.confidence > 0.5).toList();

    if (confident.isEmpty) {
      setState(() => _statusMessage = 'Objects unclear. Say scan to try again.');
      await _tts.speak('Objects unclear. Say scan to try again.');
      return;
    }

    // Build announcement
    final count = confident.length;
    final objectWord = count == 1 ? 'object' : 'objects';
    setState(() => _statusMessage = '$count $objectWord detected. Say scan for more.');

    // Get unique labels
    final labels = confident.map((r) => r.label).toSet().take(5).toList();
    final labelText = labels.join(', ');

    await _tts.speak('Found $count $objectWord: $labelText. Say scan to detect again.');
  }

  Future<void> _announceCurrentResults() async {
    if (_results.isEmpty) {
      await _tts.speak('No objects detected yet. Say scan to detect objects.');
      return;
    }

    final confident = _results.where((r) => r.confidence > 0.5).toList();
    if (confident.isEmpty) {
      await _tts.speak('No clear objects detected. Say scan to try again.');
      return;
    }

    final labels = confident.map((r) => r.label).toSet().take(5).toList();
    await _tts.speak('I see: ${labels.join(', ')}');
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
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          // Camera preview - full screen, tap to scan
          if (_isInitialized && _camera != null)
            GestureDetector(
              onTap: () async {
                if (!_isProcessing) {
                  _detectionActive = true;
                  await _captureAndDetect();
                }
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
                        // Detection boxes overlay
                        if (_results.isNotEmpty && _imageWidth != null)
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
            const Center(
              child: CircularProgressIndicator(color: AppTheme.accentColor),
            ),

          // Status bar at bottom
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
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Voice commands hint
                    Text(
                      'Tap screen or say "scan" to detect objects',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Status row
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
                        else if (_results.isNotEmpty)
                          const Icon(Icons.check_circle, color: AppTheme.successColor, size: 20)
                        else
                          const Icon(Icons.center_focus_strong, color: AppTheme.accentColor, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _statusMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // Results summary
                    if (_results.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _results
                              .where((r) => r.confidence > 0.5)
                              .map((r) => r.label)
                              .toSet()
                              .take(3)
                              .join(', '),
                          style: const TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 12,
                          ),
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
      ..color = AppTheme.successColor.withOpacity(0.8);

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

      // Draw bounding box
      canvas.drawRect(rect, boxPaint);

      // Draw label
      final label = '${det.label} ${(det.confidence * 100).toInt()}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - 18,
        textPainter.width + 8,
        18,
      );
      canvas.drawRect(labelRect, bgPaint);
      textPainter.paint(canvas, Offset(rect.left + 4, rect.top - 16));
    }
  }

  @override
  bool shouldRepaint(_DetectionPainter old) => detections != old.detections;
}
