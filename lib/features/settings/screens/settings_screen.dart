import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/models/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

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
    await _tts.speak(
      'Settings screen. '
      'Adjust text to speech, vibration, and battery settings. '
      'Swipe down to go back.'
    );
  }

  Future<void> _updateSettings(AppSettings newSettings) async {
    setState(() {
      _settings = newSettings;
    });
    await _settingsService.saveSettings(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          iconSize: 35,
          onPressed: () async {
            await _tts.speak('Going back');
            Navigator.pop(context);
          },
        ),
      ),
      body: GestureDetector(
        onVerticalDragEnd: (details) async {
          if (details.primaryVelocity! > 0) {
            await _tts.speak('Going back');
            Navigator.pop(context);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // TTS Settings Section
            _buildSectionHeader('Text-to-Speech'),
            _buildSliderSetting(
              'Speech Rate',
              _settings.speechRate,
              0.1,
              1.0,
              (value) async {
                await _updateSettings(_settings.copyWith(speechRate: value));
                await _tts.speak('Speech rate adjusted');
              },
            ),
            _buildSliderSetting(
              'Pitch',
              _settings.pitch,
              0.5,
              2.0,
              (value) async {
                await _updateSettings(_settings.copyWith(pitch: value));
                await _tts.speak('Pitch adjusted');
              },
            ),
            _buildSliderSetting(
              'Volume',
              _settings.volume,
              0.0,
              1.0,
              (value) async {
                await _updateSettings(_settings.copyWith(volume: value));
                await _tts.speak('Volume adjusted');
              },
            ),

            const SizedBox(height: 30),

            // Vibration Settings Section
            _buildSectionHeader('Vibration'),
            _buildSwitchSetting(
              'Vibration Enabled',
              _settings.vibrationEnabled,
              (value) async {
                await _updateSettings(_settings.copyWith(vibrationEnabled: value));
                if (value && await Vibration.hasVibrator() == true) {
                  Vibration.vibrate(duration: 100);
                }
                await _tts.speak(value ? 'Vibration enabled' : 'Vibration disabled');
              },
            ),
            if (_settings.vibrationEnabled)
              _buildIntensitySetting(),

            const SizedBox(height: 30),

            // Battery Optimization Section
            _buildSectionHeader('Battery Optimization'),
            _buildSwitchSetting(
              'Battery Saver Mode',
              _settings.batterySaverMode,
              (value) async {
                await _updateSettings(_settings.copyWith(batterySaverMode: value));
                await _tts.speak(value 
                    ? 'Battery saver enabled. GPS and camera quality will be reduced.' 
                    : 'Battery saver disabled');
              },
            ),
            _buildSwitchSetting(
              'Auto-Stop Camera',
              _settings.autoStopCamera,
              (value) async {
                await _updateSettings(_settings.copyWith(autoStopCamera: value));
                await _tts.speak(value 
                    ? 'Camera will auto-stop when battery is low' 
                    : 'Camera will not auto-stop');
              },
            ),
            _buildSwitchSetting(
              'Reduced GPS Accuracy',
              _settings.reducedGPSAccuracy,
              (value) async {
                await _updateSettings(_settings.copyWith(reducedGPSAccuracy: value));
                await _tts.speak(value 
                    ? 'GPS accuracy reduced to save battery' 
                    : 'GPS accuracy set to high');
              },
            ),

            const SizedBox(height: 30),

            // Voice Control Section removed (headset button feature deprecated)

            // Test TTS Button
            _buildTestButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: AppTheme.accentColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSliderSetting(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return GestureDetector(
      onTap: () async {
        await _tts.speak('$label. Current value ${value.toStringAsFixed(2)}');
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    value.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Slider(
                value: value,
                min: min,
                max: max,
                divisions: 20,
                activeColor: AppTheme.accentColor,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchSetting(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return GestureDetector(
      onTap: () async {
        await _tts.speak('$label. Currently ${value ? "enabled" : "disabled"}. Double tap to toggle.');
      },
      onDoubleTap: () => onChanged(!value),
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: value,
                activeColor: AppTheme.accentColor,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntensitySetting() {
    return GestureDetector(
      onTap: () async {
        final intensity = ['Low', 'Medium', 'High'][_settings.vibrationIntensity - 1];
        await _tts.speak('Vibration intensity. Currently $intensity');
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vibration Intensity',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildIntensityButton('Low', 1),
                  _buildIntensityButton('Medium', 2),
                  _buildIntensityButton('High', 3),
                ],
              ),
            ],
          ),
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
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentColor : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.accentColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        await _tts.speak(
          'This is a test of your text to speech settings. '
          'The quick brown fox jumps over the lazy dog.'
        );
      },
      icon: const Icon(Icons.volume_up, size: 30),
      label: const Text('Test Voice Settings'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.successColor,
        minimumSize: const Size(double.infinity, 70),
      ),
    );
  }
}
