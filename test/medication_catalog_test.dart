import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_fallbeispiel/Screens/medication_catalog_screen.dart';
import 'package:rd_fallbeispiel/models/medication.dart';
import 'package:rd_fallbeispiel/services/medication_catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MedicationCatalog.current = MedicationCatalog.all;
  });

  group('MedicationCatalogService', () {
    test('ohne Anpassung gilt der Standard-Katalog', () async {
      await MedicationCatalogService.load();
      expect(MedicationCatalog.current, MedicationCatalog.all);
      expect(await MedicationCatalogService.isCustomized(), isFalse);
    });

    test('Anpassung wird gespeichert und wieder geladen', () async {
      const eigen = Medication(wirkstoff: 'Ketamin', staerke: '100 mg / 2 ml');
      await MedicationCatalogService.save([eigen]);
      MedicationCatalog.current = MedicationCatalog.all;

      await MedicationCatalogService.load();
      expect(MedicationCatalog.current.single.label, 'Ketamin 100 mg / 2 ml');
      expect(MedicationCatalog.search('keta'), hasLength(1));
      expect(MedicationCatalog.search('adrenalin'), isEmpty);
    });

    test('Zurücksetzen stellt den Standard wieder her', () async {
      await MedicationCatalogService.save(const []);
      await MedicationCatalogService.reset();
      await MedicationCatalogService.load();
      expect(MedicationCatalog.current, MedicationCatalog.all);
      expect(await MedicationCatalogService.isCustomized(), isFalse);
    });

    test('beschädigte Daten führen zum Standard statt zum Absturz', () async {
      SharedPreferences.setMockInitialValues(
          {'medication_catalog_v1': '{kein json'});
      await MedicationCatalogService.load();
      expect(MedicationCatalog.current, MedicationCatalog.all);
    });
  });

  group('MedicationCatalogScreen', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: MedicationCatalogScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('Medikament hinzufügen', (tester) async {
      await open(tester);
      await tester.tap(find.text('Medikament'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Speichern');
      expect(tester.widget<FilledButton>(save).onPressed, isNull,
          reason: 'Wirkstoff und Stärke sind Pflicht');

      await tester.enterText(
          find.widgetWithText(TextField, 'Wirkstoff *'), 'Ketamin');
      await tester.enterText(
          find.widgetWithText(TextField, 'Stärke / Packung *'), '100 mg / 2 ml');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(MedicationCatalog.current.any((m) => m.wirkstoff == 'Ketamin'),
          isTrue);
      expect(await MedicationCatalogService.isCustomized(), isTrue);
    });

    testWidgets('doppelte Einträge werden abgelehnt', (tester) async {
      await open(tester);
      await tester.tap(find.text('Medikament'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Wirkstoff *'), 'Adrenalin');
      await tester.enterText(
          find.widgetWithText(TextField, 'Stärke / Packung *'), '1 mg / 1 ml');
      await tester.pump();
      expect(find.text('Diesen Wirkstoff gibt es in dieser Stärke schon'),
          findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Speichern'))
              .onPressed,
          isNull);
    });
  });
}
