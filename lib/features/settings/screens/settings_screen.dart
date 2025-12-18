import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/models/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TTSService _tts = TTSService();
  final SettingsService _settingsService = SettingsService();
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.settings;
    _announceScreen();
  }

  Future<void> _announceScreen() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _tts.speak('Settings screen. Adjust voice, vibration, and battery settings.');
  }

  Future<void> _updateSettings(AppSettings newSettings) async {
    setState(() => _settings = newSettings);
    await _settingsService.saveSettings(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  _buildSectionHeader('Text-to-Speech'),
                  _buildSliderCard(
                    icon: Icons.speed_rounded,
                    label: 'Speech Rate',
                    value: _settings.speechRate,
                    min: 0.1,
                    max: 1.0,
                    onChanged: (value) async {
                      await _updateSettings(_settings.copyWith(speechRate: value));
                      await _tts.speak('Speech rate adjusted');
                    },
                  ),
                  _buildSliderCard(
                    icon: Icons.tune_rounded,
                    label: 'Pitch',
                    value: _settings.pitch,
                    min: 0.5,
                    max: 2.0,
                    onChanged: (value) async {
                      await _updateSettings(_settings.copyWith(pitch: value));
                      await _tts.speak('Pitch adjusted');
                    },
                  ),
                  _buildSliderCard(
                    icon: Icons.volume_up_rounded,
                    label: 'Volume',
                    value: _settings.volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (value) async {
                      await _updateSettings(_settings.copyWith(volume: value));
                      await _tts.speak('Volume adjusted');
                    },
                  ),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Vibration'),
                  _buildSwitchCard(
                    icon: Icons.vibration_rounded,
                    label: 'Vibration Enabled',
                    description: 'Haptic feedback for actions',
                    value: _settings.vibrationEnabled,
                    onChanged: (value) async {
                      await _updateSettings(_settings.copyWith(vibrationEnabled: value));
                      if (value && await Vibration.hasVibrator() == true) {
                        Vibration.vibrate(duration: 100);
                      }
                      await _tts.speak(value ? 'Vibration enabled' : 'Vibration disabled');
                    },
                  ),
                  if (_settings.vibrationEnabled) _buildIntensityCard(),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Battery Optimization'),
                  _buildSwitchCard(
                    icon: Icons.battery_saver_rounded,
                    label: 'Battery Saver Mode',
                    description: 'Reduce camera quality to save power',
                    value: _settings.batterySaverMode,
                    onChanged: (value) async {
                      await _updateSettings(_settings.copyWith(batterySaverMode: value));
                      await _tts.speak(value
                          ? 'Battery saver enabled'
                          : 'Battery saver disabled');
                    },
                  ),
                  _buildSwitchCard(
                    icon: Icons.camera_alt_rounded,
                    label: 'Auto-Stop Camera',
                    description: 'Stop camera when battery is low',
                    value: _settings.autoStopCamera,
                    onChanged: (value) async {
                      await _updateSettings(_settings.copyWith(autoStopCamera: value));
                      await _tts.speak(value
                          ? 'Camera will auto-stop when battery is low'
                          : 'Camera will not auto-stop');
                    },
                  ),

                  const SizedBox(height: 24),
                  _buildTestButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              await _tts.speak('Going back');
              if (mounted) Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
                Text('Customize your experience', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }


  Widget _buildSliderCard({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
  }) {
    return GestureDetector(
      onTap: () async {
        await _tts.speak('$label. Current value ${value.toStringAsFixed(1)}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: Theme.of(context).textTheme.titleLarge),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    value.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primaryColor,
                inactiveTrackColor: AppTheme.cardColor,
                thumbColor: AppTheme.primaryColor,
                overlayColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                trackHeight: 6,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: 20,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchCard({
    required IconData icon,
    required String label,
    required String description,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return GestureDetector(
      onTap: () async {
        await _tts.speak('$label. Currently ${value ? "enabled" : "disabled"}. Double tap to toggle.');
      },
      onDoubleTap: () => onChanged(!value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? AppTheme.successColor.withValues(alpha: 0.3) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: value
                    ? AppTheme.successColor.withValues(alpha: 0.2)
                    : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: value ? AppTheme.successColor : AppTheme.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeColor: AppTheme.successColor,
              activeTrackColor: AppTheme.successColor.withValues(alpha: 0.3),
              inactiveThumbColor: AppTheme.textSecondary,
              inactiveTrackColor: AppTheme.cardColor,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildIntensityCard() {
    return GestureDetector(
      onTap: () async {
        final intensity = ['Low', 'Medium', 'High'][_settings.vibrationIntensity - 1];
        await _tts.speak('Vibration intensity. Currently $intensity');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, color: AppTheme.accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Vibration Intensity', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildIntensityButton('Low', 1),
                const SizedBox(width: 10),
                _buildIntensityButton('Medium', 2),
                const SizedBox(width: 10),
                _buildIntensityButton('High', 3),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntensityButton(String label, int intensity) {
    final isSelected = _settings.vibrationIntensity == intensity;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          await _updateSettings(_settings.copyWith(vibrationIntensity: intensity));
          if (await Vibration.hasVibrator() == true) {
            final duration = _settingsService.getVibrationDuration(100);
            Vibration.vibrate(duration: duration);
          }
          await _tts.speak('$label intensity selected');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentColor : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.accentColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.backgroundColor : AppTheme.textColor,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestButton() {
    return GestureDetector(
      onTap: () async {
        await _tts.speak(
          'This is a test of your text to speech settings. '
          'The quick brown fox jumps over the lazy dog.',
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.successColor, Color(0xFF16A34A)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.successColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.volume_up_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              'Test Voice Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
