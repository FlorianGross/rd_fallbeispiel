import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_fallbeispiel/Screens/history_screen.dart';
import 'package:rd_fallbeispiel/Screens/result_screen.dart';
import 'package:rd_fallbeispiel/measure_requirements.dart';
import 'package:rd_fallbeispiel/models/session_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

SessionRecord _session(String id, {bool details = true}) => SessionRecord(
      id: id,
      startTime: DateTime(2026, 9, int.parse(id), 12),
      durationSeconds: 300,
      qualification: 'RS',
      isResuscitation: false,
      completedCount: 1,
      missingCount: 1,
      scenarioName: 'Fall $id',
      notes: 'Notiz $id',
      completedActions: details
          ? [
              CompletedAction(
                  schema: 'SSSS',
                  action: 'Scene',
                  timestamp: DateTime(2026, 9, 1, 12, 1)),
            ]
          : null,
      missingActions: details
          ? const [
              MissingAction(
                  schema: 'D',
                  action: 'BZ',
                  requirementLevel: RequirementLevel.required),
            ]
          : null,
    );

Future<void> _pumpHistory(WidgetTester tester, List<SessionRecord> s) async {
  SharedPreferences.setMockInitialValues({
    'session_history_v1': json.encode(s.map((e) => e.toJson()).toList()),
  });
  await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('zeigt häufig vergessene Pflichtmaßnahmen', (tester) async {
    await _pumpHistory(tester, [_session('1'), _session('2')]);
    expect(find.text('Häufig vergessen'), findsOneWidget);
    expect(find.text('D – BZ'), findsOneWidget);
    expect(find.text('2× von 2'), findsOneWidget);
  });

  testWidgets('Details öffnen die Auswertung mit Notiz', (tester) async {
    await _pumpHistory(tester, [_session('1')]);
    await tester.tap(find.text('Fall 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.byType(MeasuresOverviewScreen), findsOneWidget);
    expect(find.text('Sitzung automatisch gespeichert'), findsNothing);
  });

  testWidgets('alte Einträge ohne Details haben keinen Details-Button',
      (tester) async {
    await _pumpHistory(tester, [_session('1', details: false)]);
    await tester.tap(find.text('Fall 1'));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsNothing);
    expect(find.text('Häufig vergessen'), findsNothing);
  });
}
