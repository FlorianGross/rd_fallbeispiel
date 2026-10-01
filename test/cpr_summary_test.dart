import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_fallbeispiel/Screens/result_screen.dart';
import 'package:rd_fallbeispiel/measure_requirements.dart';
import 'package:rd_fallbeispiel/models/cpr_summary.dart';
import 'package:rd_fallbeispiel/models/session_record.dart';
import 'package:rd_fallbeispiel/widgets/bpm_chart.dart';

void main() {
  final start = DateTime(2026, 10, 1, 12);
  List<Map<String, dynamic>> history(List<double> values) => [
        for (var i = 0; i < values.length; i++)
          {
            'timestamp': start.add(Duration(milliseconds: 550 * (i + 1))),
            'bpm': values[i],
          },
      ];

  group('CprSummary', () {
    test('Mittelwert und Anteil im Zielbereich', () {
      final s = CprSummary.fromHistory(
        compressions: 4,
        ventilations: 2,
        bpmHistory: history([90, 105, 115, 130]),
      );
      expect(s.averageBpm, 110);
      expect(s.targetShare, 0.5);
    });

    test('ohne Messung kein Anteil', () {
      final s = CprSummary.fromHistory(
          compressions: 1, ventilations: 0, bpmHistory: const []);
      expect(s.averageBpm, 0);
      expect(s.targetShare, isNull);
    });

    test('wird mit der Sitzung gespeichert', () {
      final r = SessionRecord(
        id: '1',
        startTime: start,
        durationSeconds: 60,
        qualification: 'RS',
        isResuscitation: true,
        completedCount: 0,
        missingCount: 0,
        cpr: const CprSummary(
            compressions: 120, ventilations: 8, averageBpm: 108.5,
            targetShare: 0.75),
      );
      final restored = SessionRecord.fromJson(r.toJson());
      expect(restored.cpr!.compressions, 120);
      expect(restored.cpr!.targetShare, 0.75);
      expect(SessionRecord.fromJson(r.toJson()..remove('cpr')).cpr, isNull);
    });
  });

  testWidgets('Auswertung zeigt Reanimations-Kennzahlen und Verlauf',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MeasuresOverviewScreen(
        completedActions: const [],
        missingActions: const [],
        userQualification: Qualification.RS,
        bpmHistory: history([110, 112, 95]),
        ventilationHistory: [
          {'timestamp': start.add(const Duration(seconds: 3)), 'count': 1},
        ],
        compressionCount: 4,
        ventilationCount: 1,
        resuscitationStart: start,
      ),
    ));
    await tester.tap(find.text('Auswertung'));
    await tester.pumpAndSettle();

    expect(find.text('Reanimation'), findsOneWidget);
    expect(find.text('106/min'), findsOneWidget);
    expect(find.text('67 %'), findsOneWidget);
    expect(find.text('mäßig'), findsOneWidget);
    expect(find.byType(BpmChart), findsOneWidget);
  });

  testWidgets('aus dem Verlauf: Kennzahlen ohne Diagramm', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MeasuresOverviewScreen(
        completedActions: [],
        missingActions: [],
        userQualification: Qualification.RS,
        cprSummary: CprSummary(
            compressions: 300, ventilations: 20, averageBpm: 112,
            targetShare: 0.9),
        fromHistory: true,
      ),
    ));
    await tester.tap(find.text('Auswertung'));
    await tester.pumpAndSettle();
    expect(find.text('300'), findsOneWidget);
    expect(find.text('gut'), findsOneWidget);
    expect(find.byType(BpmChart), findsNothing);
  });
}
