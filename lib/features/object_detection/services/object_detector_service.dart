import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../models/detection_result.dart';

/// Object detection service using YOLOv8 TFLite model
class ObjectDetectorService {
  static final ObjectDetectorService _instance = ObjectDetectorService._internal();
  factory ObjectDetectorService() => _instance;
  ObjectDetectorService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  String? _lastError;

  // Model dimensions (will be updated from tensor shape)
  int _inputHeight = 640;
  int _inputWidth = 640;

  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  /// Initialize the object detection model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🚀 Initializing ObjectDetector...');
      
      // Load model with options
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        AppConstants.objectDetectionModel,
        options: options,
      );

      // Log tensor info
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      
      debugPrint('📐 Input tensors: ${inputTensors.length}');
      for (var t in inputTensors) {
        debugPrint('   - ${t.name}: ${t.shape} ${t.type}');
      }
      debugPrint('📐 Output tensors: ${outputTensors.length}');
      for (var t in outputTensors) {
        debugPrint('   - ${t.name}: ${t.shape} ${t.type}');
      }

      // Get input dimensions from tensor shape [1, H, W, 3] or [1, 3, H, W]
      final inputShape = inputTensors[0].shape;
      if (inputShape[1] == 3) {
        _inputHeight = inputShape[2];
        _inputWidth = inputShape[3];
      } else {
        _inputHeight = inputShape[1];
        _inputWidth = inputShape[2];
      }
      debugPrint('📐 Input size: ${_inputWidth}x$_inputHeight');

      // Load labels
      final labelsData = await rootBundle.loadString(AppConstants.objectDetectionLabels);
      _labels = labelsData.split('\n').where((l) => l.trim().isNotEmpty).toList();
      debugPrint('📝 Loaded ${_labels.length} labels');

      // Allocate tensors
      _interpreter!.allocateTensors();

      _isInitialized = true;
      _lastError = null;
      debugPrint('✅ ObjectDetector ready');
    } catch (e, st) {
      _isInitialized = false;
      _lastError = e.toString();
      debugPrint('❌ ObjectDetector init failed: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Detect objects in an image
  Future<List<DetectionResult>> detectObjects(img.Image image) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_interpreter == null) {
      debugPrint('❌ Interpreter is null');
      return [];
    }

    try {
      // Get tensor info
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      final inputShape = inputTensor.shape;
      final outputShape = outputTensor.shape;

      // Resize image to model input size
      final resized = img.copyResize(image, width: _inputWidth, height: _inputHeight);
      
      // Prepare input based on tensor type
      final inputType = inputTensor.type;
      
      Object inputData;
      if (inputType == TensorType.float32) {
        inputData = _prepareFloat32Input(resized, inputShape);
      } else if (inputType == TensorType.uint8) {
        inputData = _prepareUint8Input(resized, inputShape);
      } else {
        debugPrint('❌ Unsupported input type: $inputType');
        return [];
      }

      // Prepare output buffer - use simple nested List<double> which tflite_flutter expects
      final outputType = outputTensor.type;
      
      // Output shape [1, 84, 8400] - create nested list of doubles
      final outputData = List.generate(
        outputShape[0],  // 1
        (_) => List.generate(
          outputShape[1],  // 84
          (_) => List.filled(outputShape[2], 0.0),  // 8400
        ),
      );

      // Run inference
      _interpreter!.run(inputData, outputData);

      // Parse results
      final results = _parseYoloOutputDouble(outputData[0], outputShape, image.width, image.height);
      
      return results;
    } catch (e, st) {
      debugPrint('❌ Detection error: $e');
      debugPrint('$st');
      _lastError = e.toString();
      return [];
    }
  }

  /// Prepare float32 input tensor
  List<List<List<List<double>>>> _prepareFloat32Input(img.Image image, List<int> shape) {
    final isNCHW = shape[1] == 3;
    
    if (isNCHW) {
      // [1, 3, H, W] format
      return [
        List.generate(3, (c) =>
          List.generate(_inputHeight, (y) =>
            List.generate(_inputWidth, (x) {
              final pixel = image.getPixel(x, y);
              switch (c) {
                case 0: return pixel.r / 255.0;
                case 1: return pixel.g / 255.0;
                case 2: return pixel.b / 255.0;
                default: return 0.0;
              }
            }),
          ),
        ),
      ];
    } else {
      // [1, H, W, 3] format
      return [
        List.generate(_inputHeight, (y) =>
          List.generate(_inputWidth, (x) {
            final pixel = image.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          }),
        ),
      ];
    }
  }

  /// Prepare uint8 input tensor
  List<List<List<List<int>>>> _prepareUint8Input(img.Image image, List<int> shape) {
    final isNCHW = shape[1] == 3;
    
    if (isNCHW) {
      return [
        List.generate(3, (c) =>
          List.generate(_inputHeight, (y) =>
            List.generate(_inputWidth, (x) {
              final pixel = image.getPixel(x, y);
              switch (c) {
                case 0: return pixel.r.toInt();
                case 1: return pixel.g.toInt();
                case 2: return pixel.b.toInt();
                default: return 0;
              }
            }),
          ),
        ),
      ];
    } else {
      return [
        List.generate(_inputHeight, (y) =>
          List.generate(_inputWidth, (x) {
            final pixel = image.getPixel(x, y);
            return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
          }),
        ),
      ];
    }
  }

  /// Parse YOLOv8 output format [84, 8400]
  /// Row 0-3: x_center, y_center, width, height
  /// Row 4-83: class probabilities
  List<DetectionResult> _parseYoloOutputDouble(
    List<List<double>> output,
    List<int> shape,
    int imgWidth,
    int imgHeight,
  ) {
    final detections = <DetectionResult>[];
    final threshold = AppConstants.objectDetectionThreshold;
    
    final numRows = shape[1];  // 84
    final numCols = shape[2];  // 8400
    

    
    double maxConfidence = 0;
    int aboveThreshold = 0;

    for (int i = 0; i < numCols; i++) {
      // Get bounding box (in pixels relative to input size)
      final xc = output[0][i];
      final yc = output[1][i];
      final w = output[2][i];
      final h = output[3][i];

      // Find best class (rows 4-83)
      double bestConf = 0;
      int bestClass = 0;
      for (int c = 0; c < 80 && (4 + c) < numRows; c++) {
        final conf = output[4 + c][i];
        if (conf > bestConf) {
          bestConf = conf;
          bestClass = c;
        }
      }
      
      if (bestConf > maxConfidence) maxConfidence = bestConf;
      if (bestConf < threshold) continue;
      aboveThreshold++;

      // YOLOv8 outputs are ALREADY normalized 0-1 (not pixel coordinates)
      // xc, yc = center, w, h = width/height as fractions of image
      final ncx = xc;
      final ncy = yc;
      final nw = w;
      final nh = h;

      // Skip invalid boxes (very small or very large)
      if (nw <= 0.01 || nh <= 0.01) continue;
      if (nw > 1.0 || nh > 1.0) continue;

      // Convert to image coordinates
      final left = ((ncx - nw / 2) * imgWidth).clamp(0.0, imgWidth.toDouble());
      final top = ((ncy - nh / 2) * imgHeight).clamp(0.0, imgHeight.toDouble());
      final right = ((ncx + nw / 2) * imgWidth).clamp(0.0, imgWidth.toDouble());
      final bottom = ((ncy + nh / 2) * imgHeight).clamp(0.0, imgHeight.toDouble());

      if (right <= left || bottom <= top) {
        if (aboveThreshold <= 3) debugPrint('      ❌ Skipped: invalid rect');
        continue;
      }

      final label = bestClass < _labels.length ? _labels[bestClass] : 'object';
      
      detections.add(DetectionResult(
        label: label,
        confidence: bestConf,
        boundingBox: BoundingBox(left: left, top: top, right: right, bottom: bottom),
      ));
    }



    // Apply NMS and return top results
    return _applyNMS(detections).take(5).toList();
  }

  /// Non-Maximum Suppression
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

  double _iou(BoundingBox a, BoundingBox b) {
    final x1 = math.max(a.left, b.left);
    final y1 = math.max(a.top, b.top);
    final x2 = math.min(a.right, b.right);
    final y2 = math.min(a.bottom, b.bottom);

    final intersection = math.max(0.0, x2 - x1) * math.max(0.0, y2 - y1);
    final areaA = (a.right - a.left) * (a.bottom - a.top);
    final areaB = (b.right - b.left) * (b.bottom - b.top);
    final union = areaA + areaB - intersection;

    return union > 0 ? intersection / union : 0;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

class ObjectDetectorException implements Exception {
  final String message;
  final ObjectDetectorErrorType type;
  ObjectDetectorException(this.message, this.type);
  @override
  String toString() => 'ObjectDetectorException: $message';
}

enum ObjectDetectorErrorType {
  modelNotFound,
  labelsNotFound,
  interpreterFailed,
  invalidModel,
  inferenceError,
}
