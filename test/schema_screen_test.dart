import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_fallbeispiel/Screens/normal_screen.dart';
import 'package:rd_fallbeispiel/Screens/resuscitation_screen.dart';
import 'package:rd_fallbeispiel/measure_requirements.dart';
import 'package:rd_fallbeispiel/models/scenario.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openScenario(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const SchemaSelectionScreen(
            vehicleStatus: {},
            vehicleArrivalMinutes: {},
            userQualification: Qualification.RS,
          ),
        )),
        child: const Text('Start'),
      ),
    ),
  ));
  await tester.tap(find.text('Start'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Zurück fragt nach und kann verwerfen', (tester) async {
    await _openScenario(tester);
    expect(find.byType(SchemaSelectionScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SchemaSelectionScreen), findsOneWidget,
        reason: 'Zurück darf das Szenario nicht direkt schließen');
    expect(find.text('Verwerfen'), findsOneWidget);

    await tester.tap(find.text('Verwerfen'));
    await tester.pumpAndSettle();
    expect(find.byType(SchemaSelectionScreen), findsNothing);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('Abbrechen im Zurück-Dialog lässt das Szenario offen',
      (tester) async {
    await _openScenario(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.byType(SchemaSelectionScreen), findsOneWidget);

    // Aufräumen, damit keine Timer offen bleiben
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Szenario zeigt Fallbild und markiert nicht bewertete Schemata',
      (tester) async {
    final stroke = PredefinedScenarios.scenarios
        .firstWhere((s) => s.name == 'Schlaganfall (Stroke)');
    await tester.pumpWidget(MaterialApp(
      home: SchemaSelectionScreen(
        vehicleStatus: const {},
        vehicleArrivalMinutes: const {},
        userQualification: Qualification.RS,
        scenario: stroke,
      ),
    ));
    await tester.pump();

    expect(find.text(stroke.name), findsOneWidget);
    await tester.tap(find.text('Fallbild anzeigen'));
    await tester.pumpAndSettle();
    expect(find.text(stroke.clinicalPicture), findsOneWidget);

    // STU und OPQRST werden beim Schlaganfall nicht bewertet
    await tester.scrollUntilVisible(find.text('STU'), 300,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    expect(find.text('Nicht bewertet in diesem Szenario'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Reanimation: Zeitstempel, Markierung und Zurück-Schutz',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ResuscitationScreen(
              vehicleStatus: {},
              vehicleArrivalMinutes: {},
              isChildResuscitation: false,
              userQualification: Qualification.RS,
            ),
          )),
          child: const Text('Start'),
        ),
      ),
    ));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SSSS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scene'));
    await tester.pump();
    expect(find.text('+00:00'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('SAMPLERS'), 300,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    expect(find.text('Nicht bewertet bei der Reanimation'), findsWidgets);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ResuscitationScreen), findsOneWidget);
    await tester.tap(find.text('Verwerfen'));
    await tester.pumpAndSettle();
    expect(find.byType(ResuscitationScreen), findsNothing);
  });
}
