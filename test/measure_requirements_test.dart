import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rd_fallbeispiel/measure_requirements.dart';
import 'package:rd_fallbeispiel/models/session_record.dart';
import 'package:rd_fallbeispiel/services/history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

CompletedAction _done(String schema, String action) => CompletedAction(
      schema: schema,
      action: action,
      timestamp: DateTime(2026),
    );

List<CompletedAction> _allOf(String schema) => MeasureRequirements
    .getActionsForSchema(schema)
    .map((a) => _done(schema, a))
    .toList();

void main() {
  group('calculateMissingRequiredActions', () {
    test('Reanimation bewertet nur CPR-relevante Schemata', () {
      final missing = MeasureRequirements.calculateMissingRequiredActions(
        [],
        Qualification.RS,
        onlySchemas: MeasureRequirements.resuscitationSchemas,
      );
      expect(missing, isNotEmpty);
      expect(
        missing.every(
            (m) => MeasureRequirements.resuscitationSchemas.contains(m.schema)),
        isTrue,
      );
      expect(missing.any((m) => m.schema == 'SAMPLERS'), isFalse);
    });

    test('ohne Filter werden alle Schemata bewertet', () {
      final missing = MeasureRequirements.calculateMissingRequiredActions(
          [], Qualification.RS);
      expect(missing.any((m) => m.schema == 'SAMPLERS'), isTrue);
    });
  });

  group('isSchemaComplete', () {
    test('offene optionale Maßnahmen blockieren den Abschluss nicht', () {
      // 'Maßnahmen' enthält nur optionale/erwartete Punkte; für SAN sind
      // Sauerstoffgabe und Wärmeerhalt optional.
      expect(
        MeasureRequirements.isSchemaComplete('Maßnahmen', [], Qualification.SAN),
        isTrue,
      );
    });

    test('erwartete Maßnahmen müssen erledigt sein', () {
      expect(
        MeasureRequirements.isSchemaComplete('Maßnahmen', [], Qualification.RS),
        isFalse,
      );
      expect(
        MeasureRequirements.isSchemaComplete(
          'Maßnahmen',
          [
            _done('Maßnahmen', 'Sauerstoffgabe'),
            _done('Maßnahmen', 'Wärmeerhalt'),
          ],
          Qualification.RS,
        ),
        isTrue,
      );
    });

    test('Schema mit allen Pflichtpunkten ist abgeschlossen', () {
      expect(
        MeasureRequirements.isSchemaComplete(
            'SSSS', _allOf('SSSS'), Qualification.SAN),
        isTrue,
      );
    });
  });

  group('countCompletedRequiredActions', () {
    test('optionale Maßnahmen zählen nicht zur Pflichtquote', () {
      final count = MeasureRequirements.countCompletedRequiredActions(
        [
          _done('SSSS', 'Scene'),
          _done('4H', 'Hypoxie'), // optional
          _done('Nachforderung', 'NEF'), // optional
        ],
        Qualification.RS,
      );
      expect(count, 1);
    });

    test('respektiert den Schema-Filter', () {
      final count = MeasureRequirements.countCompletedRequiredActions(
        [_done('SSSS', 'Scene'), _done('SAMPLERS', 'Allergien')],
        Qualification.RS,
        onlySchemas: MeasureRequirements.resuscitationSchemas,
      );
      expect(count, 1);
    });
  });

  group('SessionRecord', () {
    SessionRecord record({int? requiredDone}) => SessionRecord(
          id: '1',
          startTime: DateTime(2026, 10, 1, 12),
          durationSeconds: 125,
          qualification: 'RS',
          isResuscitation: false,
          completedCount: 10,
          missingCount: 5,
          requiredCompletedCount: requiredDone,
        );

    test('Quote basiert auf Pflichtmaßnahmen', () {
      expect(record(requiredDone: 5).completionRate, 50);
    });

    test('alte Einträge ohne Pflichtzähler fallen auf completedCount zurück',
        () {
      final json = record().toJson()..remove('requiredCompletedCount');
      final restored = SessionRecord.fromJson(json);
      expect(restored.requiredCompletedCount, isNull);
      expect(restored.completionRate, closeTo(66.7, 0.1));
    });

    test('JSON-Roundtrip', () {
      final restored = SessionRecord.fromJson(record(requiredDone: 3).toJson());
      expect(restored.requiredCompletedCount, 3);
      expect(restored.formattedDuration, '02:05');
    });
  });

  group('HistoryService', () {
    test('kaputtes JSON führt zu leerem Verlauf statt Absturz', () async {
      SharedPreferences.setMockInitialValues(
          {'session_history_v1': '{kein json'});
      expect(await HistoryService.loadHistory(), isEmpty);
    });

    test('ungültige Einträge werden übersprungen', () async {
      final valid = SessionRecord(
        id: 'ok',
        startTime: DateTime(2026),
        durationSeconds: 1,
        qualification: 'RS',
        isResuscitation: false,
        completedCount: 1,
        missingCount: 0,
      ).toJson();
      SharedPreferences.setMockInitialValues({
        'session_history_v1': json.encode([
          valid,
          {'id': 42},
        ]),
      });
      final history = await HistoryService.loadHistory();
      expect(history.map((s) => s.id), ['ok']);
    });
  });
}
