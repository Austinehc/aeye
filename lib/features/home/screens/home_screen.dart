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
  int _selectedIndex = -1;
  bool _isListening = false;
  String _recognizedText = '';

  final List<MenuItem> _menuItems = [
    MenuItem(
      title: 'Object Detection',
      description: 'Identify objects around you',
      icon: Icons.camera_alt_rounded,
      color: const Color(0xFF3B82F6),
    ),
    MenuItem(
      title: 'Text Reader',
      description: 'Scan and read documents',
      icon: Icons.document_scanner_rounded,
      color: const Color(0xFF22C55E),
    ),
    MenuItem(
      title: 'Settings',
      description: 'Customize your experience',
      icon: Icons.settings_rounded,
      color: const Color(0xFF8B5CF6),
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
      await _tts.speak('Voice not available. Use touch controls.');
    }
    // Note: listening will start after TTS completes via _onTtsComplete
  }

  void _onTtsStart() {
    _voiceService.cancelListening();
    if (mounted) setState(() => _isListening = false);
  }

  void _onTtsComplete() {
    if (mounted && _voiceService.isInitialized) {
      // Start listening after TTS completes
      _startListening();
    }
  }

  Future<void> _restartVoiceListening() async {
    if (!mounted) return;
    await _voiceService.stopListening();
    setState(() => _isListening = false);
    
    // Wait for TTS to complete instead of fixed delay
    int attempts = 0;
    while (_tts.isSpeaking && mounted && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    
    if (mounted && _voiceService.isInitialized) {
      _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    if (!_voiceService.isInitialized && !await _voiceService.initialize()) return;

    setState(() => _recognizedText = '');

    try {
      await _voiceService.startListening(
        onResult: (text) async {
          if (!mounted) return;
          setState(() => _recognizedText = text);
          await _handleVoiceResult(text);
        },
        onPartialResult: (text) {
          if (mounted) setState(() => _recognizedText = text);
        },
        onListeningStateChanged: (isListening) {
          if (mounted) setState(() => _isListening = isListening);
        },
        continuous: true,
      );
    } catch (e) {
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _handleVoiceResult(String text) async {
    final lower = text.toLowerCase().trim();

    if (lower.contains('detect') || lower.contains('object')) {
      await _openScreen(0);
    } else if (lower.contains('read') || lower.contains('text')) {
      await _openScreen(1);
    } else if (lower.contains('setting')) {
      await _openScreen(2);
    } else if (lower.contains('help')) {
      await _tts.speak('Say detect objects, read text, or settings.');
    } else {
      await _tts.speak('Unknown command. Say detect objects, read text, or settings.');
    }
  }

  Future<void> _openScreen(int index) async {
    final screens = [
      const ObjectDetectionScreen(),
      const OCRScreen(),
      const SettingsScreen(),
    ];

    await _tts.speak('Opening ${_menuItems[index].title}');
    if (mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => screens[index]));
      _restartVoiceListening();
    }
  }

  void _onItemTap(int index) async {
    setState(() => _selectedIndex = index);
    await VibrationHelper.selection();
    await _tts.speak('${_menuItems[index].title}. Double tap to open.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildVoiceStatus(context),
            const SizedBox(height: 8),
            _buildMenuList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: AppTheme.primaryGradient,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.visibility,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AEye', style: Theme.of(context).textTheme.headlineMedium),
                Text('Your Vision, Enhanced', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _tts.speak('Say detect objects, read text, or settings.'),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.help_outline_rounded, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceStatus(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isListening
            ? AppTheme.successColor.withValues(alpha: 0.15)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isListening ? AppTheme.successColor.withValues(alpha: 0.3) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isListening
                  ? AppTheme.successColor.withValues(alpha: 0.2)
                  : AppTheme.cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isListening ? Icons.mic_rounded : Icons.touch_app_rounded,
              color: _isListening ? AppTheme.successColor : AppTheme.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isListening ? 'Listening...' : 'Voice Ready',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _isListening ? AppTheme.successColor : AppTheme.textColor,
                      ),
                ),
                Text(
                  _recognizedText.isNotEmpty ? '"$_recognizedText"' : 'Say a command or tap',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_isListening)
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.successColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuList() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: _menuItems.length,
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          final isSelected = index == _selectedIndex;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () => _onItemTap(index),
              onDoubleTap: () => _openScreen(index),
              child: _MenuCard(item: item, isSelected: isSelected),
            ),
          );
        },
      ),
    );
  }
}

class MenuItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  MenuItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _MenuCard extends StatelessWidget {
  final MenuItem item;
  final bool isSelected;

  const _MenuCard({required this.item, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${item.title}. ${item.description}. Double tap to open.',
      button: true,
      selected: isSelected,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.accentColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppTheme.accentColor.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(item.icon, size: 30, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accentColor : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSelected ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: isSelected ? AppTheme.backgroundColor : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
