import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_fallbeispiel/Screens/normal_screen.dart';
import 'package:rd_fallbeispiel/measure_requirements.dart';
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
}
