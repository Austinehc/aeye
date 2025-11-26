class AppConstants {
  // App Info
  static const String appName = 'Aeye';
  static const String appVersion = '1.0.0';
  
  // TensorFlow Lite Models
  static const String objectDetectionModel = 'assets/models/yolov8n.tflite';
  static const String objectDetectionLabels = 'assets/models/labelmap.txt';
  
  // Confidence Thresholds
  static const double objectDetectionThreshold = 0.45; // Higher threshold for better quality detections
  static const double nmsIouThreshold = 0.45; // Standard NMS threshold for good overlap filtering
  static const double ocrConfidenceThreshold = 0.7;
  
  // Voice Commands
  static const List<String> wakeWords = ['hey vision', 'hello vision'];
  static const Duration voiceCommandTimeout = Duration(seconds: 30); // Increased for continuous listening
  
  // TTS Settings
  static const double defaultSpeechRate = 0.5;
  static const double defaultPitch = 1.0;
  static const double defaultVolume = 1.0;
  
  // Camera Settings
  static const int targetImageWidth = 320;
  static const int targetImageHeight = 320;
  

  
  // Vibration Patterns
  static const List<int> successVibration = [0, 100, 50, 100];
  static const List<int> errorVibration = [0, 500];
  static const List<int> alertVibration = [0, 100, 100, 100, 100, 100];
  
  // Voice Commands
  static const Map<String, String> voiceCommandsMap = {
    'detect objects': 'object_detection',
    'read text': 'ocr',
    'scan text': 'ocr',
    'help': 'help',
    'exit': 'exit',
  };
}
