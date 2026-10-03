import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_fallbeispiel/Screens/resuscitation_screen.dart';
import 'package:rd_fallbeispiel/measure_requirements.dart';
import 'package:rd_fallbeispiel/models/cpr_summary.dart';
import 'package:rd_fallbeispiel/models/medication.dart';
import 'package:rd_fallbeispiel/models/resuscitation_notes.dart';
import 'package:rd_fallbeispiel/models/session_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

MedicationAdministration _gabe(Medication m, DateTime t) =>
    MedicationAdministration(medication: m, dose: 'x', route: 'i.v.', timestamp: t);

Widget _resus(Qualification q) => MaterialApp(
      home: ResuscitationScreen(
        vehicleStatus: const {},
        vehicleArrivalMinutes: const {},
        isChildResuscitation: false,
        userQualification: q,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Katalog', () {
    test('enthält nur Medikamente, kein Verbrauchsmaterial', () {
      const material = [
        'spritze', 'kanüle', 'spike', 'mad', 'nasenapplikator',
        'combistopper', 'tupfer', 'abwurf', 'etikett', 'ampullenöffner',
        'edding', 'aqua',
      ];
      for (final m in MedicationCatalog.all) {
        final text = '${m.wirkstoff} ${m.staerke}'.toLowerCase();
        for (final w in material) {
          expect(text.contains(w), isFalse, reason: '$text enthält $w');
        }
      }
    });

    test('Einträge sind eindeutig und Stärken werden unterschieden', () {
      final ids = MedicationCatalog.all.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(MedicationCatalog.search('midazolam'), hasLength(2));
      expect(MedicationCatalog.search('Adrenalin'), hasLength(2));
    });

    test('Suche findet Handelsnamen', () {
      expect(MedicationCatalog.search('suprarenin').single.wirkstoff,
          'Adrenalin');
      expect(MedicationCatalog.search('novalgin'), hasLength(1));
    });
  });

  group('Speicherung', () {
    test('Medikamente und Schocks überstehen JSON', () {
      final t = DateTime(2026, 1, 1, 10);
      final record = SessionRecord(
        id: '1',
        startTime: t,
        durationSeconds: 60,
        qualification: 'NFS',
        isResuscitation: true,
        completedCount: 0,
        missingCount: 0,
        medications: [_gabe(MedicationCatalog.adrenalin, t)],
        cpr: CprSummary(
          compressions: 1,
          ventilations: 0,
          averageBpm: 0,
          shockTimes: [t],
          startedAt: t,
        ),
      );
      final back = SessionRecord.fromJson(
          json.decode(json.encode(record.toJson())) as Map<String, dynamic>);
      expect(back.medications!.single.medication.label,
          'Adrenalin 1 mg / 1 ml');
      expect(back.medications!.single.route, 'i.v.');
      expect(back.cpr!.shocks, 1);
      expect(back.cpr!.startedAt, t);
    });

    test('ältere Einträge ohne Medikamente bleiben lesbar', () {
      final back = SessionRecord.fromJson({
        'id': '1',
        'startTime': DateTime(2026).toIso8601String(),
        'durationSeconds': 1,
        'qualification': 'RS',
        'isResuscitation': true,
        'completedCount': 0,
        'missingCount': 0,
        'cpr': {'compressions': 1, 'ventilations': 0, 'averageBpm': 0},
      });
      expect(back.medications, isNull);
      expect(back.cpr!.shocks, isNull);
    });
  });

  group('Reanimations-Hinweise', () {
    final start = DateTime(2026, 1, 1, 10);
    DateTime at(int s) => start.add(Duration(seconds: s));

    test('ohne Reanimationsbeginn keine Hinweise', () {
      expect(
          resuscitationMedicationNotes(
              medications: const [], shockTimes: const [],
              resuscitationStart: null),
          isEmpty);
    });

    test('erstes Adrenalin, Abstände und Amiodaron nach Schocks', () {
      final notes = resuscitationMedicationNotes(
        medications: [
          _gabe(MedicationCatalog.adrenalin, at(130)),
          _gabe(MedicationCatalog.adrenalin, at(130 + 240)),
          _gabe(MedicationCatalog.adrenalin, at(130 + 240 + 360)),
          _gabe(MedicationCatalog.amiodaron, at(500)),
        ],
        shockTimes: [at(60), at(180), at(300)],
        resuscitationStart: start,
      );
      expect(notes, contains('Schocks: 3'));
      expect(notes, contains('Adrenalin: 3× – erste Gabe 2:10 nach Reanimationsbeginn'));
      expect(notes, contains('Abstände Adrenalin: 4:00, 6:00 min (1× länger als 5 min)'));
      expect(notes, contains('Amiodaron: 1× – erste Gabe nach 3 Schocks'));
    });

    test('SAN/RH: nur der Schock-Hinweis, keine Medikamenten-Hinweise', () {
      final notes = resuscitationMedicationNotes(
        medications: const [],
        shockTimes: [at(10), at(20), at(30)],
        resuscitationStart: start,
        medicationsAllowed: false,
      );
      expect(notes, ['Schocks: 3']);
    });

    test('fehlendes Amiodaron ab 3 Schocks wird erwähnt', () {
      final notes = resuscitationMedicationNotes(
        medications: const [],
        shockTimes: [at(10), at(20), at(30)],
        resuscitationStart: start,
      );
      expect(notes, contains('Kein Adrenalin dokumentiert'));
      expect(notes, contains('Kein Amiodaron dokumentiert trotz 3 Schocks'));
    });
  });

  group('Reanimations-Screen', () {
    testWidgets('Schock zählt mit und hakt Defibrillation einmal ab',
        (tester) async {
      // Smartphone hochkant (Standardgröße im Test wäre Querformat)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_resus(Qualification.SAN));
      await tester.pump();
      await tester.tap(find.text('Schock'));
      await tester.pump();
      await tester.tap(find.text('Schock (1)'));
      await tester.pump();
      expect(find.text('Schock (2)'), findsOneWidget);
      // SAN darf keine Medikamente dokumentieren
      expect(find.text('Adrenalin'), findsNothing);
      expect(find.text('Medikamente'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Adrenalin per Schnellzugriff dokumentieren', (tester) async {
      // Smartphone hochkant (Standardgröße im Test wäre Querformat)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_resus(Qualification.NFS));
      await tester.pump();
      await tester.tap(find.text('Adrenalin'));
      await tester.pumpAndSettle();
      // Dosis wird nie vorbelegt
      final confirm = find.widgetWithText(FilledButton, 'Dokumentieren');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byType(TextField), '1 mg');
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Medikamente (1)'), findsOneWidget);
      expect(find.text('Adrenalin 1 mg'), findsOneWidget);
      expect(find.textContaining('Letztes Adrenalin vor'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
