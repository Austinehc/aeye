import 'package:speech_to_text/speech_to_text.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/tts_service.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final SpeechToText _speechToText = SpeechToText();
  final TTSService _tts = TTSService();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastRecognizedText = '';
  String _lastError = '';
  
  // Store callbacks for continuous listening
  Function(String)? _onResultCallback;
  Function(String)? _onPartialResultCallback;
  bool _continuousMode = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get lastRecognizedText => _lastRecognizedText;
  String get lastError => _lastError;

  // Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      print(' Initializing Voice Service...');
      
      // Check if speech recognition is available
      final available = await _speechToText.initialize(
        onError: (error) {
          // Don't log timeout errors as they're normal for continuous listening
          if (!error.errorMsg.contains('timeout')) {
            print('⚠️ Speech recognition error: ${error.errorMsg}');
          }
          _lastError = error.errorMsg;
          _isListening = false;
        },
        onStatus: (status) {
          // Only log important status changes
          if (status != 'listening' && status != 'notListening') {
            print('🎤 Speech recognition status: $status');
          }
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            // Auto-restart listening in continuous mode
            if (_continuousMode && _onResultCallback != null) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (!_isListening && _continuousMode) {
                  _restartListening();
                }
              });
            }
            
            // Auto-restart in continuous mode when listening stops
            if (_continuousMode && _isInitialized && _onResultCallback != null) {
              Future.delayed(const Duration(milliseconds: 2000), () {
                if (_isInitialized && !_isListening && _continuousMode) {
                  print('🔄 Auto-restarting from status callback...');
                  startListening(
                    onResult: _onResultCallback!,
                    onPartialResult: _onPartialResultCallback,
                    continuous: _continuousMode,
                  );
                }
              });
            }
          }
        },
      );

      if (available) {
        _isInitialized = true;
        _lastError = '';
        print(' Voice Service initialized successfully');
        
        // Check available locales
        final locales = await _speechToText.locales();
        print('   Available locales: ${locales.length}');
        if (locales.isNotEmpty) {
          print('   Current locale: ${locales.first.localeId}');
        }
      } else {
        _isInitialized = false;
        _lastError = 'Speech recognition not available on this device';
        print(' Speech recognition not available');
      }

      return _isInitialized;
    } catch (e, stackTrace) {
      print(' Error initializing Voice Service: $e');
      print('   Stack trace: $stackTrace');
      _lastError = e.toString();
      _isInitialized = false;
      return false;
    }
  }

  // Start continuous listening with auto-restart
  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
    bool continuous = true, // Enable continuous listening by default
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized || _isListening) return;

    // Store callbacks for continuous mode
    _onResultCallback = onResult;
    _onPartialResultCallback = onPartialResult;
    _continuousMode = continuous;

    try {
      _isListening = true;
      
      await _speechToText.listen(
        onResult: (result) {
          _lastRecognizedText = result.recognizedWords;
          
          if (result.finalResult) {
            // Stop listening before processing command
            _isListening = false;
            
            // Process the command
            onResult(result.recognizedWords);
            
            // Auto-restart listening after processing result (continuous mode)
            if (continuous && _continuousMode) {
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (_isInitialized && !_isListening && _continuousMode) {
                  print('🔄 Auto-restarting continuous listening...');
                  startListening(
                    onResult: onResult,
                    onPartialResult: onPartialResult,
                    continuous: continuous,
                  );
                }
              });
            }
          } else if (onPartialResult != null) {
            onPartialResult(result.recognizedWords);
          }
        },
        listenFor: AppConstants.voiceCommandTimeout,
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );
    } catch (e) {
      print('❌ Error starting listening: $e');
      _isListening = false;
      
      // Auto-restart on error (continuous mode)
      if (continuous && _isInitialized) {
        Future.delayed(const Duration(seconds: 2), () {
          if (_isInitialized && !_isListening) {
            print('🔄 Restarting after error...');
            startListening(
              onResult: onResult,
              onPartialResult: onPartialResult,
              continuous: continuous,
            );
          }
        });
      }
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    _continuousMode = false; // Disable continuous mode
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
    }
  }

  // Cancel listening
  Future<void> cancelListening() async {
    _continuousMode = false; // Disable continuous mode
    if (_isListening) {
      await _speechToText.cancel();
      _isListening = false;
      _lastRecognizedText = '';
    }
  }

  // Process voice command
  String? processCommand(String recognizedText) {
    final lowerText = recognizedText.toLowerCase().trim();
    
    for (final entry in AppConstants.voiceCommandsMap.entries) {
      if (lowerText.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }

  // Check if command is a wake word
  bool isWakeWord(String text) {
    final lowerText = text.toLowerCase().trim();
    
    for (final wakeWord in AppConstants.wakeWords) {
      if (lowerText.contains(wakeWord)) {
        return true;
      }
    }
    
    return false;
  }

  // Get available locales
  Future<List<LocaleName>> getLocales() async {
    return await _speechToText.locales();
  }

  // Internal method to restart listening
  Future<void> _restartListening() async {
    if (_onResultCallback != null && !_isListening && _continuousMode) {
      print('🔄 Restarting listening...');
      await startListening(
        onResult: _onResultCallback!,
        onPartialResult: _onPartialResultCallback,
        continuous: _continuousMode,
      );
    }
  }

  // Dispose
  Future<void> dispose() async {
    await stopListening();
  }
}