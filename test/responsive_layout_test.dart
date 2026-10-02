import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_fallbeispiel/Screens/normal_screen.dart';
import 'package:rd_fallbeispiel/Screens/resuscitation_screen.dart';
import 'package:rd_fallbeispiel/measure_requirements.dart';
import 'package:rd_fallbeispiel/widgets/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Spaltenzahl nach Breite', () {
    expect(schemaColumnCount(390), 1);
    expect(schemaColumnCount(899), 1);
    expect(schemaColumnCount(1024), 2);
    expect(schemaColumnCount(1366), 3);
  });

  testWidgets('ColumnFlow verteilt spaltenweise in Lesereihenfolge',
      (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: ColumnFlow(
        columns: 2,
        children: [for (var i = 1; i <= 5; i++) Text('$i')],
      ),
    ));
    final x = {
      for (var i = 1; i <= 5; i++) i: tester.getTopLeft(find.text('$i')).dx
    };
    // 1–3 links, 4–5 rechts
    expect(x[1], x[3]);
    expect(x[4], x[5]);
    expect(x[4]! > x[1]!, isTrue);
  });

  testWidgets('Normalmodus: Tablet zeigt Schemata in mehreren Spalten',
      (tester) async {
    _setSize(tester, const Size(1366, 1024));
    await tester.pumpWidget(const MaterialApp(
      home: SchemaSelectionScreen(
        vehicleStatus: {},
        vehicleArrivalMinutes: {},
        userQualification: Qualification.RS,
      ),
    ));
    await tester.pump();
    final flow = tester.widget<ColumnFlow>(find.byType(ColumnFlow));
    expect(flow.columns, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Reanimation: Tablet hat festes CPR-Panel statt FABs',
      (tester) async {
    _setSize(tester, const Size(1366, 1024));
    await tester.pumpWidget(const MaterialApp(
      home: ResuscitationScreen(
        vehicleStatus: {},
        vehicleArrivalMinutes: {},
        isChildResuscitation: false,
        userQualification: Qualification.RS,
      ),
    ));
    await tester.pump();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Kompression'), findsOneWidget);

    await tester.tap(find.text('Kompression'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Kompressionen'), findsOneWidget,
        reason: 'Die erste Kompression startet das Dashboard im Panel');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Reanimation: Smartphone behält die schwebenden Tasten',
      (tester) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(
      home: ResuscitationScreen(
        vehicleStatus: {},
        vehicleArrivalMinutes: {},
        isChildResuscitation: false,
        userQualification: Qualification.RS,
      ),
    ));
    await tester.pump();
    expect(find.byType(FloatingActionButton), findsNWidgets(2));
    expect(find.text('Kompression'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
