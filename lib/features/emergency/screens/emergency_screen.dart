import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/models/app_settings.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({Key? key}) : super(key: key);

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final TTSService _tts = TTSService();
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _announceScreen();
  }

  Future<void> _announceScreen() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final contactCount = _settingsService.settings.emergencyContacts.length;
    await _tts.speak(
      'Emergency screen. '
      'You have $contactCount emergency contact${contactCount != 1 ? "s" : ""}. '
      'Tap SOS button to call emergency services. '
      'Tap a contact to call them. '
      'Swipe down to go back.'
    );
  }

  Future<void> _callEmergency() async {
    // Vibrate for emergency
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 200]);
    }

    await _tts.speak('Calling emergency services');
    
    // Call emergency number (911 in US, 112 in EU, etc.)
    final Uri phoneUri = Uri(scheme: 'tel', path: '911');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      await _tts.speak('Unable to make emergency call');
    }
  }

  Future<void> _callContact(EmergencyContact contact) async {
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(duration: 150);
    }

    await _tts.speak('Calling ${contact.name}');
    
    final Uri phoneUri = Uri(scheme: 'tel', path: contact.phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      await _tts.speak('Unable to call ${contact.name}');
    }
  }

  Future<void> _sendLocationSMS(EmergencyContact contact) async {
    // Location feature removed - send emergency message without location
    await _tts.speak('Preparing emergency message for ${contact.name}');

    try {
      final message = 'EMERGENCY! I need help. Please call me immediately.';

      final Uri smsUri = Uri(
        scheme: 'sms',
        path: contact.phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        await _tts.speak('Emergency message prepared for ${contact.name}');
      } else {
        await _tts.speak('Unable to send message');
      }
    } catch (e) {
      print('Error sending SMS: $e');
      await _tts.speak('Error sending message');
    }
  }

  Future<void> _showContactOptions(EmergencyContact contact) async {
    await _tts.speak(
      '${contact.name}. '
      'Tap once to call. '
      'Double tap to send location message.'
    );
  }

  void _navigateToManageContacts() async {
    await _tts.speak('Opening emergency contacts management');
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ManageContactsScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _settingsService.settings.emergencyContacts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency'),
        backgroundColor: AppTheme.errorColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          iconSize: 35,
          onPressed: () async {
            await _tts.speak('Going back');
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            iconSize: 35,
            onPressed: _navigateToManageContacts,
          ),
        ],
      ),
      body: GestureDetector(
        onVerticalDragEnd: (details) async {
          if (details.primaryVelocity! > 0) {
            await _tts.speak('Going back');
            Navigator.pop(context);
          }
        },
        child: Column(
          children: [
            // SOS Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: GestureDetector(
                onTap: () async {
                  await _tts.speak('SOS button. Double tap to call emergency services.');
                },
                onDoubleTap: _callEmergency,
                child: Container(
                  height: 160,  // Reduced from 200
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.errorColor.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emergency,
                        size: 64,  // Reduced from 80
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),  // Reduced from 15
                      Text(
                        'SOS',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Double tap to call 911',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Emergency Contacts List
            Expanded(
              child: contacts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person_add_outlined,
                              size: 80,
                              color: AppTheme.accentColor,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No Emergency Contacts',
                              style: Theme.of(context).textTheme.headlineMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tap the + button to add contacts',
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        return _buildContactCard(contact);
                      },
                    ),
            ),


          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact) {
    return GestureDetector(
      onTap: () => _showContactOptions(contact),
      onDoubleTap: () => _callContact(contact),
      onLongPress: () => _sendLocationSMS(contact),
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
        color: contact.isPrimary ? AppTheme.primaryColor : AppTheme.surfaceColor,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 35,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          contact.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (contact.isPrimary) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'PRIMARY',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      contact.phoneNumber,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.phone,
                size: 35,
                color: AppTheme.successColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Manage Contacts Screen
class ManageContactsScreen extends StatefulWidget {
  const ManageContactsScreen({Key? key}) : super(key: key);

  @override
  State<ManageContactsScreen> createState() => _ManageContactsScreenState();
}

class _ManageContactsScreenState extends State<ManageContactsScreen> {
  final TTSService _tts = TTSService();
  final SettingsService _settingsService = SettingsService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _announceScreen();
  }

  Future<void> _announceScreen() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _tts.speak('Manage emergency contacts. Add or remove contacts.');
  }

  Future<void> _addContact() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      await _tts.speak('Please enter both name and phone number');
      return;
    }

    final contact = EmergencyContact(
      name: _nameController.text,
      phoneNumber: _phoneController.text,
      isPrimary: _settingsService.settings.emergencyContacts.isEmpty,
    );

    await _settingsService.addEmergencyContact(contact);
    await _tts.speak('${contact.name} added as emergency contact');

    _nameController.clear();
    _phoneController.clear();
    setState(() {});
  }

  Future<void> _removeContact(int index) async {
    final contact = _settingsService.settings.emergencyContacts[index];
    await _settingsService.removeEmergencyContact(index);
    await _tts.speak('${contact.name} removed');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _settingsService.settings.emergencyContacts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Contacts'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Column(
        children: [
          // Add Contact Form
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(fontSize: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: TextStyle(fontSize: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: _addContact,
                  icon: const Icon(Icons.add, size: 30),
                  label: const Text('Add Contact'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    minimumSize: const Size(double.infinity, 60),
                  ),
                ),
              ],
            ),
          ),

          // Contacts List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.person, size: 35),
                    title: Text(
                      contact.name,
                      style: const TextStyle(fontSize: 18),
                    ),
                    subtitle: Text(
                      contact.phoneNumber,
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 30),
                      color: AppTheme.errorColor,
                      onPressed: () => _removeContact(index),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
