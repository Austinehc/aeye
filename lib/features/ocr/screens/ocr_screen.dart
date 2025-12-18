import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:vibration/vibration.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_service.dart';
import '../services/ocr_service.dart';
import '../models/text_detection_result.dart';
import '../../voice/services/voice_service.dart';

class OCRScreen extends StatefulWidget {
  const OCRScreen({super.key});

  @override
  State<OCRScreen> createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> with WidgetsBindingObserver {
  final TTSService _tts = TTSService();
  final OCRService _ocrService = OCRService();
  final VoiceService _voiceService = VoiceService();

  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isProcessing = false;
  TextDetectionResult? _detectionResult;
  String _statusMessage = 'Initializing...';
  bool _isReading = false;
  bool _isListening = false;
  int? _srcW;
  int? _srcH;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _initializeVoice();
    _tts.addOnStartListener(_onTtsStart);
    _tts.addOnCompleteListener(_onTtsComplete);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _restartVoiceListening();
    } else if (state == AppLifecycleState.paused) {
      _voiceService.stopListening();
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _restartVoiceListening() async {
    if (!mounted) return;
    await _voiceService.stopListening();
    setState(() => _isListening = false);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted && !_tts.isSpeaking && _voiceService.isInitialized) {
      _startListening();
    }
  }

  Future<void> _initializeVoice() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isDenied) return;
      await _voiceService.initialize();
      // Note: listening will start after TTS completes via _onTtsComplete
    } catch (_) {}
  }

  void _onTtsStart() {
    _voiceService.cancelListening();
    if (mounted) setState(() => _isListening = false);
  }

  void _onTtsComplete() {
    if (mounted) _startListening();
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    if (!_voiceService.isInitialized && !await _voiceService.initialize()) return;

    try {
      await _voiceService.startListening(
        onResult: (text) async {
          if (!mounted) return;
          await _handleVoiceResult(text);
        },
        onPartialResult: (_) {},
        onListeningStateChanged: (isListening) {
          if (mounted) setState(() => _isListening = isListening);
        },
        continuous: true,
      );
    } catch (e) {
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _handleVoiceResult(String text) async {
    final t = text.toLowerCase().trim();

    if (t.contains('scan')) {
      await _captureAndRecognize();
    } else if (t.contains('read again') || t.contains('again')) {
      await _readText();
    } else if (t.contains('read')) {
      await _readText();
    } else if (t.contains('stop')) {
      if (_isReading) {
        await _tts.stop();
        setState(() => _isReading = false);
        await _tts.speak('Stopped');
      }
    } else if (t.contains('back') || t.contains('exit')) {
      await _tts.speak('Going back');
      if (mounted) Navigator.pop(context);
    } else {
      await _tts.speak('Unknown command. Say scan, read, read again, stop, or back.');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusMessage = 'No camera');
        await _tts.speak('No camera found');
        return;
      }

      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.max,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _ocrService.initialize();

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Ready to scan';
      });
      await _tts.speak('Text reader ready. Point at text and say scan.');
    } catch (e) {
      setState(() => _statusMessage = 'Camera error');
      await _tts.speak('Camera failed');
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
      try {
        await File(image.path).delete();
      } catch (_) {
        // Ignore deletion errors
      }

      setState(() {
        _detectionResult = result;
        _isProcessing = false;
        _statusMessage = result.hasText ? '${result.wordCount} words found' : 'No text found';
      });

      await _announceResults(result);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Scan failed';
      });
      await _tts.speak('Scan failed. Try again.');
    }
  }

  Future<void> _announceResults(TextDetectionResult result) async {
    if (!result.hasText) {
      await _tts.speak('No text detected. Move closer or adjust angle.');
      return;
    }
    await _tts.speak('Found ${result.wordCount} words. Say read to hear.');
  }

  Future<void> _readText() async {
    if (_detectionResult == null || !_detectionResult!.hasText) {
      await _tts.speak('No text. Say scan first.');
      return;
    }
    if (_isReading) {
      await _tts.stop();
      setState(() => _isReading = false);
      return;
    }
    setState(() => _isReading = true);
    if (await Vibration.hasVibrator() == true) Vibration.vibrate(duration: 150);

    await _tts.speak(_detectionResult!.fullText);
    setState(() => _isReading = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _tts.stop();
    _voiceService.stopListening();
    _tts.removeOnStartListener(_onTtsStart);
    _tts.removeOnCompleteListener(_onTtsComplete);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
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
              await _tts.stop();
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
                Text('Text Reader', style: Theme.of(context).textTheme.headlineSmall),
                Text('Scan documents and read aloud', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (_detectionResult?.hasText == true)
            GestureDetector(
              onTap: _readText,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isReading
                      ? AppTheme.successColor.withValues(alpha: 0.2)
                      : AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isReading ? Icons.stop_rounded : Icons.volume_up_rounded,
                  color: _isReading ? AppTheme.successColor : AppTheme.textColor,
                  size: 24,
                ),
              ),
            ),
          if (_isListening) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.mic_rounded, color: AppTheme.successColor, size: 24),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (!_isInitialized || _cameraController == null) {
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
        if (!_isProcessing) await _captureAndRecognize();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
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
                    width: _cameraController!.value.previewSize!.height,
                    height: _cameraController!.value.previewSize!.width,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
              if (_detectionResult?.hasText == true && _srcW != null && _srcH != null)
                CustomPaint(
                  size: Size.infinite,
                  painter: _TextBlockPainter(_detectionResult!.blocks, _srcW!, _srcH!),
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
    final hasText = _detectionResult?.hasText == true;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: hasText
                  ? AppTheme.successColor.withValues(alpha: 0.15)
                  : _isReading
                      ? AppTheme.accentColor.withValues(alpha: 0.15)
                      : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasText
                    ? AppTheme.successColor.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isProcessing
                      ? Icons.hourglass_top_rounded
                      : _isReading
                          ? Icons.volume_up_rounded
                          : hasText
                              ? Icons.check_circle_rounded
                              : Icons.document_scanner_rounded,
                  color: hasText
                      ? AppTheme.successColor
                      : _isReading
                          ? AppTheme.accentColor
                          : AppTheme.accentColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isReading ? 'Reading...' : _statusMessage,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: hasText ? AppTheme.successColor : AppTheme.textColor,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Hint
          Text(
            'Say "scan", "read", or "back" • Tap to scan',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TextBlockPainter extends CustomPainter {
  final List<TextBlockResult> blocks;
  final int srcWidth;
  final int srcHeight;

  _TextBlockPainter(this.blocks, this.srcWidth, this.srcHeight);

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
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TextBlockPainter oldDelegate) {
    return blocks != oldDelegate.blocks ||
        srcWidth != oldDelegate.srcWidth ||
        srcHeight != oldDelegate.srcHeight;
  }
}
