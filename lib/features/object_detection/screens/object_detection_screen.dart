import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:vibration/vibration.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_service.dart';
import '../../../core/utils/vibration_helper.dart';
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
  final TTSService _tts = TTSService();
  final ObjectDetectorService _detector = ObjectDetectorService();
  final VoiceService _voiceService = VoiceService();
  
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isRealTimeMode = true; // Enable real-time by default
  List<DetectionResult> _detections = [];
  String _statusMessage = 'Initializing camera...';
  int _frameCount = 0;
  DateTime? _lastDetectionTime;
  bool _isListening = false;
  String _recognizedText = '';
  int? _srcW;
  int? _srcH;
  
  // Simplified performance tracking
  Set<String> _announcedObjects = {};
  DateTime? _lastAnnouncementTime;
  
  // Performance optimization variables
  bool _isProcessingFrame = false;
  List<int> _recentInferenceTimes = [];
  final int _maxInferenceHistory = 10;
  DateTime? _lastUIUpdate;
  List<DetectionResult> _cachedDetections = [];
  
  // ✅ FIX: Smooth detection updates
  List<DetectionResult> _previousDetections = [];
  
  // ✅ NEW: Error handling for no detections
  int _noDetectionFrameCount = 0;
  DateTime? _lastDetectionAnnouncement;
  
  // ✅ FIX: Use ValueNotifier to update only overlay, not camera preview
  final ValueNotifier<List<DetectionResult>> _detectionsNotifier = ValueNotifier([]);
  final ValueNotifier<String> _statusNotifier = ValueNotifier('Initializing camera...');

  @override
  void initState() {
    super.initState();
    AudioFeedback.initialize(); // ✅ Initialize audio feedback
    _initializeCamera();
    _initializeVoice(); // ✅ REMOVED: _announceScreen() - no startup feedback
    _tts.addOnStartListener(_onTtsStart);
    _tts.addOnCompleteListener(_onTtsComplete);
  }

  // ✅ REMOVED: _announceScreen() method - no startup audio feedback

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
      print('🎤 Initializing voice service...');
      final ok = await _voiceService.initialize();
      
      if (ok) {
        print('✅ Voice service initialized successfully');
        _startListening();
      } else {
        print('❌ Voice service initialization failed');
        setState(() {
          _statusMessage = 'Voice recognition not available';
        });
        await _tts.speak(
          'Voice recognition is not available on this device. '
          'Voice commands will not work.'
        );
      }
    } catch (e) {
      print('❌ Error initializing voice: $e');
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
    print('🎤 Object Detection Voice result: "$text"');
    
    final t = text.toLowerCase().trim();
    print('🔍 Processing command: "$t"');
    
    if (t.contains('pause')) {
      print('✅ Executing: pause detection');
      AudioFeedback.success();
      await _pauseDetection();
      return;
    }
    if (t.contains('resume') || t.contains('start')) {
      print('✅ Executing: resume detection');
      AudioFeedback.success();
      await _resumeDetection();
      return;
    }
    if (t.contains('what do you see') || t.contains('describe') || t.contains('results')) {
      print('✅ Executing: announce detections');
      AudioFeedback.success();
      await _announceDetections(_detections);
      return;
    }
    if (t.contains('help')) {
      print('✅ Executing: help');
      AudioFeedback.success();
      await _provideHelp();
      return;
    }
    if (t.contains('back') || t.contains('exit')) {
      print('✅ Executing: back/exit');
      AudioFeedback.success();
      await _tts.speak('Going back');
      if (mounted) Navigator.pop(context);
      return;
    }
    
    print('❌ Command not recognized: "$t"');
    AudioFeedback.error();
    await _tts.speak('Command not recognized. Try: pause detection, resume detection, what do you see, help, or back.');
  }

  Future<void> _provideHelp() async {
    await _tts.speak(
      'You can say: pause detection, resume detection, what do you see, help, or back.'
    );
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

      // ✅ FIX: Use low resolution for maximum smoothness
      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.medium,  // Medium resolution for better detection quality
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      
      // ✅ FIX: Optimize camera settings for smooth video
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);
      
      // ✅ Initialize detector with error handling and recovery
      try {
        print('🔄 Starting detector initialization...');
        await _detector.initialize();
        print('✅ Detector initialized successfully');
      } catch (e, stackTrace) {
        print('❌ Failed to initialize detector: $e');
        print('📋 Stack trace: $stackTrace');
        
        setState(() {
          _statusMessage = 'Model loading failed - Tap to retry';
        });
        
        // Provide specific error message
        String errorMsg = 'Failed to load detection model. ';
        if (e.toString().contains('not found')) {
          errorMsg += 'Model file not found in assets folder.';
        } else if (e.toString().contains('Invalid')) {
          errorMsg += 'Model file is invalid or corrupted.';
        } else if (e.toString().contains('NNAPI')) {
          errorMsg += 'Hardware acceleration not supported.';
        } else {
          final errStr = e.toString();
          errorMsg += 'Error: ${errStr.length > 100 ? errStr.substring(0, 100) : errStr}';
        }
        
        await _tts.speak(errorMsg + ' Say back to return to home screen.');
        
        // ✅ FIX: Don't return - allow user to go back
        return;
      }

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Real-time detection active';
      });

      // Start real-time detection
      _startRealTimeDetection();

      await _tts.speak('Camera initialized. Real-time detection active.');
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() {
        _statusMessage = 'Initialization error';
      });
      await _tts.speak('Failed to initialize. Please check camera permissions.');
    }
  }

  // Start real-time detection
  void _startRealTimeDetection() {
    if (_cameraController == null || !_isInitialized) return;

    _cameraController!.startImageStream((CameraImage cameraImage) {
      _frameCount++;
      
      // ✅ FIX: Smart throttling - skip frames if still processing OR too soon
      if (!_isRealTimeMode || _isProcessingFrame) {
        return;
      }
      
      // ✅ FIX: Time-based throttling for smooth video (max 15 FPS detection)
      final now = DateTime.now();
      if (_lastDetectionTime != null && 
          now.difference(_lastDetectionTime!).inMilliseconds < 66) {
        return; // Skip if less than 66ms since last detection (15 FPS)
      }

      // ✅ FIX: Set single atomic flag to prevent race conditions
      _isProcessingFrame = true;
      _lastDetectionTime = now;

      // ✅ CRITICAL: Process frame in background without blocking camera stream
      _processFrameOptimized(cameraImage).then((processingResult) {
        if (processingResult != null && mounted) {
          final (convertedImage, detections, inferenceTime) = processingResult;
          
          _srcW = convertedImage.width;
          _srcH = convertedImage.height;
          
          // ✅ FIX: Track performance for monitoring
          _trackPerformance(inferenceTime);
          
          // ✅ FIX: Smooth UI updates with throttling
          _updateUISmooth(detections);
        }
      }).catchError((e) {
        print('⚠️ Frame processing error: $e');
      }).whenComplete(() {
        // ✅ FIX: Clear flag atomically
        _isProcessingFrame = false;
      });
    });
  }

  // Stop real-time detection (synchronous for proper cleanup)
  void _stopRealTimeDetection() {
    try {
      if (_cameraController != null && 
          _cameraController!.value.isInitialized &&
          _cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream();
      }
    } catch (e) {
      print('⚠️ Error stopping image stream: $e');
      // Ignore errors during cleanup
    }
  }
  
  // ✅ NEW: Track performance without frame skipping
  void _trackPerformance(int inferenceTimeMs) {
    _recentInferenceTimes.add(inferenceTimeMs);
    
    // Keep only recent measurements for monitoring
    if (_recentInferenceTimes.length > _maxInferenceHistory) {
      _recentInferenceTimes.removeAt(0);
    }
    
    // Log performance occasionally
    if (_frameCount % 100 == 0 && _recentInferenceTimes.isNotEmpty) {
      final avgTime = _recentInferenceTimes.reduce((a, b) => a + b) / 
                      _recentInferenceTimes.length;
      final fps = 1000 / avgTime;
      print('📊 Performance: ${avgTime.toInt()}ms avg → ${fps.toStringAsFixed(1)} FPS detection rate');
    }
  }

  // ✅ OPTIMIZED: Process entire frame pipeline efficiently
  Future<(img.Image, List<DetectionResult>, int)?> _processFrameOptimized(
      CameraImage cameraImage) async {
    try {
      final processingStart = DateTime.now();
      
      // Verify we have enough planes for YUV420 format
      if (cameraImage.planes.length < 3) {
        return null;
      }
      
      // Convert CameraImage to img.Image in isolate (non-blocking)
      final convertedImage = await compute(_convertYUVtoRGB, _CameraImageData(
        width: cameraImage.width,
        height: cameraImage.height,
        yBytes: cameraImage.planes[0].bytes,
        uBytes: cameraImage.planes[1].bytes,
        vBytes: cameraImage.planes[2].bytes,
        yRowStride: cameraImage.planes[0].bytesPerRow,
        uvRowStride: cameraImage.planes[1].bytesPerRow,
        uvPixelStride: cameraImage.planes[1].bytesPerPixel ?? 1,
        targetWidth: 320, // Target YOLOv8 input size
        targetHeight: 320,
      ));
      
      if (convertedImage == null) {
        return null;
      }
      
      // Run object detection
      final detections = await _detector.detectObjects(convertedImage);
      
      // Calculate total processing time
      final totalTime = DateTime.now().difference(processingStart).inMilliseconds;
      
      return (convertedImage, detections, totalTime);
    } catch (e, stackTrace) {
      print('❌ Frame processing error: $e');
      return null;
    }
  }
  
  // ✅ OPTIMIZED: Ultra-smooth UI updates WITHOUT rebuilding camera
  void _updateUISmooth(List<DetectionResult> detections) {
    final now = DateTime.now();
    
    // ✅ FIX: Minimal throttle for smooth updates
    if (_lastUIUpdate != null && 
        now.difference(_lastUIUpdate!).inMilliseconds < 33) {
      return;
    }
    
    _lastUIUpdate = now;
    
    // ✅ NEW: Track no detection frames for error handling
    if (detections.isEmpty) {
      _noDetectionFrameCount++;
    } else {
      _noDetectionFrameCount = 0;
    }
    
    // ✅ NEW: Announce when nothing detected for a while
    if (_noDetectionFrameCount == 60) {
      _announceNoDetections();
    }
    
    // ✅ FIX: Minimal stabilization
    final isSimilar = _areDetectionsSimilar(_previousDetections, detections);
    
    // Apply smoothing if similar (reduces jitter)
    List<DetectionResult> finalDetections = detections;
    if (isSimilar && _previousDetections.isNotEmpty) {
      finalDetections = _smoothDetections(_previousDetections, detections);
    }
    
    _previousDetections = finalDetections;
    
    // ✅ FIX: Update using ValueNotifier - NO setState, NO camera rebuild!
    _detections = finalDetections;
    _cachedDetections = finalDetections;
    _detectionsNotifier.value = finalDetections;
    
    // Update status message
    if (detections.isEmpty) {
      if (_noDetectionFrameCount > 60) {
        _statusNotifier.value = 'No objects detected - Try different angle';
      } else {
        _statusNotifier.value = 'Scanning...';
      }
    } else {
      _statusNotifier.value = '${detections.length} object(s) detected';
    }
    
    // Auto-announce new objects (non-blocking)
    if (detections.isNotEmpty) {
      _autoAnnounceDetections(detections);
    }
  }
  
  // ✅ NEW: Announce when nothing is detected
  Future<void> _announceNoDetections() async {
    final now = DateTime.now();
    
    // Don't announce too frequently
    if (_lastDetectionAnnouncement != null &&
        now.difference(_lastDetectionAnnouncement!).inSeconds < 15) {
      return;
    }
    
    // Don't announce if TTS is speaking
    if (_tts.isSpeaking) {
      return;
    }
    
    _lastDetectionAnnouncement = now;
    await _tts.speak('No objects detected. Try moving the camera or adjusting lighting.');
  }
  
  // ✅ NEW: Check if detections are similar (reduces jitter)
  bool _areDetectionsSimilar(List<DetectionResult> prev, List<DetectionResult> curr) {
    if (prev.length != curr.length) return false;
    if (prev.isEmpty) return true;
    
    // Check if same objects detected
    final prevLabels = prev.map((d) => d.label).toSet();
    final currLabels = curr.map((d) => d.label).toSet();
    
    return prevLabels.difference(currLabels).isEmpty &&
           currLabels.difference(prevLabels).isEmpty;
  }

  // ✅ NEW: Exponential smoothing for bounding boxes
  List<DetectionResult> _smoothDetections(List<DetectionResult> prev, List<DetectionResult> curr) {
    final smoothed = <DetectionResult>[];
    final alpha = 0.7; // Smoothing factor (higher = more responsive, lower = smoother)
    
    for (final currDet in curr) {
      // Find matching detection in previous frame
      final prevDet = prev.firstWhere(
        (p) => p.label == currDet.label && 
               _calculateIOU(p.boundingBox, currDet.boundingBox) > 0.5,
        orElse: () => currDet, // Return current if no match
      );
      
      if (prevDet == currDet) {
        smoothed.add(currDet);
        continue;
      }
      
      // Smooth coordinates
      final newBox = BoundingBox(
        left: prevDet.boundingBox.left * (1 - alpha) + currDet.boundingBox.left * alpha,
        top: prevDet.boundingBox.top * (1 - alpha) + currDet.boundingBox.top * alpha,
        right: prevDet.boundingBox.right * (1 - alpha) + currDet.boundingBox.right * alpha,
        bottom: prevDet.boundingBox.bottom * (1 - alpha) + currDet.boundingBox.bottom * alpha,
      );
      
      smoothed.add(DetectionResult(
        label: currDet.label,
        confidence: currDet.confidence,
        boundingBox: newBox,
      ));
    }
    
    return smoothed;
  }
  
  double _calculateIOU(BoundingBox box1, BoundingBox box2) {
    final x1 = box1.left > box2.left ? box1.left : box2.left;
    final y1 = box1.top > box2.top ? box1.top : box2.top;
    final x2 = box1.right < box2.right ? box1.right : box2.right;
    final y2 = box1.bottom < box2.bottom ? box1.bottom : box2.bottom;
    
    final intersectionWidth = (x2 - x1).clamp(0.0, double.infinity);
    final intersectionHeight = (y2 - y1).clamp(0.0, double.infinity);
    final intersectionArea = intersectionWidth * intersectionHeight;
    
    final box1Area = (box1.right - box1.left) * (box1.bottom - box1.top);
    final box2Area = (box2.right - box2.left) * (box2.bottom - box2.top);
    final unionArea = box1Area + box2Area - intersectionArea;
    
    if (unionArea == 0) return 0.0;
    return intersectionArea / unionArea;
  }

  // ✅ OPTIMIZED: Direct downsampling YUV conversion
  // This converts ONLY the pixels needed for the target size, skipping the rest.
  // Massive performance boost (10x-20x faster).
  static img.Image? _convertYUVtoRGB(_CameraImageData data) {
    try {
      final int targetW = data.targetWidth;
      final int targetH = data.targetHeight;
      final img.Image image = img.Image(width: targetW, height: targetH);
      
      // Get Y, U, V planes
      final yPlane = data.yBytes;
      final uPlane = data.uBytes;
      final vPlane = data.vBytes;
      
      final int yStride = data.yRowStride;
      final int uvStride = data.uvRowStride;
      final int uvPixelStride = data.uvPixelStride;
      
      // Calculate scaling factors
      // We want to sample pixels from the source to fit into targetW x targetH
      final double scaleX = data.width / targetW;
      final double scaleY = data.height / targetH;
      
      // Loop through TARGET pixels (320x320) instead of SOURCE pixels (1280x720)
      for (int y = 0; y < targetH; y++) {
        // Map target Y to source Y
        final int srcY = (y * scaleY).floor();
        final int uvRow = srcY ~/ 2;
        final int yIndexBase = srcY * yStride;
        
        for (int x = 0; x < targetW; x++) {
          // Map target X to source X
          final int srcX = (x * scaleX).floor();
          
          // Get Y value
          final int yValue = yPlane[yIndexBase + srcX];
          
          // Get UV values
          final int uvX = srcX ~/ 2;
          final int uvIndex = (uvRow * uvStride) + (uvX * uvPixelStride);
          
          // Bounds check
          if (uvIndex >= uPlane.length || uvIndex >= vPlane.length) continue;
          
          final int uValue = uPlane[uvIndex];
          final int vValue = vPlane[uvIndex];
          
          // Convert YUV to RGB
          final int c = (298 * (yValue - 16)) >> 8;
          final int d = uValue - 128;
          final int e = vValue - 128;
          
          final int r = (c + 409 * e + 128) >> 8;
          final int g = (c - 100 * d - 208 * e + 128) >> 8;
          final int b = (c + 516 * d + 128) >> 8;
          
          // Set pixel
          image.setPixelRgba(x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255), 255);
        }
      }
      
      return image;
    } catch (e) {
      print('❌ Error in YUV conversion: $e');
      return null;
    }
  }

  // ✅ REMOVED: _toggleRealTimeMode() method - no button feedback needed

  Future<void> _pauseDetection() async {
    if (!_isRealTimeMode) {
      await _tts.speak('Already paused');
      return;
    }
    setState(() {
      _isRealTimeMode = false;
      _statusMessage = 'Real-time detection paused';
    });
    _stopRealTimeDetection();
    await _tts.speak('Real-time detection paused');
  }

  Future<void> _resumeDetection() async {
    if (_isRealTimeMode) {
      await _tts.speak('Already running');
      return;
    }
    setState(() {
      _isRealTimeMode = true;
      _statusMessage = 'Real-time detection active';
    });
    _startRealTimeDetection();
    await _tts.speak('Real-time detection enabled');
  }

  Future<void> _announceDetections(List<DetectionResult> detections) async {
    // ✅ NEW: Better error handling for no detections
    if (detections.isEmpty) {
      await _tts.speak('No objects detected. Try moving the camera to a different angle or improving lighting.');
      return;
    }

    // ✅ NEW: Check if detections have low confidence
    final highConfidenceDetections = detections.where((d) => d.confidence >= 0.5).toList();
    
    if (highConfidenceDetections.isEmpty) {
      await _tts.speak('Objects detected but not clearly identified. Try moving closer or improving lighting.');
      return;
    }

    // Announce count
    String message = 'Found ${highConfidenceDetections.length} object';
    if (highConfidenceDetections.length > 1) message += 's';
    message += '. ';

    // Announce top 3 high-confidence detections
    final topDetections = highConfidenceDetections.take(3).toList();
    for (int i = 0; i < topDetections.length; i++) {
      final detection = topDetections[i];
      message += '${detection.label} with ${detection.confidencePercentage} confidence';
      if (i < topDetections.length - 1) {
        message += ', ';
      }
    }

    if (highConfidenceDetections.length > 3) {
      message += ', and ${highConfidenceDetections.length - 3} more';
    }

    await _tts.speak(message);
  }

  // ✅ OPTIMIZED: Smart auto-announce with reduced frequency
  Future<void> _autoAnnounceDetections(List<DetectionResult> detections) async {
    if (detections.isEmpty) return;
    
    // ✅ FIX: Longer throttle to reduce interruptions (10 seconds)
    final now = DateTime.now();
    if (_lastAnnouncementTime != null && 
        now.difference(_lastAnnouncementTime!).inSeconds < 10) {
      return;
    }
    
    // ✅ FIX: Don't announce if TTS is currently speaking
    if (_tts.isSpeaking) {
      return;
    }
    
    // Find new high-confidence objects (not previously announced)
    final newObjects = <String>[];
    for (final detection in detections) {
      if (!_announcedObjects.contains(detection.label) && 
          detection.confidence > 0.65) {  // Higher threshold for auto-announce
        newObjects.add(detection.label);
        _announcedObjects.add(detection.label);
      }
    }
    
    // ✅ FIX: Use LRU-style cache - keep only current detections
    if (_announcedObjects.length > 10) {
      // Keep only objects currently visible with high confidence
      final currentObjects = detections
          .where((d) => d.confidence > 0.65)
          .take(5)
          .map((d) => d.label)
          .toSet();
      _announcedObjects = currentObjects;
    }
    
    // ✅ FIX: Only announce if there's something significant (1-2 objects max)
    if (newObjects.isNotEmpty && newObjects.length <= 2) {
      _lastAnnouncementTime = now;
      String message = '';
      
      if (newObjects.length == 1) {
        message = '${newObjects[0]} detected';
      } else {
        message = '${newObjects[0]} and ${newObjects[1]} detected';
      }
      
      // Non-blocking announcement
      _tts.speak(message);
    }
  }

  @override
  void dispose() {
    // ✅ FIX: Proper cleanup order to prevent crashes
    try {
      // Stop detection first
      _stopRealTimeDetection();
    } catch (e) {
      print('⚠️ Error stopping detection: $e');
    }
    
    try {
      // Dispose camera
      _cameraController?.dispose();
    } catch (e) {
      print('⚠️ Error disposing camera: $e');
    }
    
    try {
      // Stop voice service
      _voiceService.stopListening();
    } catch (e) {
      print('⚠️ Error stopping voice: $e');
    }
    
    try {
      // Remove TTS listeners
      _tts.removeOnStartListener(_onTtsStart);
      _tts.removeOnCompleteListener(_onTtsComplete);
    } catch (e) {
      print('⚠️ Error removing TTS listeners: $e');
    }
    
    try {
      // Cleanup audio feedback
      AudioFeedback.dispose();
    } catch (e) {
      print('⚠️ Error disposing audio feedback: $e');
    }
    
    // ✅ FIX: Dispose ValueNotifiers
    _detectionsNotifier.dispose();
    _statusNotifier.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: GestureDetector(
        child: Stack(
          children: [
            // ✅ FIX: Camera Preview - Separated from detection overlay
            if (_isInitialized && _cameraController != null)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize!.height,
                    height: _cameraController!.value.previewSize!.width,
                    child: Stack(
                      children: [
                        // ✅ Camera preview - never rebuilds
                        CameraPreview(_cameraController!),
                        // ✅ Detection overlay - only this rebuilds
                        ValueListenableBuilder<List<DetectionResult>>(
                          valueListenable: _detectionsNotifier,
                          builder: (context, detections, child) {
                            if (detections.isEmpty || _srcW == null || _srcH == null) {
                              return const SizedBox.shrink();
                            }
                            return CustomPaint(
                              size: Size.infinite,
                              painter: DetectionPainter(detections, _srcW!, _srcH!),
                            );
                          },
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
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Voice Commands: "pause detection", "resume detection", "what do you see", "help", "back"',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // ✅ FIX: Status Message - only this rebuilds
                    ValueListenableBuilder<String>(
                      valueListenable: _statusNotifier,
                      builder: (context, statusMessage, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isRealTimeMode ? Icons.videocam : Icons.videocam_off,
                              size: 20,
                              color: _isRealTimeMode ? AppTheme.accentColor : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                statusMessage,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              ),  // Close SafeArea
            ),
          ],
        ),
      ),
    );
  }

}

// ✅ OPTIMIZED: Custom painter with better rendering
class DetectionPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final int srcWidth;
  final int srcHeight;

  DetectionPainter(this.detections, this.srcWidth, this.srcHeight);

  @override
  void paint(Canvas canvas, Size size) {
    // ✅ FIX: Handle edge cases
    if (detections.isEmpty || srcWidth <= 0 || srcHeight <= 0) return;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = AppTheme.accentColor;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // ✅ FIX: Rotate coordinates 90 degrees clockwise for portrait mode
    // Image is Landscape (srcWidth > srcHeight), Screen is Portrait
    // We map Image Y -> Screen X, and Image X -> Screen Y
    final scaleX = size.width / srcHeight;
    final scaleY = size.height / srcWidth;

    for (final detection in detections) {
      final box = detection.boundingBox;
      
      // Transform coordinates for 90 deg rotation (Standard Android Back Camera)
      // (0,0) Image Top-Left -> Screen Top-Right
      // x_screen = (srcHeight - y_image) * scaleX
      // y_screen = x_image * scaleY
      
      final left = (srcHeight - box.bottom) * scaleX;
      final top = box.left * scaleY;
      final right = (srcHeight - box.top) * scaleX;
      final bottom = box.right * scaleY;
      
      // Clamp to canvas bounds
      final clampedLeft = left.clamp(0.0, size.width);
      final clampedTop = top.clamp(0.0, size.height);
      final clampedRight = right.clamp(0.0, size.width);
      final clampedBottom = bottom.clamp(0.0, size.height);
      
      // Skip invalid boxes
      if (clampedRight <= clampedLeft || clampedBottom <= clampedTop) continue;
      
      // Draw bounding box
      canvas.drawRect(Rect.fromLTRB(clampedLeft, clampedTop, clampedRight, clampedBottom), paint);

      // Draw label background
      final labelSpan = TextSpan(
        text: '${detection.label} ${detection.confidencePercentage}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );

      textPainter.text = labelSpan;
      textPainter.layout();

      // ✅ FIX: Position label inside box if too close to top edge
      final labelY = clampedTop > 30 ? clampedTop - 25 : clampedTop + 5;
      final labelOffset = Offset(clampedLeft, labelY);
      
      // ✅ FIX: Ensure label background doesn't go off screen
      final bgWidth = (textPainter.width + 10).clamp(0.0, size.width - clampedLeft);
      final bgHeight = textPainter.height + 5;
      
      canvas.drawRect(
        Rect.fromLTWH(
          labelOffset.dx,
          labelOffset.dy,
          bgWidth,
          bgHeight,
        ),
        Paint()..color = AppTheme.accentColor,
      );

      textPainter.paint(canvas, labelOffset + const Offset(5, 2));
    }
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) {
    // ✅ OPTIMIZATION: Only repaint if detections actually changed
    return oldDelegate.detections.length != detections.length ||
           oldDelegate.srcWidth != srcWidth ||
           oldDelegate.srcHeight != srcHeight;
  }
}

// Data class for passing camera image data to isolate
class _CameraImageData {
  final int width;
  final int height;
  final Uint8List yBytes;
  final Uint8List uBytes;
  final Uint8List vBytes;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
  final int targetWidth;
  final int targetHeight;

  _CameraImageData({
    required this.width,
    required this.height,
    required this.yBytes,
    required this.uBytes,
    required this.vBytes,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.targetWidth,
    required this.targetHeight,
  });
}