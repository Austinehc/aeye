import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../models/detection_result.dart';

class ObjectDetectorService {
  static final ObjectDetectorService _instance = ObjectDetectorService._internal();
  factory ObjectDetectorService() => _instance;
  ObjectDetectorService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  List<int>? _inputShape;
  List<int>? _outputShape;
  bool _isInputCHW = false;
  bool _isOutputCHW = false;
  TensorType? _outputType;
  bool _outputQuantized = false;
  double? _outputScale;
  int? _outputZeroPoint;
  
  // ✅ PERFORMANCE OPTIMIZATION: Pre-allocated tensors for smooth video
  List<dynamic>? _preAllocatedInput;
  List<dynamic>? _preAllocatedOutput;
  int _targetWidth = 320;
  int _targetHeight = 320;
  
  // ✅ REMOVED: Inference throttling - frame skip in screen handles this
  // ✅ REMOVED: Image caching - causes memory leaks and adds overhead

  bool get isInitialized => _isInitialized;

  // Initialize the model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // ✅ Check if model file exists
      print('Checking for model file: ${AppConstants.objectDetectionModel}');
      final modelExists = await _checkAssetExists(AppConstants.objectDetectionModel);
      if (!modelExists) {
        throw Exception(
          'Model file not found: ${AppConstants.objectDetectionModel}. '
          'Please ensure yolov8n.tflite is in assets/models/ folder.'
        );
      }
      
      // ✅ Check if labels file exists
      print('Checking for labels file: ${AppConstants.objectDetectionLabels}');
      final labelsExist = await _checkAssetExists(AppConstants.objectDetectionLabels);
      if (!labelsExist) {
        throw Exception(
          'Labels file not found: ${AppConstants.objectDetectionLabels}. '
          'Please ensure labelmap.txt is in assets/models/ folder.'
        );
      }
      
      // Load model with optimized options
      print('Loading TFLite model...');
      
      // Try with NNAPI first
      try {
        final options = InterpreterOptions()
          ..threads = 4
          ..useNnApiForAndroid = true;
        
        _interpreter = await Interpreter.fromAsset(
          AppConstants.objectDetectionModel,
          options: options,
        );
        print('✅ Model loaded with NNAPI acceleration');
      } catch (e) {
        print('⚠️ NNAPI not available, loading without acceleration: $e');
        
        // Fallback: Load without NNAPI
        final options = InterpreterOptions()..threads = 4;
        
        _interpreter = await Interpreter.fromAsset(
          AppConstants.objectDetectionModel,
          options: options,
        );
        print('✅ Model loaded without NNAPI (CPU only)');
      }
      
      // ✅ Verify interpreter loaded
      if (_interpreter == null) {
        throw Exception('Failed to create interpreter from model file');
      }
      
      // ✅ Verify input/output shapes
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      
      // Determine input format: CHW = [1, 3, H, W], HWC = [1, H, W, 3]
      if (_inputShape!.length == 4) {
        if (_inputShape![1] == 3) {
          _isInputCHW = true;  // [1, 3, 320, 320]
          _targetHeight = _inputShape![2];
          _targetWidth = _inputShape![3];
        } else if (_inputShape![3] == 3) {
          _isInputCHW = false;  // [1, 320, 320, 3]
          _targetHeight = _inputShape![1];
          _targetWidth = _inputShape![2];
        } else {
          print('⚠️ WARNING: Unexpected input shape format: $_inputShape');
          // Default to CHW for YOLOv8
          _isInputCHW = true;
          _targetHeight = _inputShape![2];
          _targetWidth = _inputShape![3];
        }
      }
      
      // Determine output format
      _isOutputCHW = _outputShape!.length == 3 && _outputShape![1] == 84;
      
      // ✅ OPTIMIZATION: Pre-allocate tensors for faster inference
      _preAllocateInferenceTensors();
      
      print('Model loaded successfully:');
      print('  Input shape: $_inputShape (Format: ${_isInputCHW ? "CHW" : "HWC"})');
      print('  Target dimensions: ${_targetWidth}x${_targetHeight}');
      print('  Output shape: $_outputShape');
      final outTensor = _interpreter!.getOutputTensor(0);
      _outputType = outTensor.type;
      final qp = outTensor.params;
      if (qp != null) {
        _outputScale = qp.scale;
        _outputZeroPoint = qp.zeroPoint;
      }
      _outputQuantized = (_outputType == TensorType.uint8 || _outputType == TensorType.int8);
      
      // ✅ Validate YOLOv8 output shape [1, 84, 8400]
      print('🔍 Validating model shapes:');
      print('   Input shape: $_inputShape (CHW: $_isInputCHW)');
      print('   Output shape: $_outputShape (CHW: $_isOutputCHW)');
      print('   Output type: $_outputType');
      print('   Quantized: $_outputQuantized');
      
      if (!(_outputShape!.length == 3 && _outputShape![0] == 1 &&
            ((_outputShape![1] == 84 && _outputShape![2] == 8400) ||
             (_outputShape![1] == 8400 && _outputShape![2] == 84)))) {
        print('⚠️ WARNING: Unexpected output shape. Expected [1, 84, 8400] or [1, 8400, 84], got $_outputShape');
        print('⚠️ Model may not be YOLOv8n. Detection may not work correctly.');
      } else {
        print('✅ Model shape validation passed - YOLOv8n format confirmed');
      }
      
      // Load labels
      print('Loading labels...');
      final labelsData = await rootBundle.loadString(AppConstants.objectDetectionLabels);
      _labels = labelsData.split('\n').where((label) => label.isNotEmpty).toList();
      
      // ✅ Validate labels count (COCO has 80 classes)
      if (_labels.length != 80) {
        print('WARNING: Expected 80 labels (COCO dataset), got ${_labels.length}');
        print('Detection may not work correctly.');
      }
      
      _isInitialized = true;
      print('✅ Object Detection Service initialized successfully');
      print('   Loaded ${_labels.length} labels');
      print('   Model ready for inference');
      print('   Pre-allocated tensors for smooth video: ${_targetWidth}x${_targetHeight}');
    } catch (e, stackTrace) {
      print('❌ Error initializing Object Detection Service:');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      _isInitialized = false;
      _interpreter?.close();
      _interpreter = null;
      rethrow;  // Let caller handle the error
    }
  }
  
  // Check if asset file exists
  Future<bool> _checkAssetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ✅ OPTIMIZED: Detect objects with performance optimization for smooth video
  Future<List<DetectionResult>> detectObjects(img.Image image) async {
    if (!_isInitialized) {
      print('⚠️ Detector not initialized, initializing now...');
      await initialize();
    }

    if (_interpreter == null) {
      print('❌ Interpreter is null after initialization!');
      throw Exception('Interpreter not initialized');
    }

    try {
      final input = _preprocessImageOptimized(image);
      final output = _preAllocatedOutput ?? 
                    _createZeroedOutputOfType(_outputShape!, _outputQuantized);

      _interpreter!.run(input, output);

      final results = _parseYOLOv8Results(output, image.width, image.height, _targetWidth, _targetHeight);
      
      return results;
    } catch (e, stackTrace) {
      print('❌ Error in optimized detection: $e');
      print('📋 Stack trace: $stackTrace');
      return [];
    }
  }

  /// ✅ NEW: Detect from raw RGB bytes (for camera stream - avoids disk I/O)
  Future<List<DetectionResult>> detectFromRgbBytes(
    Uint8List rgbBytes,
    int width,
    int height,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_interpreter == null) {
      return [];
    }

    try {
      // Resize and normalize RGB bytes directly to model input
      final input = _preprocessRgbBytes(rgbBytes, width, height);
      final output = _preAllocatedOutput ?? 
                    _createZeroedOutputOfType(_outputShape!, _outputQuantized);

      _interpreter!.run(input, output);

      return _parseYOLOv8Results(output, width, height, _targetWidth, _targetHeight);
    } catch (e) {
      print('❌ Error in RGB detection: $e');
      return [];
    }
  }

  /// Preprocess RGB bytes directly (faster than going through img.Image)
  List<dynamic> _preprocessRgbBytes(Uint8List rgbBytes, int srcWidth, int srcHeight) {
    final input = _preAllocatedInput ?? _createNewInputTensor();
    
    // Simple nearest-neighbor resize for speed
    final scaleX = srcWidth / _targetWidth;
    final scaleY = srcHeight / _targetHeight;
    
    if (_isInputCHW) {
      for (int y = 0; y < _targetHeight; y++) {
        final srcY = (y * scaleY).toInt().clamp(0, srcHeight - 1);
        for (int x = 0; x < _targetWidth; x++) {
          final srcX = (x * scaleX).toInt().clamp(0, srcWidth - 1);
          final srcIdx = (srcY * srcWidth + srcX) * 3;
          
          if (srcIdx + 2 < rgbBytes.length) {
            input[0][0][y][x] = rgbBytes[srcIdx] / 255.0;
            input[0][1][y][x] = rgbBytes[srcIdx + 1] / 255.0;
            input[0][2][y][x] = rgbBytes[srcIdx + 2] / 255.0;
          }
        }
      }
    } else {
      for (int y = 0; y < _targetHeight; y++) {
        final srcY = (y * scaleY).toInt().clamp(0, srcHeight - 1);
        for (int x = 0; x < _targetWidth; x++) {
          final srcX = (x * scaleX).toInt().clamp(0, srcWidth - 1);
          final srcIdx = (srcY * srcWidth + srcX) * 3;
          
          if (srcIdx + 2 < rgbBytes.length) {
            input[0][y][x][0] = rgbBytes[srcIdx] / 255.0;
            input[0][y][x][1] = rgbBytes[srcIdx + 1] / 255.0;
            input[0][y][x][2] = rgbBytes[srcIdx + 2] / 255.0;
          }
        }
      }
    }
    
    return input;
  }
  
  // ✅ OPTIMIZED: Pre-allocate tensors with retry logic
  void _preAllocateInferenceTensors() {
    if (_inputShape == null || _outputShape == null) return;
    
    try {
      // Pre-allocate input tensor
      if (_isInputCHW) {
        _preAllocatedInput = List.generate(1, (_) =>
            List.generate(3, (_) =>
                List.generate(_targetHeight, (_) => 
                    List<double>.filled(_targetWidth, 0.0))));
      } else {
        _preAllocatedInput = List.generate(1, (_) =>
            List.generate(_targetHeight, (_) =>
                List.generate(_targetWidth, (_) => 
                    List<double>.filled(3, 0.0))));
      }
      
      // Pre-allocate output tensor
      _preAllocatedOutput = _createZeroedOutputOfType(_outputShape!, _outputQuantized);
      
      print('✅ Pre-allocated inference tensors: ${_targetWidth}x${_targetHeight}');
      print('   Input tensor size: ~${(_targetWidth * _targetHeight * 3 * 8 / 1024).toStringAsFixed(1)} KB');
    } catch (e) {
      print('⚠️ Failed to pre-allocate tensors: $e');
      print('   Will allocate on-demand (slower but functional)');
      _preAllocatedInput = null;
      _preAllocatedOutput = null;
    }
  }

  // ✅ OPTIMIZED: Fast preprocessing with batch pixel access
  List<dynamic> _preprocessImageOptimized(img.Image image) {
    // Resize image once
    final resized = img.copyResize(image, width: _targetWidth, height: _targetHeight);
    
    // ✅ PERFORMANCE: Reuse pre-allocated tensor if available
    final input = _preAllocatedInput ?? _createNewInputTensor();

    // ✅ OPTIMIZATION: Batch process pixels for better cache locality
    if (_isInputCHW) {
      // CHW format: [batch, channels, height, width]
      // Process by channel for better memory access pattern
      for (int y = 0; y < _targetHeight; y++) {
        for (int x = 0; x < _targetWidth; x++) {
          final p = resized.getPixel(x, y);
          final rNorm = p.r / 255.0;
          final gNorm = p.g / 255.0;
          final bNorm = p.b / 255.0;
          
          input[0][0][y][x] = rNorm;
          input[0][1][y][x] = gNorm;
          input[0][2][y][x] = bNorm;
        }
      }
    } else {
      // HWC format: [batch, height, width, channels]
      // Process row by row for better cache performance
      for (int y = 0; y < _targetHeight; y++) {
        for (int x = 0; x < _targetWidth; x++) {
          final p = resized.getPixel(x, y);
          input[0][y][x][0] = p.r / 255.0;
          input[0][y][x][1] = p.g / 255.0;
          input[0][y][x][2] = p.b / 255.0;
        }
      }
    }
    
    return input;
  }
  
  // ✅ HELPER: Create new input tensor when pre-allocation fails
  List<dynamic> _createNewInputTensor() {
    if (_isInputCHW) {
      return List.generate(1, (_) =>
          List.generate(3, (_) =>
              List.generate(_targetHeight, (_) => 
                  List<double>.filled(_targetWidth, 0.0))));
    } else {
      return List.generate(1, (_) =>
          List.generate(_targetHeight, (_) =>
              List.generate(_targetWidth, (_) => 
                  List<double>.filled(3, 0.0))));
    }
  }

  // Parse YOLOv8 detection results (OPTIMIZED)
  List<DetectionResult> _parseYOLOv8Results(
    List<dynamic> output,
    int imageWidth,
    int imageHeight,
    int modelInputWidth,
    int modelInputHeight,
  ) {
    // ✅ Pre-allocate list with estimated capacity
    final validDetections = <_RawDetection>[];
    final threshold = AppConstants.objectDetectionThreshold;
    
    // YOLOv8 output shape: [1, 84, 8400]
    // First 4 values: [x_center, y_center, width, height] (normalized 0-1)
    // Next 80 values: class probabilities
    
    // ✅ OPTIMIZATION: Find max class probability FIRST, then process bbox only if valid
    final anchorCount = _isOutputCHW
        ? (_outputShape != null ? _outputShape![2] : 8400)
        : (_outputShape != null ? _outputShape![1] : 8400);
    
    double getVal(int channel, int i) {
      final v = _isOutputCHW ? output[0][channel][i] : output[0][i][channel];
      double val = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
      if (_outputQuantized && _outputScale != null) {
        final zp = _outputZeroPoint ?? 0;
        val = (val - zp) * _outputScale!;
      }
      return val;
    }
    
    for (int i = 0; i < anchorCount; i++) {
      double maxProb = 0.0;
      int maxClassIndex = 0;
      for (int c = 0; c < 80; c++) {
        final prob = getVal(4 + c, i);
        if (prob > maxProb) {
          maxProb = prob;
          maxClassIndex = c;
        }
      }
      
      if (maxProb < threshold) continue;
      if (maxClassIndex < 0 || maxClassIndex >= _labels.length) continue;

      final xCenter = getVal(0, i);
      final yCenter = getVal(1, i);
      final width = getVal(2, i);
      final height = getVal(3, i);

      validDetections.add(_RawDetection(
        xCenter: xCenter,
        yCenter: yCenter,
        width: width,
        height: height,
        classIndex: maxClassIndex,
        confidence: maxProb,
      ));
    }
    
    // ✅ Convert to DetectionResult with validation
    final results = <DetectionResult>[];
    final imgWidthD = imageWidth.toDouble();
    final imgHeightD = imageHeight.toDouble();
    
    for (final raw in validDetections) {
      // ✅ FIX: Validate normalized coordinates
      final isNorm = raw.xCenter <= 1.0 && raw.yCenter <= 1.0 &&
                     raw.width <= 1.0 && raw.height <= 1.0;
      final xCenterN = isNorm ? raw.xCenter : (raw.xCenter / modelInputWidth);
      final yCenterN = isNorm ? raw.yCenter : (raw.yCenter / modelInputHeight);
      final widthN   = isNorm ? raw.width   : (raw.width   / modelInputWidth);
      final heightN  = isNorm ? raw.height  : (raw.height  / modelInputHeight);
      
      // ✅ FIX: Filter out unreasonably large boxes (likely errors)
      // Max 80% of image width/height for a single object
      if (widthN > 0.8 || heightN > 0.8) {
        continue;
      }
      
      // ✅ FIX: Filter out tiny boxes (likely noise)
      // Min 2% of image width/height
      if (widthN < 0.02 || heightN < 0.02) {
        continue;
      }
      
      // Convert from center format to corner format (denormalize)
      final halfW = widthN / 2;
      final halfH = heightN / 2;
      
      final left = ((xCenterN - halfW) * imgWidthD).clamp(0.0, imgWidthD);
      final top = ((yCenterN - halfH) * imgHeightD).clamp(0.0, imgHeightD);
      final right = ((xCenterN + halfW) * imgWidthD).clamp(0.0, imgWidthD);
      final bottom = ((yCenterN + halfH) * imgHeightD).clamp(0.0, imgHeightD);
      
      // ✅ FIX: Validate final box dimensions
      final boxWidth = right - left;
      final boxHeight = bottom - top;
      
      // Skip invalid boxes
      if (boxWidth <= 0 || boxHeight <= 0) {
        continue;
      }
      
      // ✅ FIX: Skip boxes with extreme aspect ratios (likely errors)
      final aspectRatio = boxWidth / boxHeight;
      if (aspectRatio > 5.0 || aspectRatio < 0.2) {
        continue;
      }
      
      results.add(DetectionResult(
        label: _labels[raw.classIndex],
        confidence: raw.confidence,
        boundingBox: BoundingBox(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ),
      ));
    }
    
    // Apply Non-Maximum Suppression (NMS)
    final nmsResults = _applyNMS(results, iouThreshold: AppConstants.nmsIouThreshold);
    
    // Sort by confidence
    nmsResults.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    // Return top 5 detections for better performance
    return nmsResults.take(5).toList();
  }

  // Apply Non-Maximum Suppression to remove overlapping boxes
  List<DetectionResult> _applyNMS(
    List<DetectionResult> detections,
    {double iouThreshold = 0.45}
  ) {
    if (detections.isEmpty) return [];
    
    // Sort by confidence (descending)
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    final selected = <DetectionResult>[];
    final suppressed = List<bool>.filled(detections.length, false);
    
    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      
      selected.add(detections[i]);
      
      // Suppress overlapping boxes
      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        
        final iou = _calculateIOU(
          detections[i].boundingBox,
          detections[j].boundingBox,
        );
        
        if (iou > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    
    return selected;
  }

  // Calculate Intersection over Union
  double _calculateIOU(BoundingBox box1, BoundingBox box2) {
    // Calculate intersection area
    final x1 = box1.left > box2.left ? box1.left : box2.left;
    final y1 = box1.top > box2.top ? box1.top : box2.top;
    final x2 = box1.right < box2.right ? box1.right : box2.right;
    final y2 = box1.bottom < box2.bottom ? box1.bottom : box2.bottom;
    
    final intersectionWidth = (x2 - x1).clamp(0.0, double.infinity);
    final intersectionHeight = (y2 - y1).clamp(0.0, double.infinity);
    final intersectionArea = intersectionWidth * intersectionHeight;
    
    // Calculate union area
    final box1Area = (box1.right - box1.left) * (box1.bottom - box1.top);
    final box2Area = (box2.right - box2.left) * (box2.bottom - box2.top);
    final unionArea = box1Area + box2Area - intersectionArea;
    
    if (unionArea == 0) return 0.0;
    
    return intersectionArea / unionArea;
  }

  // Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    
    // ✅ CLEANUP: Clear pre-allocated tensors
    _preAllocatedInput = null;
    _preAllocatedOutput = null;
  }
}

// Lightweight class for raw detection data (optimization)
class _RawDetection {
  final double xCenter;
  final double yCenter;
  final double width;
  final double height;
  final int classIndex;
  final double confidence;

  _RawDetection({
    required this.xCenter,
    required this.yCenter,
    required this.width,
    required this.height,
    required this.classIndex,
    required this.confidence,
  });
}

// Extension to reshape lists
extension ListReshape on List<double> {
  List<dynamic> reshape(List<int> shape) {
    if (shape.length == 1) {
      return this;
    } else if (shape.length == 2) {
      var result = List.generate(shape[0], (i) => 
        List.generate(shape[1], (j) => this[i * shape[1] + j])
      );
      return result;
    } else if (shape.length == 3) {
      var result = List.generate(shape[0], (i) => 
        List.generate(shape[1], (j) => 
          List.generate(shape[2], (k) => 
            this[i * shape[1] * shape[2] + j * shape[2] + k]
          )
        )
      );
      return result;
    }
    return this;
  }
}

List<dynamic> _createZeroedOutputOfType(List<int> shape, bool quantized) {
  if (shape.isEmpty) return quantized ? <int>[] : <double>[];
  if (shape.length == 1) {
    return quantized ? List<int>.filled(shape[0], 0) : List<double>.filled(shape[0], 0.0);
  }
  return List.generate(shape[0], (_) => _createZeroedOutputOfType(shape.sublist(1), quantized));
}