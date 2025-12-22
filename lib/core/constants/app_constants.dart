class AppConstants {
  // App Info
  static const String appName = 'Aeye';
  static const String appVersion = '1.0.0';
  
  // TensorFlow Lite Models
  static const String objectDetectionModel = 'assets/models/yolov8n.tflite';
  static const String objectDetectionLabels = 'assets/models/labelmap.txt';
  
  // Confidence Thresholds - LOWERED for initial testing
  static const double objectDetectionThreshold = 0.25; // Start low to see what model detects
  static const double nmsIouThreshold = 0.45; // Standard NMS
  static const double ocrConfidenceThreshold = 0.7;
  
  // Per-Class Confidence Thresholds - DISABLED for testing (use default)
  static const Map<String, double> perClassThresholds = {
    // All set to low values for testing
    'person': 0.25,
    'car': 0.25,
    'chair': 0.25,
    'couch': 0.25,
    'bed': 0.25,
    'dining table': 0.25,
    'tv': 0.25,
    'laptop': 0.25,
    'mouse': 0.25,
    'keyboard': 0.25,
    'cell phone': 0.25,
    'cup': 0.25,
    'bottle': 0.25,
    'wine glass': 0.25,
    'fork': 0.25,
    'knife': 0.25,
    'spoon': 0.25,
    'bowl': 0.25,
    'book': 0.25,
    'clock': 0.25,
    'bicycle': 0.25,
    'motorcycle': 0.25,
    'bus': 0.25,
    'truck': 0.25,
    'traffic light': 0.25,
    'stop sign': 0.25,
    'parking meter': 0.25,
    'backpack': 0.25,
    'umbrella': 0.25,
    'handbag': 0.25,
    'tie': 0.25,
    'suitcase': 0.25,
    'bird': 0.25,
    'cat': 0.25,
    'dog': 0.25,
    'horse': 0.25,
    'sheep': 0.25,
    'cow': 0.25,
    'elephant': 0.25,
    'bear': 0.25,
    'zebra': 0.25,
    'giraffe': 0.25,
  };
  
  // Voice Commands
  static const List<String> wakeWords = ['hey vision', 'hello vision'];
  static const Duration voiceCommandTimeout = Duration(seconds: 30); // Increased for continuous listening
  
  // TTS Settings
  static const double defaultSpeechRate = 0.5;
  static const double defaultPitch = 1.0;
  static const double defaultVolume = 1.0;
  
  // Camera Settings
  static const int targetImageWidth = 640;
  static const int targetImageHeight = 640;
  

  
  // Vibration Patterns
  static const List<int> successVibration = [0, 100, 50, 100];
  static const List<int> errorVibration = [0, 500];
  static const List<int> alertVibration = [0, 100, 100, 100, 100, 100];
  
  // Voice Commands - used by home screen for navigation
  static const Map<String, String> voiceCommandsMap = {
    'detect objects': 'object_detection',
    'object detection': 'object_detection',
    'detect': 'object_detection',
    'objects': 'object_detection',
    'read text': 'ocr',
    'scan text': 'ocr',
    'text reader': 'ocr',
    'ocr': 'ocr',
    'help': 'help',
    'exit': 'exit',
    'back': 'exit',
  };
}
