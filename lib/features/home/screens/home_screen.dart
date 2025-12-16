import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_service.dart';
import '../../../core/utils/vibration_helper.dart';
import '../../object_detection/screens/object_detection_screen.dart';
import '../../ocr/screens/ocr_screen.dart';
import '../../voice/screens/voice_control_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../voice/services/voice_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TTSService _tts = TTSService();
  final VoiceService _voiceService = VoiceService();
  int _selectedIndex = 0;
  bool _isListening = false;
  String _recognizedText = '';
  bool _hasInitialized = false;

  final List<MenuItem> _menuItems = [
    MenuItem(
      title: 'Object Detection',
      description: 'Detect and identify objects around you',
      icon: Icons.camera_alt,
      route: '/object-detection',
    ),
    MenuItem(
      title: 'Text Reader',
      description: 'Read text from images and documents',
      icon: Icons.text_fields,
      route: '/ocr',
    ),
    MenuItem(
      title: 'Settings',
      description: 'Adjust app preferences',
      icon: Icons.settings,
      route: '/settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _announceScreen();
    _initializeVoice();
    _tts.addOnStartListener(_onTtsStart);
    _tts.addOnCompleteListener(_onTtsComplete);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // Restart voice listening when app comes to foreground
      print('📱 App resumed, restarting voice...');
      _restartVoiceListening();
    } else if (state == AppLifecycleState.paused) {
      // Stop listening when app goes to background
      print('📱 App paused, stopping voice...');
      _voiceService.stopListening();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voiceService.stopListening();
    _tts.removeOnStartListener(_onTtsStart);
    _tts.removeOnCompleteListener(_onTtsComplete);
    super.dispose();
  }

  Future<void> _announceScreen() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _tts.speak(
      'Home screen. ${_menuItems.length} options available. '
      'Say: detect objects, read text, settings, help, or exit.'
    );
  }

  Future<void> _initializeVoice() async {
    final ok = await _voiceService.initialize();
    if (!ok) {
      print('⚠️ Voice recognition initialization failed: ${_voiceService.lastError}');
      await _tts.speak('Voice recognition not available. You can still use touch controls.');
      return;
    }
    print('✅ Voice service initialized on home screen');
  }

  void _onTtsStart() {
    _voiceService.cancelListening();
  }

  void _onTtsComplete() {
    // Only start listening if voice service is initialized and we're not already listening
    if (mounted && !_isListening && _voiceService.isInitialized) {
      print('🎤 Starting voice listening after TTS complete');
      _startListening();
    }
  }

  void _restartVoiceListening() async {
    // Restart voice listening after returning from another screen
    if (!mounted) return;
    
    // Force stop any existing listening session
    await _voiceService.stopListening();
    setState(() {
      _isListening = false;
    });
    
    // Wait for everything to settle
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Start fresh if conditions are met
    if (mounted && !_tts.isSpeaking && _voiceService.isInitialized) {
      _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    
    // Double-check voice service state
    if (_isListening) {
      print('⚠️ Already listening, stopping first...');
      await _voiceService.stopListening();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    if (!_voiceService.isInitialized) {
      print('⚠️ Voice service not initialized, reinitializing...');
      final ok = await _voiceService.initialize();
      if (!ok) {
        print('❌ Failed to initialize voice service');
        return;
      }
    }
    
    if (!mounted) return;
    
    setState(() {
      _isListening = true;
      _recognizedText = '';
    });
    
    print('🎤 Voice listening started on home screen');
    
    try {
      await _voiceService.startListening(
        onResult: (text) async {
          if (!mounted) return;
          
          setState(() {
            _isListening = false;
            _recognizedText = text;
          });
          
          print('🎤 Voice command received: $text');
          await _handleVoiceResult(text);
        },
        onPartialResult: (text) {
          if (mounted) {
            setState(() {
              _recognizedText = text;
            });
          }
        },
        continuous: true, // VoiceService handles auto-restart
      );
    } catch (e) {
      print('❌ Error starting voice listening: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      
      // Retry after error
      if (mounted) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && !_tts.isSpeaking) {
          print('🔄 Retrying voice listening...');
          _startListening();
        }
      }
    }
  }

  Future<void> _handleVoiceResult(String recognizedText) async {
    print('📝 Processing voice command: "$recognizedText"');
    
    final cmd = _voiceService.processCommand(recognizedText) ?? '';
    final lower = recognizedText.toLowerCase();
    
    print('🔍 Matched command: "$cmd"');

    switch (cmd) {
      case 'object_detection':
        print('✅ Executing: object_detection');
        await _tts.speak('Opening object detection');
        if (mounted) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ObjectDetectionScreen()));
          _restartVoiceListening();
        }
        return;
      case 'ocr':
        print('✅ Executing: ocr');
        await _tts.speak('Opening text reader');
        if (mounted) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const OCRScreen()));
          _restartVoiceListening();
        }
        return;

      case 'help':
        print('✅ Executing: help');
        await _tts.speak('Say detect objects, read text, voice control, or settings.');
        return;
      case 'exit':
        print('✅ Executing: exit');
        await _tts.speak('You are on the home screen. Say a command to open a feature.');
        return;
    }
    
    print('⚠️ No exact command match, checking contains...');

    if (lower.contains('voice control') || lower.contains('voice')) {
      await _tts.speak('Opening voice control');
      if (mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceControlScreen()));
        _restartVoiceListening();
      }
      return;
    }
    if (lower.contains('setting')) {
      await _tts.speak('Opening settings');
      if (mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
        _restartVoiceListening();
      }
      return;
    }
    
    // Unrecognized command - provide feedback
    print('⚠️ Unrecognized command: "$recognizedText"');
    await _tts.speak('Command not recognized. Say help for available commands.');
  }

  void _navigateToScreen(int index) async {
    final item = _menuItems[index];
    
    switch (item.route) {
      case '/object-detection':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ObjectDetectionScreen()),
        );
        _restartVoiceListening();
        break;
      case '/ocr':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OCRScreen()),
        );
        _restartVoiceListening();
        break;
      case '/voice-control':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VoiceControlScreen()),
        );
        _restartVoiceListening();
        break;

      case '/settings':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        _restartVoiceListening();
        break;
    }
  }

  void _onItemTap(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    
    // Vibrate on selection
    await VibrationHelper.selection();
    
    // Announce the selected item
    final item = _menuItems[index];
    await _tts.speak('${item.title}. ${item.description}. Tap again to open.');
    
    // Auto-navigation removed in favor of standard accessibility pattern
    // User must double-tap to activate
    // This prevents accidental navigation while exploring
  }

  void _onItemDoubleTap(int index) async {
    // Vibrate on activation
    await VibrationHelper.activation();
    
    final item = _menuItems[index];
    await _tts.speak('Opening ${item.title}');
    
    await Future.delayed(const Duration(milliseconds: 500));
    _navigateToScreen(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aeye'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            iconSize: 35,
            onPressed: () async {
              await _tts.speak(
                'Aeye help. This is the home screen. '
                'You have 3 options: Object Detection, Text Reader, and Settings. '
                'Say a command like detect objects, read text, or settings.'
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Help Banner with Voice Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isListening 
                  ? AppTheme.successColor.withValues(alpha: 0.2)
                  : AppTheme.accentColor.withValues(alpha: 0.2),
              border: Border(
                bottom: BorderSide(
                  color: _isListening
                      ? AppTheme.successColor.withValues(alpha: 0.3)
                      : AppTheme.accentColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isListening ? Icons.mic : Icons.touch_app,
                  color: _isListening ? AppTheme.successColor : AppTheme.accentColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isListening 
                        ? '🎤 Listening... Say a command or tap an option'
                        : 'Tap any option to select, tap again to open',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_recognizedText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _recognizedText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
            // Menu Items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isSelected = index == _selectedIndex;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GestureDetector(
                      onTap: () => _onItemTap(index),
                      onDoubleTap: () => _onItemDoubleTap(index),
                      child: MenuCard(
                        item: item,
                        isSelected: isSelected,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MenuItem {
  final String title;
  final String description;
  final IconData icon;
  final String route;

  MenuItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
  });
}

class MenuCard extends StatelessWidget {
  final MenuItem item;
  final bool isSelected;

  const MenuCard({
    Key? key,
    required this.item,
    required this.isSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${item.title}. ${item.description}. ${isSelected ? "Selected" : "Tap to select"}',
      button: true,
      selected: isSelected,
      child: Card(
      elevation: isSelected ? 8 : 4,
      color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isSelected ? AppTheme.accentColor : Colors.transparent,
          width: 3,
        ),
      ),
      child: Container(
        height: 120,  // Reduced from 140
        padding: const EdgeInsets.all(16),  // Reduced from 20
        child: Row(
          children: [
            Container(
              width: 64,  // Reduced from 80
              height: 64,  // Reduced from 80
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accentColor : AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.icon,
                size: 40,  // Reduced from 50
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(width: 16),  // Reduced from 20
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
              color: isSelected ? AppTheme.accentColor : AppTheme.textColor.withValues(alpha: 0.5),
              size: isSelected ? 30 : 25,
            ),
          ],
        ),
      ),
    ),
    );
  }
}