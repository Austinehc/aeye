import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Image processing utilities using isolates for better performance
class ImageProcessingIsolate {
  /// Convert CameraImage to img.Image in a separate isolate
  static Future<img.Image> convertCameraImage(CameraImage cameraImage) async {
    return await _runInIsolate(_convertCameraImageIsolate, cameraImage);
  }

  /// Resize image in a separate isolate
  static Future<img.Image> resizeImage(
    img.Image image, {
    required int width,
    required int height,
  }) async {
    final params = _ResizeParams(image, width, height);
    return await _runInIsolate(_resizeImageIsolate, params);
  }

  /// Run a function in a separate isolate
  static Future<R> _runInIsolate<T, R>(
    R Function(T) function,
    T parameter,
  ) async {
    final receivePort = ReceivePort();
    
    await Isolate.spawn(
      _isolateEntry<T, R>,
      _IsolateParams(receivePort.sendPort, function, parameter),
    );

    return await receivePort.first as R;
  }

  /// Isolate entry point
  static void _isolateEntry<T, R>(_IsolateParams<T, R> params) {
    final result = params.function(params.parameter);
    params.sendPort.send(result);
  }

  /// Convert CameraImage to img.Image (isolate function)
  static img.Image _convertCameraImageIsolate(CameraImage cameraImage) {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToImage(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToImage(cameraImage);
      } else {
        throw UnsupportedError(
          'Unsupported image format: ${cameraImage.format.group}',
        );
      }
    } catch (e) {
      print('Error converting camera image: $e');
      rethrow;
    }
  }

  /// Convert YUV420 to img.Image
  static img.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    
    final img.Image image = img.Image(width: width, height: height);
    
    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = uvPixelStride * (x / 2).floor() +
            uvRowStride * (y / 2).floor();
        final int index = y * width + x;
        
        final yp = cameraImage.planes[0].bytes[index];
        final up = cameraImage.planes[1].bytes[uvIndex];
        final vp = cameraImage.planes[2].bytes[uvIndex];
        
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        
        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    
    return image;
  }

  /// Convert BGRA8888 to img.Image
  static img.Image _convertBGRA8888ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    
    final img.Image image = img.Image(width: width, height: height);
    final bytes = cameraImage.planes[0].bytes;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int pixelIndex = (y * width + x) * 4;
        
        final int b = bytes[pixelIndex];
        final int g = bytes[pixelIndex + 1];
        final int r = bytes[pixelIndex + 2];
        final int a = bytes[pixelIndex + 3];
        
        image.setPixelRgba(x, y, r, g, b, a);
      }
    }
    
    return image;
  }

  /// Resize image (isolate function)
  static img.Image _resizeImageIsolate(_ResizeParams params) {
    return img.copyResize(
      params.image,
      width: params.width,
      height: params.height,
      interpolation: img.Interpolation.linear,
    );
  }
}

/// Parameters for isolate communication
class _IsolateParams<T, R> {
  final SendPort sendPort;
  final R Function(T) function;
  final T parameter;

  _IsolateParams(this.sendPort, this.function, this.parameter);
}

/// Parameters for resize operation
class _ResizeParams {
  final img.Image image;
  final int width;
  final int height;

  _ResizeParams(this.image, this.width, this.height);
}
