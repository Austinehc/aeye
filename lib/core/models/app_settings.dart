class AppSettings {
  // TTS Settings
  final double speechRate;
  final double pitch;
  final double volume;
  
  // Vibration Settings
  final bool vibrationEnabled;
  final int vibrationIntensity; // 1-3 (low, medium, high)
  
  // Battery Optimization
  final bool batterySaverMode;
  final bool autoStopCamera;
  final bool reducedGPSAccuracy;
  
  // Emergency Contacts
  final List<EmergencyContact> emergencyContacts;
  
  // Map Settings
  final bool offlineMapsEnabled;
  final int maxCachedTiles;
  
  // Headset Button
  final bool headsetButtonEnabled;

  const AppSettings({
    this.speechRate = 0.5,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.vibrationEnabled = true,
    this.vibrationIntensity = 2,
    this.batterySaverMode = false,
    this.autoStopCamera = true,
    this.reducedGPSAccuracy = false,
    this.emergencyContacts = const [],
    this.offlineMapsEnabled = true,
    this.maxCachedTiles = 500,
    this.headsetButtonEnabled = true,
  });

  AppSettings copyWith({
    double? speechRate,
    double? pitch,
    double? volume,
    bool? vibrationEnabled,
    int? vibrationIntensity,
    bool? batterySaverMode,
    bool? autoStopCamera,
    bool? reducedGPSAccuracy,
    List<EmergencyContact>? emergencyContacts,
    bool? offlineMapsEnabled,
    int? maxCachedTiles,
    bool? headsetButtonEnabled,
  }) {
    return AppSettings(
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      vibrationIntensity: vibrationIntensity ?? this.vibrationIntensity,
      batterySaverMode: batterySaverMode ?? this.batterySaverMode,
      autoStopCamera: autoStopCamera ?? this.autoStopCamera,
      reducedGPSAccuracy: reducedGPSAccuracy ?? this.reducedGPSAccuracy,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      offlineMapsEnabled: offlineMapsEnabled ?? this.offlineMapsEnabled,
      maxCachedTiles: maxCachedTiles ?? this.maxCachedTiles,
      headsetButtonEnabled: headsetButtonEnabled ?? this.headsetButtonEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speechRate': speechRate,
      'pitch': pitch,
      'volume': volume,
      'vibrationEnabled': vibrationEnabled,
      'vibrationIntensity': vibrationIntensity,
      'batterySaverMode': batterySaverMode,
      'autoStopCamera': autoStopCamera,
      'reducedGPSAccuracy': reducedGPSAccuracy,
      'emergencyContacts': emergencyContacts.map((e) => e.toJson()).toList(),
      'offlineMapsEnabled': offlineMapsEnabled,
      'maxCachedTiles': maxCachedTiles,
      'headsetButtonEnabled': headsetButtonEnabled,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      speechRate: json['speechRate'] ?? 0.5,
      pitch: json['pitch'] ?? 1.0,
      volume: json['volume'] ?? 1.0,
      vibrationEnabled: json['vibrationEnabled'] ?? true,
      vibrationIntensity: json['vibrationIntensity'] ?? 2,
      batterySaverMode: json['batterySaverMode'] ?? false,
      autoStopCamera: json['autoStopCamera'] ?? true,
      reducedGPSAccuracy: json['reducedGPSAccuracy'] ?? false,
      emergencyContacts: (json['emergencyContacts'] as List<dynamic>?)
              ?.map((e) => EmergencyContact.fromJson(e))
              .toList() ??
          [],
      offlineMapsEnabled: json['offlineMapsEnabled'] ?? true,
      maxCachedTiles: json['maxCachedTiles'] ?? 500,
      headsetButtonEnabled: json['headsetButtonEnabled'] ?? true,
    );
  }
}

class EmergencyContact {
  final String name;
  final String phoneNumber;
  final bool isPrimary;

  const EmergencyContact({
    required this.name,
    required this.phoneNumber,
    this.isPrimary = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'isPrimary': isPrimary,
    };
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      isPrimary: json['isPrimary'] ?? false,
    );
  }
}
