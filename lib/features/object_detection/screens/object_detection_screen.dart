import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_service.dart';
import '../services/object_detector_service.dart';
import '../models/detection_result.dart';
import '../../voice/services/voice_service.dart';

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen>
    with WidgetsBindingObserver {
  final _tts = TTSService();
  final _detector = ObjectDetectorService();
  final _voice = VoiceService();

  CameraController? _camera;
  bool _isInitialized = false;
  bool _isProcessing = false;
  List<DetectionResult> _results = [];
  String _statusMessage = 'Initializing...';
  int? _imageWidth;
  int? _imageHeight;
  bool _isListening = false;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    _tts.addOnStartListener(_onTtsStart);
    _tts.addOnCompleteListener(_onTtsComplete);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _restartVoiceListening();
    } else if (state == AppLifecycleState.paused) {
      _voice.stopListening();
      if (mounted) setState(() => _isListening = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.removeOnStartListener(_onTtsStart);
    _tts.removeOnCompleteListener(_onTtsComplete);
    _voice.stopListening();
    _camera?.dispose();
    super.dispose();
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
        await _tts.speak('No camera found');
        return;
      }

      _camera = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _camera!.initialize();
      await _camera!.setFocusMode(FocusMode.auto);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Ready to scan';
        });
        await _tts.speak('Object detection ready. Say scan or tap screen.');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Camera error');
      await _tts.speak('Camera failed to initialize');
    }
  }

  Future<void> _initDetector() async {
    try {
      await _detector.initialize();
    } catch (e) {
      setState(() => _statusMessage = 'Model failed');
      await _tts.speak('Detection model failed. Please restart.');
    }
  }

  Future<void> _initVoice() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isDenied) return;
      await _voice.initialize();
      // Listening starts after TTS completes via _onTtsComplete
    } catch (_) {}
  }

  void _onTtsStart() {
    _voice.cancelListening();
    if (mounted) setState(() => _isListening = false);
  }

  void _onTtsComplete() {
    if (mounted && _voice.isInitialized) {
      _startListening();
    }
  }

  Future<void> _restartVoiceListening() async {
    if (!mounted) return;
    await _voice.stopListening();
    setState(() => _isListening = false);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted && !_tts.isSpeaking && _voice.isInitialized) {
      _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    if (!_voice.isInitialized && !await _voice.initialize()) return;

    setState(() => _recognizedText = '');

    try {
      await _voice.startListening(
        onResult: (text) async {
          if (!mounted) return;
          setState(() => _recognizedText = text);
          await _handleVoiceCommand(text);
        },
        onPartialResult: (text) {
          if (mounted) setState(() => _recognizedText = text);
        },
        onListeningStateChanged: (isListening) {
          if (mounted) setState(() => _isListening = isListening);
        },
        continuous: true,
      );
    } catch (e) {
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _handleVoiceCommand(String text) async {
    final cmd = text.toLowerCase().trim();

    if (cmd.contains('scan')) {
      await _captureAndDetect();
    } else if (cmd.contains('back') || cmd.contains('exit')) {
      await _tts.speak('Going back');
      if (mounted) Navigator.pop(context);
    } else if (cmd.contains('help')) {
      await _tts.speak('Say scan to detect objects, or back to return.');
    } else {
      await _tts.speak('Unknown command. Say scan or back.');
    }
  }


  Future<void> _captureAndDetect() async {
    if (!_isInitialized || _isProcessing || _camera == null) return;

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

      if (decoded == null) throw Exception('Failed to decode');

      _imageWidth = decoded.width;
      _imageHeight = decoded.height;

      final results = await _detector.detectObjects(decoded);

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
        _statusMessage = 'Scan failed';
      });
      await _tts.speak('Detection failed. Try again.');
    }
  }

  Future<void> _announceResults(List<DetectionResult> results) async {
    final confident = results.where((r) => r.confidence > 0.5).toList();

    if (confident.isEmpty) {
      setState(() => _statusMessage = 'No objects found');
      await _tts.speak('No objects detected.');
      return;
    }

    final labels = confident.map((r) => r.label).toSet().take(5).toList();
    setState(() =>
        _statusMessage = '${confident.length} objects: ${labels.take(3).join(", ")}');
    await _tts.speak('Found ${confident.length} objects: ${labels.join(", ")}.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildVoiceStatus(context),
            Expanded(child: _buildCameraView()),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              await _tts.speak('Going back');
              if (mounted) Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Object Detection',
                    style: Theme.of(context).textTheme.headlineSmall),
                Text('Say "scan" or tap to detect',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _tts.speak('Say scan to detect objects, or back to return.'),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.help_outline_rounded, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceStatus(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _isListening
            ? AppTheme.successColor.withValues(alpha: 0.15)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isListening
              ? AppTheme.successColor.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isListening
                  ? AppTheme.successColor.withValues(alpha: 0.2)
                  : AppTheme.cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
              color: _isListening ? AppTheme.successColor : AppTheme.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isListening ? 'Listening...' : 'Voice Ready',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _isListening
                            ? AppTheme.successColor
                            : AppTheme.textColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (_recognizedText.isNotEmpty)
                  Text(
                    '"$_recognizedText"',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (_isListening)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.successColor.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildCameraView() {
    if (!_isInitialized || _camera == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.accentColor),
            const SizedBox(height: 16),
            Text(_statusMessage, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        if (!_isProcessing) await _captureAndDetect();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.surfaceColor, width: 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _camera!.value.previewSize!.height,
                    height: _camera!.value.previewSize!.width,
                    child: CameraPreview(_camera!),
                  ),
                ),
              ),
              if (_results.isNotEmpty && _imageWidth != null && _imageHeight != null)
                CustomPaint(
                  size: Size.infinite,
                  painter: _DetectionPainter(_results, _imageWidth!, _imageHeight!),
                ),
              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppTheme.accentColor),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _results.isNotEmpty
              ? AppTheme.successColor.withValues(alpha: 0.15)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _results.isNotEmpty
                ? AppTheme.successColor.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isProcessing
                  ? Icons.hourglass_top_rounded
                  : _results.isNotEmpty
                      ? Icons.check_circle_rounded
                      : Icons.center_focus_strong_rounded,
              color: _results.isNotEmpty ? AppTheme.successColor : AppTheme.accentColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _statusMessage,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color:
                          _results.isNotEmpty ? AppTheme.successColor : AppTheme.textColor,
                    ),
              ),
            ),
          ],
        ),
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
      ..color = AppTheme.successColor;

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

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        boxPaint,
      );

      final label = '${det.label} ${(det.confidence * 100).toInt()}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top - 22, textPainter.width + 12, 22),
        const Radius.circular(6),
      );
      canvas.drawRRect(labelRect, bgPaint);
      textPainter.paint(canvas, Offset(rect.left + 6, rect.top - 19));
    }
  }

  @override
  bool shouldRepaint(_DetectionPainter old) => detections != old.detections;
}
