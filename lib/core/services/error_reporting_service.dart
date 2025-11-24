import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Error reporting service for tracking crashes and errors
/// In production, integrate with Firebase Crashlytics or Sentry
class ErrorReportingService {
  static final ErrorReportingService _instance = ErrorReportingService._internal();
  factory ErrorReportingService() => _instance;
  ErrorReportingService._internal();

  bool _isInitialized = false;
  final List<ErrorReport> _errorQueue = [];
  static const int _maxQueueSize = 50;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // In production, initialize Firebase Crashlytics here:
      // await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      
      // For now, we'll use local storage
      await _loadErrorQueue();
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✅ Error Reporting Service initialized (Local mode)');
        print('   In production, integrate Firebase Crashlytics or Sentry');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing error reporting: $e');
      }
    }
  }

  /// Record a Dart error
  void recordError(
    dynamic error,
    StackTrace? stackTrace, {
    bool fatal = false,
    Map<String, dynamic>? context,
  }) {
    if (!_isInitialized) return;

    final errorReport = ErrorReport(
      error: error.toString(),
      stackTrace: stackTrace?.toString() ?? 'No stack trace',
      fatal: fatal,
      timestamp: DateTime.now(),
      context: context ?? {},
    );

    _addToQueue(errorReport);

    // In production:
    // FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: fatal);

    if (kDebugMode) {
      print('🔴 Error recorded: ${fatal ? "FATAL" : "NON-FATAL"}');
      print('   Error: $error');
      if (stackTrace != null) {
        print('   Stack: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      }
    }
  }

  /// Record a Flutter framework error
  void recordFlutterError(FlutterErrorDetails details) {
    if (!_isInitialized) return;

    final errorReport = ErrorReport(
      error: details.exception.toString(),
      stackTrace: details.stack?.toString() ?? 'No stack trace',
      fatal: false,
      timestamp: DateTime.now(),
      context: {
        'library': details.library ?? 'unknown',
        'context': details.context?.toString() ?? 'unknown',
      },
    );

    _addToQueue(errorReport);

    // In production:
    // FirebaseCrashlytics.instance.recordFlutterFatalError(details);

    if (kDebugMode) {
      print('🔴 Flutter Error recorded');
      print('   Exception: ${details.exception}');
      print('   Library: ${details.library}');
    }
  }

  /// Log a custom message
  void log(String message, {Map<String, dynamic>? parameters}) {
    if (!_isInitialized) return;

    // In production:
    // FirebaseCrashlytics.instance.log(message);

    if (kDebugMode) {
      print('📝 Log: $message');
      if (parameters != null) {
        print('   Parameters: $parameters');
      }
    }
  }

  /// Set user identifier for crash reports
  void setUserIdentifier(String userId) {
    if (!_isInitialized) return;

    // In production:
    // FirebaseCrashlytics.instance.setUserIdentifier(userId);

    if (kDebugMode) {
      print('👤 User identifier set: $userId');
    }
  }

  /// Set custom key-value pairs
  void setCustomKey(String key, dynamic value) {
    if (!_isInitialized) return;

    // In production:
    // FirebaseCrashlytics.instance.setCustomKey(key, value);

    if (kDebugMode) {
      print('🔑 Custom key set: $key = $value');
    }
  }

  /// Get error reports (for debugging)
  List<ErrorReport> getErrorReports() {
    return List.unmodifiable(_errorQueue);
  }

  /// Clear error queue
  Future<void> clearErrors() async {
    _errorQueue.clear();
    await _saveErrorQueue();
  }

  // Private methods

  void _addToQueue(ErrorReport report) {
    _errorQueue.add(report);
    
    // Keep queue size manageable
    if (_errorQueue.length > _maxQueueSize) {
      _errorQueue.removeAt(0);
    }

    _saveErrorQueue();
  }

  Future<void> _loadErrorQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final errorData = prefs.getString('error_queue');
      
      if (errorData != null) {
        final List<dynamic> jsonList = jsonDecode(errorData);
        _errorQueue.clear();
        _errorQueue.addAll(
          jsonList.map((json) => ErrorReport.fromJson(json)).toList(),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading error queue: $e');
      }
    }
  }

  Future<void> _saveErrorQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _errorQueue.map((e) => e.toJson()).toList();
      await prefs.setString('error_queue', jsonEncode(jsonList));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving error queue: $e');
      }
    }
  }
}

/// Error report model
class ErrorReport {
  final String error;
  final String stackTrace;
  final bool fatal;
  final DateTime timestamp;
  final Map<String, dynamic> context;

  ErrorReport({
    required this.error,
    required this.stackTrace,
    required this.fatal,
    required this.timestamp,
    required this.context,
  });

  Map<String, dynamic> toJson() => {
        'error': error,
        'stackTrace': stackTrace,
        'fatal': fatal,
        'timestamp': timestamp.toIso8601String(),
        'context': context,
      };

  factory ErrorReport.fromJson(Map<String, dynamic> json) => ErrorReport(
        error: json['error'] as String,
        stackTrace: json['stackTrace'] as String,
        fatal: json['fatal'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
        context: Map<String, dynamic>.from(json['context'] as Map),
      );
}
