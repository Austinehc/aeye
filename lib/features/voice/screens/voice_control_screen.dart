import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_service.dart';
import '../../../core/constants/app_constants.dart';
import '../services/voice_service.dart';
import '../../object_detection/screens/object_detection_screen.dart';
import '../../ocr/screens/ocr_screen.dart';


class VoiceControlScreen extends StatefulWidget {
  const VoiceControlScreen({Key? key}) : super(key: key);

  @override
  State<VoiceControlScreen> createState() => _VoiceControlScreenState();
}

class _VoiceControlScreenState extends State<VoiceControlScreen> with SingleTickerProviderStateMixin {
  final TTSService _tts = TTSService();
  final VoiceService _voiceService = VoiceService();
  
  bool _isListening = false;
  String _recognizedText = '';
  String _statusMessage = 'Tap to start voice command';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _initializeVoice();
    _announceScreen();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  Future<void> _announceScreen() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _tts.speak(
      'Voice Control screen. '
      'Tap anywhere to start listening for commands. '
      'Available commands: detect objects, read text, where am I, navigate, help, or exit. '
      'Swipe down to go back.'
    );
  }

  Future<void> _initializeVoice() async {
    final success = await _voiceService.initialize();
    if (!success) {
      final error = _voiceService.lastError;
      setState(() {
        _statusMessage = 'Voice recognition not available';
      });
      await _tts.speak(
        'Voice recognition initialization failed. $error. '
        'Please check your microphone and speech recognition permissions.'
      );
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_voiceService.isInitialized) {
      await _tts.speak('Voice service not ready');
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _statusMessage = 'Listening...';
    });

    // Vibrate for feedback
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }

    await _tts.speak('Listening for command');

    await _voiceService.startListening(
      onResult: _handleVoiceResult,
      onPartialResult: (text) {
        setState(() {
          _recognizedText = text;
        });
      },
    );
  }

  Future<void> _stopListening() async {
    await _voiceService.stopListening();
    
    setState(() {
      _isListening = false;
      _statusMessage = 'Tap to start voice command';
    });
  }

  Future<void> _handleVoiceResult(String recognizedText) async {
    setState(() {
      _recognizedText = recognizedText;
      _isListening = false;
    });

    // Vibrate for feedback
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 150);
    }

    await _tts.speak('Processing command');

    final command = _voiceService.processCommand(recognizedText);

    if (command == null) {
      setState(() {
        _statusMessage = 'Command not recognized';
      });
      await _tts.speak('Command not recognized. Please try again.');
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _statusMessage = 'Tap to start voice command';
      });
      return;
    }

    await _executeCommand(command);
  }

  Future<void> _executeCommand(String command) async {
    setState(() {
      _statusMessage = 'Executing command...';
    });

    switch (command) {
      case 'object_detection':
        await _tts.speak('Opening object detection');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ObjectDetectionScreen()),
          );
        }
        break;

      case 'ocr':
        await _tts.speak('Opening text reader');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OCRScreen()),
          );
        }
        break;



      case 'help':
        await _provideHelp();
        break;

      case 'exit':
        await _tts.speak('Going back');
        if (mounted) {
          Navigator.pop(context);
        }
        break;

      default:
        await _tts.speak('Unknown command');
    }

    setState(() {
      _statusMessage = 'Tap to start voice command';
    });
  }

  Future<void> _provideHelp() async {
    await _tts.speak(
      'Available voice commands: '
      'Say detect objects to scan your surroundings. '
      'Say read text to scan and read text. '
      'Say where am I to get your location. '
      'Say navigate for directions. '
      'Say help to hear this again. '
      'Say exit to go back.'
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Control'),
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          iconSize: 35,
          onPressed: () async {
            await _voiceService.stopListening();
            await _tts.speak('Going back');
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            iconSize: 35,
            onPressed: _provideHelp,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _toggleListening,
        onVerticalDragEnd: (details) async {
          if (details.primaryVelocity! > 0) {
            await _voiceService.stopListening();
            await _tts.speak('Going back');
            Navigator.pop(context);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.backgroundColor,
                AppTheme.primaryColor.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                             MediaQuery.of(context).padding.top - 
                             kToolbarHeight,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Microphone Icon with Animation
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Container(
                          width: 180 + (_isListening ? _animationController.value * 30 : 0),
                          height: 180 + (_isListening ? _animationController.value * 30 : 0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening 
                                ? AppTheme.successColor.withValues(alpha: 0.3)
                                : AppTheme.accentColor.withValues(alpha: 0.3),
                            border: Border.all(
                              color: _isListening ? AppTheme.successColor : AppTheme.accentColor,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            size: 80,
                            color: _isListening ? AppTheme.successColor : AppTheme.accentColor,
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Status Message
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _statusMessage,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // Recognized Text
                    if (_recognizedText.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 30),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: AppTheme.accentColor,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          _recognizedText,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // Commands List
                    Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Available Commands:',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppTheme.accentColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildCommandItem('"Detect objects"', 'Scan surroundings'),
                          _buildCommandItem('"Read text"', 'Scan and read text'),
                          _buildCommandItem('"Where am I"', 'Get location'),
                          _buildCommandItem('"Navigate"', 'Get directions'),
                          _buildCommandItem('"Help"', 'Hear commands again'),
                          _buildCommandItem('"Exit"', 'Go back'),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommandItem(String command, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.arrow_right,
            color: AppTheme.accentColor,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  command,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}