import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../models/detection_result.dart';

/// Object detection service using YOLOv8 TFLite model
/// Handles model loading, inference, and result parsing with proper error handling
class ObjectDetectorService {
  static final ObjectDetectorService _instance = ObjectDetectorService._internal();
  factory ObjectDetectorService() => _instance;
  ObjectDetectorService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  String? _lastError;
  String _accelerator = 'none';

  // Model configuration
  List<int>? _inputShape;
  List<int>? _outputShape;
  bool _isInputCHW = false;
  bool _isOutputCHW = false;

  // Pre-allocated buffers for fast inference
  Float32List? _inputBuffer;
  Float32List? _outputBuffer;
  int _targetWidth = 320;
  int _targetHeight = 320;
  int _numAnchors = 8400;

  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  String get accelerator => _accelerator;

  /// Initialize the object detection model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Verify model file exists
      try {
        await rootBundle.load(AppConstants.objectDetectionModel);
      } catch (e) {
        throw ObjectDetectorException(
          'Model file not found: ${AppConstants.objectDetectionModel}',
          ObjectDetectorErrorType.modelNotFound,
        );
      }

      // Verify labels file exists
      try {
        await rootBundle.load(AppConstants.objectDetectionLabels);
      } catch (e) {
        throw ObjectDetectorException(
          'Labels file not found: ${AppConstants.objectDetectionLabels}',
          ObjectDetectorErrorType.labelsNotFound,
        );
      }

      // Load interpreter with best available delegate
      _interpreter = await _loadInterpreterWithBestDelegate();

      if (_interpreter == null) {
        throw ObjectDetectorException(
          'Failed to create TFLite interpreter',
          ObjectDetectorErrorType.interpreterFailed,
        );
      }

      // Get and validate tensor shapes
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;

      if (_inputShape == null || _inputShape!.length != 4) {
        throw ObjectDetectorException(
          'Invalid input tensor shape: $_inputShape',
          ObjectDetectorErrorType.invalidModel,
        );
      }

      // Determine input format (CHW vs HWC)
      _isInputCHW = _inputShape![1] == 3;
      _targetHeight = _isInputCHW ? _inputShape![2] : _inputShape![1];
      _targetWidth = _isInputCHW ? _inputShape![3] : _inputShape![2];

      // Determine output format and anchor count
      if (_outputShape != null && _outputShape!.length == 3) {
        _isOutputCHW = _outputShape![1] == 84;
        _numAnchors = _isOutputCHW ? _outputShape![2] : _outputShape![1];
      }

      // Pre-allocate buffers
      _inputBuffer = Float32List(_targetWidth * _targetHeight * 3);
      _outputBuffer = Float32List(84 * _numAnchors);

      // Load labels
      final labelsData = await rootBundle.loadString(AppConstants.objectDetectionLabels);
      _labels = labelsData.split('\n').where((l) => l.trim().isNotEmpty).toList();

      if (_labels.isEmpty) {
        throw ObjectDetectorException(
          'No labels found in labels file',
          ObjectDetectorErrorType.labelsNotFound,
        );
      }

      _isInitialized = true;
      _lastError = null;
      debugPrint('ObjectDetector initialized: $_accelerator, ${_labels.length} labels');
    } catch (e) {
      _isInitialized = false;
      _lastError = e.toString();
      _interpreter?.close();
      _interpreter = null;
      debugPrint('ObjectDetector initialization failed: $e');
      rethrow;
    }
  }

  /// Load interpreter with best available hardware acceleration
  Future<Interpreter> _loadInterpreterWithBestDelegate() async {
    // Try GPU delegate first (fastest on supported devices)
    try {
      final gpuDelegate = GpuDelegateV2();
      final options = InterpreterOptions()
        ..addDelegate(gpuDelegate)
        ..threads = 4;
      final interpreter = await Interpreter.fromAsset(
        AppConstants.objectDetectionModel,
        options: options,
      );
      _accelerator = 'GPU';
      debugPrint('Using GPU delegate for inference');
      return interpreter;
    } catch (e) {
      debugPrint('GPU delegate not available: $e');
    }

    // Try NNAPI (Android Neural Network API)
    try {
      final options = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true;
      final interpreter = await Interpreter.fromAsset(
        AppConstants.objectDetectionModel,
        options: options,
      );
      _accelerator = 'NNAPI';
      debugPrint('Using NNAPI for inference');
      return interpreter;
    } catch (e) {
      debugPrint('NNAPI not available: $e');
    }

    // Fallback to CPU with multi-threading
    try {
      final options = InterpreterOptions()..threads = 4;
      final interpreter = await Interpreter.fromAsset(
        AppConstants.objectDetectionModel,
        options: options,
      );
      _accelerator = 'CPU';
      debugPrint('Using CPU (4 threads) for inference');
      return interpreter;
    } catch (e) {
      debugPrint('CPU interpreter failed: $e');
      throw ObjectDetectorException(
        'Failed to load model with any delegate: $e',
        ObjectDetectorErrorType.interpreterFailed,
      );
    }
  }

  /// Detect objects in an image
  Future<List<DetectionResult>> detectObjects(img.Image image) async {
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        debugPrint('Auto-initialization failed: $e');
        return [];
      }
    }

    if (_interpreter == null || _inputBuffer == null || _outputBuffer == null) {
      debugPrint('Detector not properly initialized');
      return [];
    }

    try {
      // Preprocess image to buffer
      _preprocessToBuffer(image);

      // Reshape input for interpreter
      final input = _isInputCHW
          ? _inputBuffer!.buffer.asFloat32List().reshape([1, 3, _targetHeight, _targetWidth])
          : _inputBuffer!.buffer.asFloat32List().reshape([1, _targetHeight, _targetWidth, 3]);

      // Run inference
      final output = _outputBuffer!.buffer.asFloat32List().reshape([1, 84, _numAnchors]);
      _interpreter!.run(input, output);

      // Parse and return results
      return _parseResults(image.width, image.height);
    } catch (e) {
      debugPrint('Detection error: $e');
      _lastError = e.toString();
      return [];
    }
  }

  /// Preprocess image directly to flat buffer for fast inference
  void _preprocessToBuffer(img.Image image) {
    final resized = img.copyResize(image, width: _targetWidth, height: _targetHeight);
    final buffer = _inputBuffer!;

    if (_isInputCHW) {
      // CHW format: all R, then all G, then all B
      final planeSize = _targetWidth * _targetHeight;
      int idx = 0;
      for (int y = 0; y < _targetHeight; y++) {
        for (int x = 0; x < _targetWidth; x++) {
          final p = resized.getPixel(x, y);
          buffer[idx] = p.r / 255.0;
          buffer[planeSize + idx] = p.g / 255.0;
          buffer[planeSize * 2 + idx] = p.b / 255.0;
          idx++;
        }
      }
    } else {
      // HWC format: RGB interleaved
      int idx = 0;
      for (int y = 0; y < _targetHeight; y++) {
        for (int x = 0; x < _targetWidth; x++) {
          final p = resized.getPixel(x, y);
          buffer[idx++] = p.r / 255.0;
          buffer[idx++] = p.g / 255.0;
          buffer[idx++] = p.b / 255.0;
        }
      }
    }
  }

  /// Parse YOLO output to detection results
  List<DetectionResult> _parseResults(int imgWidth, int imgHeight) {
    final buffer = _outputBuffer!;
    final threshold = AppConstants.objectDetectionThreshold;
    final detections = <_Detection>[];

    for (int i = 0; i < _numAnchors; i++) {
      // Find max class score
      double maxScore = 0;
      int maxClass = 0;

      for (int c = 0; c < 80; c++) {
        final score = _isOutputCHW
            ? buffer[(4 + c) * _numAnchors + i]
            : buffer[i * 84 + 4 + c];

        if (score > maxScore) {
          maxScore = score;
          maxClass = c;
        }
      }

      // Skip low confidence detections
      if (maxScore < threshold) continue;
      if (maxClass >= _labels.length) continue;

      // Get bounding box
      final xc = _isOutputCHW ? buffer[i] : buffer[i * 84];
      final yc = _isOutputCHW ? buffer[_numAnchors + i] : buffer[i * 84 + 1];
      final w = _isOutputCHW ? buffer[_numAnchors * 2 + i] : buffer[i * 84 + 2];
      final h = _isOutputCHW ? buffer[_numAnchors * 3 + i] : buffer[i * 84 + 3];

      // Filter invalid boxes
      if (w > 0.8 || h > 0.8 || w < 0.02 || h < 0.02) continue;

      detections.add(_Detection(xc, yc, w, h, maxClass, maxScore));
    }

    // Convert to results
    final results = <DetectionResult>[];
    for (final d in detections) {
      final halfW = d.w / 2;
      final halfH = d.h / 2;

      final left = ((d.xc - halfW) * imgWidth).clamp(0.0, imgWidth.toDouble());
      final top = ((d.yc - halfH) * imgHeight).clamp(0.0, imgHeight.toDouble());
      final right = ((d.xc + halfW) * imgWidth).clamp(0.0, imgWidth.toDouble());
      final bottom = ((d.yc + halfH) * imgHeight).clamp(0.0, imgHeight.toDouble());

      if (right <= left || bottom <= top) continue;

      results.add(DetectionResult(
        label: _labels[d.classIdx],
        confidence: d.score,
        boundingBox: BoundingBox(left: left, top: top, right: right, bottom: bottom),
      ));
    }

    // Apply NMS and return top 5
    return _applyNMS(results).take(5).toList();
  }

  /// Apply Non-Maximum Suppression
  List<DetectionResult> _applyNMS(List<DetectionResult> detections, {double iouThreshold = 0.45}) {
    if (detections.isEmpty) return [];

    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final selected = <DetectionResult>[];
    final suppressed = List<bool>.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      selected.add(detections[i]);

      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        if (_iou(detections[i].boundingBox, detections[j].boundingBox) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    return selected;
  }

  /// Calculate Intersection over Union
  double _iou(BoundingBox a, BoundingBox b) {
    final x1 = a.left > b.left ? a.left : b.left;
    final y1 = a.top > b.top ? a.top : b.top;
    final x2 = a.right < b.right ? a.right : b.right;
    final y2 = a.bottom < b.bottom ? a.bottom : b.bottom;

    final iw = (x2 - x1).clamp(0.0, double.infinity);
    final ih = (y2 - y1).clamp(0.0, double.infinity);
    final intersection = iw * ih;

    final areaA = (a.right - a.left) * (a.bottom - a.top);
    final areaB = (b.right - b.left) * (b.bottom - b.top);
    final union = areaA + areaB - intersection;

    return union > 0 ? intersection / union : 0;
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    _inputBuffer = null;
    _outputBuffer = null;
    _lastError = null;
  }
}

/// Internal detection data class
class _Detection {
  final double xc, yc, w, h;
  final int classIdx;
  final double score;
  _Detection(this.xc, this.yc, this.w, this.h, this.classIdx, this.score);
}

/// Error types for object detection
enum ObjectDetectorErrorType {
  modelNotFound,
  labelsNotFound,
  interpreterFailed,
  invalidModel,
  inferenceError,
}

/// Custom exception for object detection errors
class ObjectDetectorException implements Exception {
  final String message;
  final ObjectDetectorErrorType type;

  ObjectDetectorException(this.message, this.type);

  @override
  String toString() => 'ObjectDetectorException: $message (type: $type)';
}

/// Extension to reshape Float32List
extension _Reshape on Float32List {
  List<dynamic> reshape(List<int> shape) {
    if (shape.length == 3) {
      return List.generate(shape[0], (i) =>
          List.generate(shape[1], (j) =>
              List.generate(shape[2], (k) =>
                  this[i * shape[1] * shape[2] + j * shape[2] + k])));
    } else if (shape.length == 4) {
      return List.generate(shape[0], (i) =>
          List.generate(shape[1], (j) =>
              List.generate(shape[2], (k) =>
                  List.generate(shape[3], (l) =>
                      this[i * shape[1] * shape[2] * shape[3] +
                          j * shape[2] * shape[3] +
                          k * shape[3] + l]))));
    }
    return toList();
  }
}
