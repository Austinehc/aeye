import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../models/detection_result.dart';

class ObjectDetectorService {
  static final ObjectDetectorService _instance =
      ObjectDetectorService._internal();
  factory ObjectDetectorService() => _instance;
  ObjectDetectorService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _initialized = false;

  int _inputW = 640;
  int _inputH = 640;

  // Blocklist: ignore irrelevant COCO classes
  static const Set<String> ignoreLabels = {
    'parking meter',
    'fire hydrant',
    'toaster',
    'hair drier',
  };

  // ---------------- INITIALIZE ----------------

  Future<void> initialize() async {
    if (_initialized) return;

    final options = InterpreterOptions()..threads = 4;
    _interpreter = await Interpreter.fromAsset(
      AppConstants.objectDetectionModel,
      options: options,
    );

    final inputShape = _interpreter!.getInputTensor(0).shape;
    _inputH = inputShape[inputShape.length - 3];
    _inputW = inputShape[inputShape.length - 2];

    _labels = (await rootBundle
            .loadString(AppConstants.objectDetectionLabels))
        .split('\n')
        .where((e) => e.trim().isNotEmpty)
        .toList();

    _interpreter!.allocateTensors();
    _initialized = true;

    debugPrint('✅ YOLOv8 initialized ($_inputW x $_inputH)');
    debugPrint('📐 Output shape: ${_interpreter!.getOutputTensor(0).shape}');
  }

  // ---------------- DETECT ----------------

  Future<List<DetectionResult>> detectObjects(img.Image image) async {
    if (!_initialized) await initialize();
    if (_interpreter == null) return [];

    final lb = _letterbox(image);
    final input = _imageToTensor(lb.image);

    // YOLOv8 output: [1, 84, 8400]
    final output = List.generate(
      1,
      (_) => List.generate(84, (_) => List.filled(8400, 0.0)),
    );

    _interpreter!.run(input, output);

    final detections = _parseYolo(
      output[0],
      image.width,
      image.height,
      lb,
    );

    // STRICT: Only return the SINGLE BEST detection
    if (detections.isEmpty) return [];

    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Only return the best detection if it's confident enough
    final best = detections.first;
    if (best.confidence >= 0.65) {
      debugPrint(
          '🎯 FINAL: ${best.label} (${(best.confidence * 100).toInt()}%)');
      return [best];
    }

    return [];
  }

  // ---------------- PARSE YOLOv8 ----------------

  List<DetectionResult> _parseYolo(
    List<List<double>> out,
    int origW,
    int origH,
    _LetterboxInfo lb,
  ) {
    const int numClasses = 80;
    const double confThreshold = 0.50; // Initial filter
    const double iouThreshold = 0.45;

    final List<DetectionResult> detections = [];
    final int numBoxes = out[0].length;

    // Track the absolute best detection
    double globalBestScore = 0;
    int globalBestClass = -1;

    for (int i = 0; i < numBoxes; i++) {
      final double cx = out[0][i];
      final double cy = out[1][i];
      final double w = out[2][i];
      final double h = out[3][i];

      // Skip invalid boxes early
      if (w <= 0 || h <= 0) continue;

      int bestClass = -1;
      double bestScore = 0.0;
      double secondBestScore = 0.0;

      // Find best and second-best class scores
      for (int c = 0; c < numClasses; c++) {
        double score = out[4 + c][i];

        // If scores are in logit form (can be negative or > 1), apply sigmoid
        if (score < 0 || score > 1) {
          score = 1 / (1 + math.exp(-score));
        }

        if (score > bestScore) {
          secondBestScore = bestScore;
          bestScore = score;
          bestClass = c;
        } else if (score > secondBestScore) {
          secondBestScore = score;
        }
      }

      if (bestScore < confThreshold) continue;
      if (bestClass < 0 || bestClass >= _labels.length) continue;
      if (ignoreLabels.contains(_labels[bestClass])) continue;

      // STRICT: Require significant gap between best and second-best class
      final double gap = bestScore - secondBestScore;
      if (gap < 0.20) {
        debugPrint(
            '⚠️ Rejected ${_labels[bestClass]} (${(bestScore * 100).toInt()}%) - gap only ${(gap * 100).toInt()}%');
        continue;
      }

      // Track global best
      if (bestScore > globalBestScore) {
        globalBestScore = bestScore;
        globalBestClass = bestClass;
      }

      // Undo letterbox to get original image coordinates
      final double x = (cx - w / 2 - lb.padX) / lb.scale;
      final double y = (cy - h / 2 - lb.padY) / lb.scale;
      final double bw = w / lb.scale;
      final double bh = h / lb.scale;

      final double left = x.clamp(0.0, origW.toDouble());
      final double top = y.clamp(0.0, origH.toDouble());
      final double right = (x + bw).clamp(0.0, origW.toDouble());
      final double bottom = (y + bh).clamp(0.0, origH.toDouble());

      if (right <= left || bottom <= top) continue;

      // Minimum box size (at least 5% of image)
      final boxWidth = right - left;
      final boxHeight = bottom - top;
      if (boxWidth < origW * 0.05 || boxHeight < origH * 0.05) continue;

      final label = _labels[bestClass];
      debugPrint(
          '✅ Candidate: $label (${(bestScore * 100).toInt()}%) gap=${(gap * 100).toInt()}%');

      detections.add(
        DetectionResult(
          label: label,
          confidence: bestScore,
          boundingBox: BoundingBox(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
          ),
        ),
      );
    }

    debugPrint('📊 Total candidates: ${detections.length}');

    if (detections.isEmpty && globalBestClass >= 0) {
      debugPrint(
          '⚠️ No confident detections. Best was ${_labels[globalBestClass]} at ${(globalBestScore * 100).toInt()}%');
    }

    return _perClassNMS(detections, iouThreshold);
  }

  // ---------------- PER-CLASS NMS ----------------

  List<DetectionResult> _perClassNMS(
      List<DetectionResult> detections, double iouThreshold) {
    final Map<String, List<DetectionResult>> byClass = {};
    for (final d in detections) {
      byClass.putIfAbsent(d.label, () => []).add(d);
    }

    final List<DetectionResult> results = [];
    for (final classDetections in byClass.values) {
      results.addAll(_nms(classDetections, iouThreshold));
    }
    return results;
  }

  // ---------------- NMS ----------------

  List<DetectionResult> _nms(
    List<DetectionResult> dets,
    double iouThr,
  ) {
    dets.sort((a, b) => b.confidence.compareTo(a.confidence));
    final List<DetectionResult> res = [];

    for (final d in dets) {
      bool keep = true;
      for (final r in res) {
        if (_iou(d.boundingBox, r.boundingBox) > iouThr) {
          keep = false;
          break;
        }
      }
      if (keep) res.add(d);
    }
    return res;
  }

  double _iou(BoundingBox a, BoundingBox b) {
    final double x1 = math.max(a.left, b.left);
    final double y1 = math.max(a.top, b.top);
    final double x2 = math.min(a.right, b.right);
    final double y2 = math.min(a.bottom, b.bottom);

    final double inter = math.max(0.0, x2 - x1) * math.max(0.0, y2 - y1);
    final double union = a.area + b.area - inter;

    return union == 0 ? 0 : inter / union;
  }

  // ---------------- IMAGE ----------------

  List<List<List<List<double>>>> _imageToTensor(img.Image src) {
    return [
      List.generate(
        _inputH,
        (y) => List.generate(
          _inputW,
          (x) {
            final p = src.getPixel(x, y);
            return [
              p.r / 255.0,
              p.g / 255.0,
              p.b / 255.0,
            ];
          },
        ),
      ),
    ];
  }

  _LetterboxInfo _letterbox(img.Image src) {
    final double scale = math.min(_inputW / src.width, _inputH / src.height);

    final int newW = (src.width * scale).round();
    final int newH = (src.height * scale).round();

    final resized = img.copyResize(src, width: newW, height: newH);

    final canvas = img.Image(width: _inputW, height: _inputH);
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));

    final int dx = (_inputW - newW) ~/ 2;
    final int dy = (_inputH - newH) ~/ 2;

    img.compositeImage(
      canvas,
      resized,
      dstX: dx,
      dstY: dy,
    );

    return _LetterboxInfo(
      canvas,
      scale,
      dx.toDouble(),
      dy.toDouble(),
    );
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }
}

// ---------------- HELPER ----------------

class _LetterboxInfo {
  final img.Image image;
  final double scale;
  final double padX;
  final double padY;

  _LetterboxInfo(
    this.image,
    this.scale,
    this.padX,
    this.padY,
  );
}
