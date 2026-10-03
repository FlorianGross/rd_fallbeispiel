import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rd_fallbeispiel/measure_requirements.dart';
import 'package:rd_fallbeispiel/models/medication.dart';
import 'package:rd_fallbeispiel/services/pdf_service.dart';

const _outDir = String.fromEnvironment('PDF_OUT');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final start = DateTime(2026, 10, 1, 12);
  final completed = [
    CompletedAction(schema: 'SSSS', action: 'Scene', timestamp: start),
    CompletedAction(
        schema: 'B',
        action: 'SpO₂',
        timestamp: start.add(const Duration(seconds: 40))),
    CompletedAction(
        schema: 'D',
        action: 'GCS – Augen (E1–E4)',
        timestamp: start.add(const Duration(seconds: 95))),
  ];
  const missing = [
    MissingAction(
        schema: 'D', action: 'BZ', requirementLevel: RequirementLevel.required),
  ];

  Future<void> maybeWrite(String name, List<int> bytes) async {
    if (_outDir.isNotEmpty) File('$_outDir/$name').writeAsBytesSync(bytes);
  }

  test('Trainingsbericht mit Szenario, Notiz und Sonderzeichen', () async {
    final pdf = await PdfService.buildNormalPdf(
      completedActions: completed,
      missingActions: missing,
      userQualification: Qualification.RS,
      elapsedSeconds: 125,
      scenarioName: 'Schlaganfall (Stroke)',
      notes: 'BZ vergessen – nächstes Mal früher messen.',
    );
    final bytes = await pdf.save();
    expect(bytes.length, greaterThan(1000));
    await maybeWrite('normal.pdf', bytes);
  });

  test('Bericht ohne durchgeführte Maßnahmen ist nicht leer', () async {
    final pdf = await PdfService.buildNormalPdf(
      completedActions: const [],
      missingActions: missing,
      userQualification: Qualification.RS,
      elapsedSeconds: 0,
    );
    expect(pdf.document.pdfPageList.pages, isNotEmpty);
    await maybeWrite('empty.pdf', await pdf.save());
  });

  test('Reanimationsbericht', () async {
    final pdf = await PdfService.buildResuscitationPdf(
      completedActions: completed,
      missingActions: missing,
      userQualification: Qualification.NFS,
      isChildResuscitation: false,
      compressionCount: 60,
      ventilationCount: 4,
      targetCompressionRatio: 30,
      targetVentilationRatio: 2,
      resuscitationStart: start,
      resuscitationDuration: const Duration(minutes: 2, seconds: 5),
      bpmHistory: [
        {'timestamp': start.add(const Duration(seconds: 1)), 'bpm': 100.0},
        {'timestamp': start.add(const Duration(seconds: 2)), 'bpm': 120.0},
      ],
      ventilationHistory: [
        {'timestamp': start.add(const Duration(seconds: 20)), 'count': 1},
      ],
      vehicleStatus: const {},
      scenarioName: 'Kreislaufstillstand (Reanimation)',
      medications: [
        MedicationAdministration(
          medication: MedicationCatalog.adrenalin,
          dose: '1 mg',
          route: 'i.o.',
          timestamp: start.add(const Duration(seconds: 70)),
        ),
      ],
      medicationNotes: const [
        'Schocks: 0',
        'Adrenalin: 1× – erste Gabe 1:10 nach Reanimationsbeginn',
      ],
    );
    final bytes = await pdf.save();
    expect(bytes.length, greaterThan(1000));
    await maybeWrite('resus.pdf', bytes);
  });
}
