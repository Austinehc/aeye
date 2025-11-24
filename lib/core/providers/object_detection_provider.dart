import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../../features/object_detection/models/detection_result.dart';
import '../../features/object_detection/services/object_detector_service.dart';

/// Object detection state provider
class ObjectDetectionProvider extends ChangeNotifier {
  final ObjectDetectorService _detector = ObjectDetectorService();

  List<DetectionResult> _detections = [];
  bool _isInitialized = false;
  bool _isDetecting = false;
  bool _isRealTimeMode = false;
  String _statusMessage = 'Initializing...';
  String? _error;

  // Getters
  List<DetectionResult> get detections => List.unmodifiable(_detections);
  bool get isInitialized => _isInitialized;
  bool get isDetecting => _isDetecting;
  bool get isRealTimeMode => _isRealTimeMode;
  String get statusMessage => _statusMessage;
  String? get error => _error;

  /// Initialize detector
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _setStatus('Initializing object detector...');
      await _detector.initialize();
      _isInitialized = true;
      _setStatus('Ready');
      _setError(null);
    } catch (e) {
      _setError('Failed to initialize: $e');
      _setStatus('Initialization failed');
      rethrow;
    }
  }

  /// Detect objects in image
  Future<void> detectObjects(img.Image image) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isDetecting) return;

    _isDetecting = true;
    notifyListeners();

    try {
      final results = await _detector.detectObjects(image);
      _detections = results;
      _setStatus(results.isEmpty
          ? 'No objects detected'
          : '${results.length} object(s) detected');
      _setError(null);
    } catch (e) {
      _setError('Detection failed: $e');
      _detections = [];
    } finally {
      _isDetecting = false;
      notifyListeners();
    }
  }

  /// Toggle real-time mode
  void toggleRealTimeMode() {
    _isRealTimeMode = !_isRealTimeMode;
    _setStatus(_isRealTimeMode ? 'Scanning...' : 'Paused');
  }

  /// Clear detections
  void clearDetections() {
    _detections = [];
    _setStatus('Ready');
    notifyListeners();
  }

  /// Dispose resources
  @override
  void dispose() {
    _detector.dispose();
    super.dispose();
  }

  // Private helpers
  void _setStatus(String status) {
    _statusMessage = status;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
  }
}
