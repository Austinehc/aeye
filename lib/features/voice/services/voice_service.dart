import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../core/constants/app_constants.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastRecognizedText = '';
  String _lastError = '';
  
  // Callbacks
  Function(String)? _onResultCallback;
  Function(String)? _onPartialResultCallback;
  Function(bool)? _onListeningStateChanged;
  bool _continuousMode = false;
  
  // Timers
  Timer? _restartTimer;
  
  // Constants
  static const Duration _listenDuration = Duration(seconds: 30);
  static const Duration _pauseDuration = Duration(seconds: 3);

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get lastRecognizedText => _lastRecognizedText;
  String get lastError => _lastError;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      debugPrint('🎤 Initializing Voice Service...');
      
      final available = await _speechToText.initialize(
        onError: (error) {
          if (!error.errorMsg.contains('timeout') && !error.errorMsg.contains('no match')) {
            debugPrint('⚠️ Speech error: ${error.errorMsg}');
          }
          _lastError = error.errorMsg;
          
          // On error, update state and schedule restart
          if (_isListening) {
            _isListening = false;
            _onListeningStateChanged?.call(false);
            
            if (_continuousMode) {
              _scheduleRestart();
            }
          }
        },
        onStatus: (status) {
          debugPrint('🎤 Status: $status');
          
          if (status == 'done' || status == 'notListening') {
            if (_isListening) {
              _isListening = false;
              _onListeningStateChanged?.call(false);
              
              // Schedule restart if in continuous mode
              if (_continuousMode) {
                _scheduleRestart();
              }
            }
          }
        },
      );

      if (available) {
        _isInitialized = true;
        _lastError = '';
        debugPrint('✅ Voice Service initialized');
      } else {
        _isInitialized = false;
        _lastError = 'Speech recognition not available';
        debugPrint('❌ Speech recognition not available');
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('❌ Voice init error: $e');
      _lastError = e.toString();
      _isInitialized = false;
      return false;
    }
  }

  /// Start listening with automatic 30s cycle
  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
    Function(bool)? onListeningStateChanged,
    bool continuous = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized) return;
    
    // Cancel any pending restart
    _restartTimer?.cancel();
    
    // If already listening, stop first
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
    }

    // Store callbacks
    _onResultCallback = onResult;
    _onPartialResultCallback = onPartialResult;
    _onListeningStateChanged = onListeningStateChanged;
    _continuousMode = continuous;

    try {
      _isListening = true;
      _onListeningStateChanged?.call(true);
      
      // Beep to indicate listening started
      HapticFeedback.lightImpact();
      debugPrint('🎤 Started listening (30s cycle)');
      
      await _speechToText.listen(
        onResult: (result) {
          _lastRecognizedText = result.recognizedWords;
          
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            debugPrint('🎤 Final result: ${result.recognizedWords}');
            
            // Stop and update state
            _isListening = false;
            _onListeningStateChanged?.call(false);
            
            // Process the command
            onResult(result.recognizedWords);
            
            // Note: restart will happen after TTS completes via _onTtsComplete
          } else if (onPartialResult != null && result.recognizedWords.isNotEmpty) {
            onPartialResult(result.recognizedWords);
          }
        },
        listenFor: _listenDuration,
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );
    } catch (e) {
      debugPrint('❌ Listen error: $e');
      _isListening = false;
      _onListeningStateChanged?.call(false);
      
      if (continuous) {
        _scheduleRestart();
      }
    }
  }

  /// Schedule a restart after pause duration
  void _scheduleRestart() {
    _restartTimer?.cancel();
    
    if (!_continuousMode || _onResultCallback == null) return;
    
    debugPrint('⏳ Scheduling restart in ${_pauseDuration.inSeconds}s...');
    
    _restartTimer = Timer(_pauseDuration, () async {
      if (_continuousMode && _onResultCallback != null && !_isListening) {
        debugPrint('🔄 Restarting listening cycle');
        await startListening(
          onResult: _onResultCallback!,
          onPartialResult: _onPartialResultCallback,
          onListeningStateChanged: _onListeningStateChanged,
          continuous: true,
        );
      }
    });
  }

  /// Stop listening completely
  Future<void> stopListening() async {
    _continuousMode = false;
    _restartTimer?.cancel();
    _onListeningStateChanged = null;
    
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
    }
  }

  /// Cancel listening (used when TTS starts)
  Future<void> cancelListening() async {
    _restartTimer?.cancel();
    
    if (_isListening) {
      await _speechToText.cancel();
      _isListening = false;
      _onListeningStateChanged?.call(false);
      _lastRecognizedText = '';
    }
  }

  /// Resume listening after TTS completes
  Future<void> resumeListening() async {
    if (_continuousMode && _onResultCallback != null && !_isListening) {
      await startListening(
        onResult: _onResultCallback!,
        onPartialResult: _onPartialResultCallback,
        onListeningStateChanged: _onListeningStateChanged,
        continuous: true,
      );
    }
  }

  /// Process voice command
  String? processCommand(String recognizedText) {
    final lowerText = recognizedText.toLowerCase().trim();
    
    for (final entry in AppConstants.voiceCommandsMap.entries) {
      if (lowerText.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Get available locales
  Future<List<LocaleName>> getLocales() async {
    return await _speechToText.locales();
  }

  /// Dispose
  Future<void> dispose() async {
    _continuousMode = false;
    _restartTimer?.cancel();
    _onResultCallback = null;
    _onPartialResultCallback = null;
    _onListeningStateChanged = null;
    
    if (_isListening) {
      await _speechToText.cancel();
      _isListening = false;
    }
    await stopListening();
  }
}
