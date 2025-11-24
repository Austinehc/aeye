import 'package:flutter_tts/flutter_tts.dart';
import '../constants/app_constants.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  final List<void Function()> _onStartListeners = [];
  final List<void Function()> _onCompleteListeners = [];

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;

  // Initialize TTS
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      print('Initializing TTS Service...');
      
      // Check if TTS is available
      final languages = await _flutterTts.getLanguages;
      if (languages.isEmpty) {
        print(' No TTS languages available on device');
        _isInitialized = false;
        return false;
      }
      
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(AppConstants.defaultSpeechRate);
      await _flutterTts.setPitch(AppConstants.defaultPitch);
      await _flutterTts.setVolume(AppConstants.defaultVolume);

      // Set callbacks
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        for (final l in _onStartListeners) {
          try { l(); } catch (_) {}
        }
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        for (final l in _onCompleteListeners) {
          try { l(); } catch (_) {}
        }
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        print(' TTS Error: $msg');
        // Mark as not initialized on error
        _isInitialized = false;
      });

      _isInitialized = true;
      print(' TTS Service initialized successfully');
      return true;
    } catch (e, stackTrace) {
      print(' Error initializing TTS: $e');
      print('   Stack trace: $stackTrace');
      _isInitialized = false;
      return false;
    }
  }

  // Speak text
  Future<bool> speak(String text) async {
    if (text.isEmpty) return false;
    
    // Initialize if needed and check success
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        print(' TTS not available, skipping speech: "$text"');
        return false;  // Gracefully skip if TTS unavailable
      }
    }

    try {
      await stop(); // Stop any current speech
      await _flutterTts.speak(text);
      return true;
    } catch (e) {
      print(' Error speaking: $e');
      print('   Text was: "$text"');
      _isInitialized = false;  // Mark as failed for re-initialization
      return false;
    }
  }

  // Stop speaking
  Future<bool> stop() async {
    if (_isSpeaking) {
      try {
        await _flutterTts.stop();
        _isSpeaking = false;
        return true;
      } catch (e) {
        print('❌ Error stopping speech: $e');
        _isSpeaking = false;
        return false;
      }
    }
    return true;
  }

  // Pause speaking
  Future<void> pause() async {
    if (_isSpeaking) {
      await _flutterTts.pause();
    }
  }

  // Register start listener
  void addOnStartListener(void Function() listener) {
    _onStartListeners.add(listener);
  }

  // Register completion listener
  void addOnCompleteListener(void Function() listener) {
    _onCompleteListeners.add(listener);
  }

  // Remove start listener
  void removeOnStartListener(void Function() listener) {
    _onStartListeners.remove(listener);
  }

  // Remove completion listener
  void removeOnCompleteListener(void Function() listener) {
    _onCompleteListeners.remove(listener);
  }

  // Set speech rate (0.0 to 1.0)
  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  // Set pitch (0.5 to 2.0)
  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  // Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume);
  }

  // Get available languages
  Future<List<String>> getLanguages() async {
    return await _flutterTts.getLanguages;
  }

  // Set language
  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }

  // Dispose
  Future<void> dispose() async {
    await stop();
  }
}