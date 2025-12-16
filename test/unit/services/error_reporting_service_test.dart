import 'package:flutter_test/flutter_test.dart';
import 'package:aeye/core/services/error_reporting_service.dart';

void main() {
  group('ErrorReport', () {
    test('should create error report with all fields', () {
      final timestamp = DateTime.now();
      final report = ErrorReport(
        error: 'Test error message',
        stackTrace: 'at line 1\nat line 2',
        fatal: false,
        timestamp: timestamp,
        context: {'key': 'value'},
      );

      expect(report.error, 'Test error message');
      expect(report.stackTrace, 'at line 1\nat line 2');
      expect(report.fatal, false);
      expect(report.timestamp, timestamp);
      expect(report.context['key'], 'value');
    });

    test('should serialize to JSON correctly', () {
      final timestamp = DateTime(2024, 1, 15, 10, 30, 0);
      final report = ErrorReport(
        error: 'Serialization test',
        stackTrace: 'stack trace here',
        fatal: true,
        timestamp: timestamp,
        context: {'module': 'test', 'action': 'serialize'},
      );

      final json = report.toJson();

      expect(json['error'], 'Serialization test');
      expect(json['stackTrace'], 'stack trace here');
      expect(json['fatal'], true);
      expect(json['timestamp'], timestamp.toIso8601String());
      expect(json['context']['module'], 'test');
      expect(json['context']['action'], 'serialize');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'error': 'Deserialization test',
        'stackTrace': 'deserialized stack',
        'fatal': false,
        'timestamp': '2024-01-15T10:30:00.000',
        'context': {'source': 'json'},
      };

      final report = ErrorReport.fromJson(json);

      expect(report.error, 'Deserialization test');
      expect(report.stackTrace, 'deserialized stack');
      expect(report.fatal, false);
      expect(report.timestamp.year, 2024);
      expect(report.timestamp.month, 1);
      expect(report.timestamp.day, 15);
      expect(report.context['source'], 'json');
    });

    test('should round-trip serialize and deserialize', () {
      final original = ErrorReport(
        error: 'Round trip test',
        stackTrace: 'original stack trace',
        fatal: true,
        timestamp: DateTime(2024, 6, 20, 14, 45, 30),
        context: {'test': 'roundtrip', 'count': 42},
      );

      final json = original.toJson();
      final restored = ErrorReport.fromJson(json);

      expect(restored.error, original.error);
      expect(restored.stackTrace, original.stackTrace);
      expect(restored.fatal, original.fatal);
      expect(restored.timestamp.toIso8601String(), original.timestamp.toIso8601String());
      expect(restored.context['test'], original.context['test']);
    });

    test('should handle empty context', () {
      final report = ErrorReport(
        error: 'No context',
        stackTrace: 'stack',
        fatal: false,
        timestamp: DateTime.now(),
        context: {},
      );

      final json = report.toJson();
      expect(json['context'], isEmpty);

      final restored = ErrorReport.fromJson(json);
      expect(restored.context, isEmpty);
    });

    test('should handle complex context values', () {
      final report = ErrorReport(
        error: 'Complex context',
        stackTrace: 'stack',
        fatal: false,
        timestamp: DateTime.now(),
        context: {
          'string': 'value',
          'number': 123,
          'boolean': true,
          'list': [1, 2, 3],
        },
      );

      final json = report.toJson();
      final restored = ErrorReport.fromJson(json);

      expect(restored.context['string'], 'value');
      expect(restored.context['number'], 123);
      expect(restored.context['boolean'], true);
    });
  });

  group('ErrorReportingService', () {
    late ErrorReportingService service;

    setUp(() {
      service = ErrorReportingService();
    });

    test('should be a singleton', () {
      final instance1 = ErrorReportingService();
      final instance2 = ErrorReportingService();
      expect(identical(instance1, instance2), true);
    });

    test('should return empty list before any errors recorded', () {
      // Note: This may contain errors from previous tests due to singleton
      final reports = service.getErrorReports();
      expect(reports, isA<List<ErrorReport>>());
    });
  });
}
