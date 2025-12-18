import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_service.dart';
import '../../../core/utils/vibration_helper.dart';
import '../../object_detection/screens/object_detection_screen.dart';
import '../../ocr/screens/ocr_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../voice/services/voice_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TTSService _tts = TTSService();
  final VoiceService _voiceService = VoiceService();
  int _selectedIndex = 0;
  bool _isListening = false;
  String _recognizedText = '';

  final List<MenuItem> _menuItems = [
    MenuItem(
      title: 'Object Detection',
      description: 'Detect and identify objects around you',
      icon: Icons.camera_alt,
    ),
    MenuItem(
      title: 'Text Reader',
      description: 'Read text from images and documents',
      icon: Icons.text_fields,
    ),
    MenuItem(
      title: 'Settings',
      description: 'Adjust app preferences',
      icon: Icons.settings,
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
      _restartVoiceListening();
    } else if (state == AppLifecycleState.paused) {
      _voiceService.stopListening();
      if (mounted) setState(() => _isListening = false);
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
    await _tts.speak('Home screen. Say detect objects, read text, or settings.');
  }

  Future<void> _initializeVoice() async {
    final ok = await _voiceService.initialize();
    if (!ok) {
      debugPrint('Voice recognition initialization failed: ${_voiceService.lastError}');
      await _tts.speak('Voice recognition not available. You can still use touch controls.');
    }
  }

  void _onTtsStart() {
    _voiceService.cancelListening();
  }

  void _onTtsComplete() {
    if (mounted && !_isListening && _voiceService.isInitialized) {
      _startListening();
    }
  }

  Future<void> _restartVoiceListening() async {
    if (!mounted) return;

    await _voiceService.stopListening();
    setState(() => _isListening = false);

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted && !_tts.isSpeaking && _voiceService.isInitialized) {
      _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!mounted) return;

    if (_isListening) {
      await _voiceService.stopListening();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!_voiceService.isInitialized) {
      final ok = await _voiceService.initialize();
      if (!ok) return;
    }

    if (!mounted) return;

    setState(() {
      _isListening = true;
      _recognizedText = '';
    });

    try {
      await _voiceService.startListening(
        onResult: (text) async {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _recognizedText = text;
          });
          await _handleVoiceResult(text);
        },
        onPartialResult: (text) {
          if (mounted) setState(() => _recognizedText = text);
        },
        continuous: true,
      );
    } catch (e) {
      debugPrint('Error starting voice listening: $e');
      if (mounted) setState(() => _isListening = false);

      if (mounted) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && !_tts.isSpeaking) _startListening();
      }
    }
  }

  Future<void> _handleVoiceResult(String recognizedText) async {
    final lower = recognizedText.toLowerCase().trim();

    if (lower.contains('detect') || lower.contains('object')) {
      await _tts.speak('Opening object detection');
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ObjectDetectionScreen()),
        );
        _restartVoiceListening();
      }
      return;
    }

    if (lower.contains('read') || lower.contains('text')) {
      await _tts.speak('Opening text reader');
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OCRScreen()),
        );
        _restartVoiceListening();
      }
      return;
    }

    if (lower.contains('setting')) {
      await _tts.speak('Opening settings');
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        _restartVoiceListening();
      }
      return;
    }

    if (lower.contains('help')) {
      await _tts.speak('Say detect objects, read text, or settings.');
      return;
    }

    await _tts.speak('Unknown command. Say detect objects, read text, or settings.');
  }

  void _openScreen(int index) async {
    Widget screen;
    switch (index) {
      case 0:
        screen = const ObjectDetectionScreen();
        break;
      case 1:
        screen = const OCRScreen();
        break;
      case 2:
        screen = const SettingsScreen();
        break;
      default:
        return;
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _restartVoiceListening();
  }

  void _onItemTap(int index) async {
    setState(() => _selectedIndex = index);
    await VibrationHelper.selection();

    final item = _menuItems[index];
    await _tts.speak('${item.title}. ${item.description}. Tap again to open.');
  }

  void _onItemDoubleTap(int index) async {
    await VibrationHelper.activation();

    final item = _menuItems[index];
    await _tts.speak('Opening ${item.title}');

    await Future.delayed(const Duration(milliseconds: 500));
    _openScreen(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AEye'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            iconSize: 35,
            onPressed: () async {
              await _tts.speak(
                'AEye help. This is the home screen. '
                'You have 3 options: Object Detection, Text Reader, and Settings. '
                'Say a command like detect objects, read text, or settings.',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Voice status banner
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
                          ? 'Listening... Say a command or tap an option'
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

            // Menu items
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
                      child: MenuCard(item: item, isSelected: isSelected),
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

  MenuItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class MenuCard extends StatelessWidget {
  final MenuItem item;
  final bool isSelected;

  const MenuCard({
    super.key,
    required this.item,
    required this.isSelected,
  });

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
          height: 120,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accentColor : AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  size: 40,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(width: 16),
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
                color: isSelected
                    ? AppTheme.accentColor
                    : AppTheme.textColor.withValues(alpha: 0.5),
                size: isSelected ? 30 : 25,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
