import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../measure_requirements.dart';

class PdfService {
  /// Erzeugt und öffnet den Trainingsbericht für den normalen Einsatzmodus
  static Future<void> generateNormalPdf({
    required List<CompletedAction> completedActions,
    required List<MissingAction> missingActions,
    required Qualification userQualification,
    required int elapsedSeconds,
  }) async {
    final pdf = pw.Document();

    final sortedCompleted = List<CompletedAction>.from(completedActions)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final now = DateTime.now();
    final firstTimeStamp =
        sortedCompleted.isNotEmpty ? sortedCompleted.first.timestamp : now;

    if (sortedCompleted.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  gradient: const pw.LinearGradient(
                    colors: [PdfColors.red300, PdfColors.blue300],
                  ),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'TRAININGSBERICHT PATIENTENVERSORGUNG',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Qualifikation: ${userQualification.name}',
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Erstellt am: ${now.day}.${now.month}.${now.year} um ${now.hour}:${now.minute.toString().padLeft(2, '0')} Uhr',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Statistics Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatBox(
                      'Durchgeführt', '${completedActions.length}', PdfColors.green),
                  _buildStatBox(
                      'Fehlend', '${missingActions.length}', PdfColors.orange),
                  _buildStatBox(
                      'Gesamt',
                      '${completedActions.length + missingActions.length}',
                      PdfColors.blue),
                  _buildStatBox(
                      'Dauer',
                      '${(elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(elapsedSeconds % 60).toString().padLeft(2, '0')}',
                      PdfColors.purple),
                ],
              ),
              pw.SizedBox(height: 20),

              // Completed Actions Section
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green200, width: 2),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(width: 4, height: 20, color: PdfColors.green),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          'DURCHGEFÜHRTE MASSNAHMEN (${completedActions.length})',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    ...sortedCompleted.asMap().entries.map((entry) {
                      final index = entry.key;
                      final action = entry.value;
                      final elapsed = action.timestamp.difference(firstTimeStamp);
                      final elapsedTime =
                          '+${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')} min';

                      return pw.Container(
                        margin: const pw.EdgeInsets.symmetric(vertical: 3),
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: index % 2 == 0 ? PdfColors.white : PdfColors.grey100,
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 25,
                              alignment: pw.Alignment.center,
                              child: pw.Text(
                                '${index + 1}.',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 10),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                action.schema,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 5,
                              child: pw.Text(
                                action.action,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey300,
                                borderRadius: const pw.BorderRadius.all(
                                    pw.Radius.circular(3)),
                              ),
                              child: pw.Text(
                                elapsedTime,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Missing Actions Section
              if (missingActions.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange50,
                    border: pw.Border.all(color: PdfColors.orange200, width: 2),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(width: 4, height: 20, color: PdfColors.orange),
                          pw.SizedBox(width: 10),
                          pw.Text(
                            'FEHLENDE VERPFLICHTENDE MASSNAHMEN (${missingActions.length})',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.orange900,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      ...missingActions.map((action) => pw.Padding(
                            padding:
                                const pw.EdgeInsets.symmetric(vertical: 2),
                            child: pw.Row(
                              children: [
                                pw.Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColors.orange,
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                                pw.SizedBox(width: 8),
                                pw.Text(
                                  '${action.schema} - ${action.action}',
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],

              // Footer
              pw.SizedBox(height: 30),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              pw.Text(
                'Dieser Bericht dient ausschließlich Ausbildungs- und Trainingszwecken im Rettungsdienst.',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ];
          },
        ),
      );
    }

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  /// Erzeugt und öffnet den Bericht für den Reanimationsmodus
  static Future<void> generateResuscitationPdf({
    required List<CompletedAction> completedActions,
    required List<MissingAction> missingActions,
    required Qualification userQualification,
    required bool isChildResuscitation,
    required int compressionCount,
    required int ventilationCount,
    required int targetCompressionRatio,
    required int targetVentilationRatio,
    required DateTime? resuscitationStart,
    required double bpm,
    required List<Map<String, dynamic>> bpmHistory,
    required List<Map<String, dynamic>> ventilationHistory,
    required Map<String, VehicleStatus> vehicleStatus,
  }) async {
    final pdf = pw.Document();

    if (completedActions.isNotEmpty) {
      DateTime firstActionTime = completedActions.first.timestamp;
      final now = DateTime.now();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PATIENTENVERSORGUNGSBERICHT',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Reanimation - ${isChildResuscitation ? "Kind/Säugling" : "Erwachsener"}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey300,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Qualifikation: ${userQualification.name}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Erstellt: ${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} um ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} Uhr',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey300,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 25),

              // Reanimation Statistics Section
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red50,
                  border: pw.Border.all(color: PdfColors.red200, width: 2),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(width: 4, height: 20, color: PdfColors.red),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          'REANIMATIONSSTATISTIK',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBox('Kompressionen', '$compressionCount', PdfColors.red),
                        _buildStatBox('Beatmungen', '$ventilationCount', PdfColors.blue),
                        _buildStatBox('Verhältnis', '$targetCompressionRatio:$targetVentilationRatio', PdfColors.green),
                      ],
                    ),
                    if (resuscitationStart != null) ...[
                      pw.SizedBox(height: 10),
                      pw.Divider(color: PdfColors.red200),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'Reanimationsdauer: ${DateTime.now().difference(resuscitationStart).inMinutes} Minuten',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      if (bpm > 0)
                        pw.Text(
                          'Durchschnittliche Frequenz: ${bpm.toStringAsFixed(0)} BPM',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Reanimation Graph
              _buildReanimationGraph(
                bpmHistory: bpmHistory,
                ventilationHistory: ventilationHistory,
                resuscitationStart: resuscitationStart,
              ),
              if (bpmHistory.isNotEmpty) pw.SizedBox(height: 20),

              // Vehicle Status Section
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue200, width: 2),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(width: 4, height: 20, color: PdfColors.blue),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          'RETTUNGSMITTEL',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    ...vehicleStatus.entries
                        .where((entry) => entry.value != VehicleStatus.none)
                        .map((entry) => pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 3),
                              child: pw.Row(
                                children: [
                                  pw.Container(
                                    width: 8,
                                    height: 8,
                                    decoration: pw.BoxDecoration(
                                      color: entry.value == VehicleStatus.kommt
                                          ? PdfColors.red
                                          : PdfColors.blue,
                                      shape: pw.BoxShape.circle,
                                    ),
                                  ),
                                  pw.SizedBox(width: 8),
                                  pw.Text(
                                    '${entry.key}: ${entry.value == VehicleStatus.kommt ? "Auf Anfahrt" : "Besetzt"}',
                                    style: const pw.TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            )),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Timeline Section
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green200, width: 2),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(width: 4, height: 20, color: PdfColors.green),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          'MASSNAHMEN-PROTOKOLL (${completedActions.length} durchgeführt)',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    ...completedActions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final action = entry.value;
                      final diff = action.timestamp.difference(firstActionTime);
                      final elapsedTime =
                          '+${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')} min';
                      firstActionTime = action.timestamp;

                      return pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 6),
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: index % 2 == 0
                              ? PdfColors.white
                              : PdfColors.green100,
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 24,
                              height: 24,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.green,
                                shape: pw.BoxShape.circle,
                              ),
                              child: pw.Center(
                                child: pw.Text(
                                  '${index + 1}',
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 10),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                action.schema,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 5,
                              child: pw.Text(
                                action.action,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey300,
                                borderRadius: const pw.BorderRadius.all(
                                    pw.Radius.circular(3)),
                              ),
                              child: pw.Text(
                                elapsedTime,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Missing Actions Section
              if (missingActions.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange50,
                    border: pw.Border.all(color: PdfColors.orange200, width: 2),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(width: 4, height: 20, color: PdfColors.orange),
                          pw.SizedBox(width: 10),
                          pw.Text(
                            'FEHLENDE MASSNAHMEN (${missingActions.length})',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.orange900,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      ...missingActions.map((action) => pw.Padding(
                            padding:
                                const pw.EdgeInsets.symmetric(vertical: 2),
                            child: pw.Row(
                              children: [
                                pw.Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColors.orange,
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                                pw.SizedBox(width: 8),
                                pw.Text(
                                  '${action.schema} - ${action.action}',
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],

              // Footer
              pw.SizedBox(height: 30),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              pw.Text(
                'Dieser Bericht dient ausschließlich Ausbildungs- und Trainingszwecken im Rettungsdienst.',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ];
          },
        ),
      );
    }

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ── Gemeinsame PDF-Hilfswidgets ─────────────────────────────────────────

  static pw.Widget _buildStatBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: color, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReanimationGraph({
    required List<Map<String, dynamic>> bpmHistory,
    required List<Map<String, dynamic>> ventilationHistory,
    required DateTime? resuscitationStart,
  }) {
    if (bpmHistory.isEmpty || resuscitationStart == null) {
      return pw.SizedBox.shrink();
    }

    const graphWidth = 480.0;

    final startTime = resuscitationStart;
    final endTime = bpmHistory.last['timestamp'] as DateTime;
    final totalSeconds = endTime.difference(startTime).inSeconds.toDouble();

    if (totalSeconds <= 0) return pw.SizedBox.shrink();

    final avgBPM = bpmHistory
            .map((e) => e['bpm'] as double)
            .reduce((a, b) => a + b) /
        bpmHistory.length;

    int optimalCount = 0;
    int acceptableCount = 0;
    int poorCount = 0;

    for (var data in bpmHistory) {
      final bpm = data['bpm'] as double;
      if (bpm >= BpmThresholds.optimalMin && bpm <= BpmThresholds.optimalMax) {
        optimalCount++;
      } else if (bpm >= BpmThresholds.acceptableMin &&
          bpm <= BpmThresholds.acceptableMax) {
        acceptableCount++;
      } else {
        poorCount++;
      }
    }

    final total = bpmHistory.length;
    final optimalPercent = optimalCount / total * 100;
    final acceptablePercent = acceptableCount / total * 100;
    final poorPercent = poorCount / total * 100;

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(width: 4, height: 20, color: PdfColors.purple),
              pw.SizedBox(width: 10),
              pw.Text(
                'REANIMATIONSQUALITÄT',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.purple900,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildQualityStatBox(
                'Durchschnitt',
                '${avgBPM.toStringAsFixed(0)} BPM',
                avgBPM >= BpmThresholds.optimalMin &&
                        avgBPM <= BpmThresholds.optimalMax
                    ? PdfColors.green
                    : avgBPM >= BpmThresholds.acceptableMin &&
                            avgBPM <= BpmThresholds.acceptableMax
                        ? PdfColors.orange
                        : PdfColors.red,
              ),
              _buildQualityStatBox('Messungen', '$total', PdfColors.blue),
              _buildQualityStatBox(
                  'Beatmungen', '${ventilationHistory.length}', PdfColors.blue),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Qualitätsverteilung:',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                _buildQualityBar('Optimal (${BpmThresholds.optimalMin}-${BpmThresholds.optimalMax} BPM)',
                    optimalCount, optimalPercent, PdfColors.green, graphWidth - 20),
                pw.SizedBox(height: 6),
                _buildQualityBar(
                    'Akzeptabel (${BpmThresholds.acceptableMin}-${BpmThresholds.acceptableMax} BPM)',
                    acceptableCount, acceptablePercent, PdfColors.orange, graphWidth - 20),
                pw.SizedBox(height: 6),
                _buildQualityBar('Verbesserungsbedarf', poorCount, poorPercent,
                    PdfColors.red, graphWidth - 20),
              ],
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Zeitlicher Verlauf (${totalSeconds.toInt()}s Gesamtdauer):',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  height: 40,
                  child: pw.Stack(
                    children: [
                      pw.Container(
                        height: 20,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey300,
                          borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(3)),
                        ),
                      ),
                      pw.Row(
                        children: bpmHistory.asMap().entries.map((entry) {
                          final bpm = entry.value['bpm'] as double;
                          PdfColor color;
                          if (bpm >= BpmThresholds.optimalMin &&
                              bpm <= BpmThresholds.optimalMax) {
                            color = PdfColors.green;
                          } else if (bpm >= BpmThresholds.acceptableMin &&
                              bpm <= BpmThresholds.acceptableMax) {
                            color = PdfColors.orange;
                          } else {
                            color = PdfColors.red;
                          }
                          return pw.Expanded(
                            child: pw.Container(
                              height: 20,
                              decoration: pw.BoxDecoration(
                                color: color,
                                border: pw.Border.all(
                                    color: PdfColors.white, width: 0.5),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      ...ventilationHistory.map((ventilation) {
                        final ventTime =
                            (ventilation['timestamp'] as DateTime)
                                .difference(startTime)
                                .inSeconds;
                        final position =
                            (ventTime / totalSeconds) * (graphWidth - 20);
                        return pw.Positioned(
                          left: position,
                          top: 0,
                          child: pw.Container(
                              width: 3, height: 40, color: PdfColors.blue),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Start',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('${(totalSeconds / 2).toInt()}s',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Ende (${totalSeconds.toInt()}s)',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              _buildLegendItem(PdfColors.green, 'Optimal'),
              pw.SizedBox(width: 10),
              _buildLegendItem(PdfColors.orange, 'Akzeptabel'),
              pw.SizedBox(width: 10),
              _buildLegendItem(PdfColors.red, 'Verbesserungsbedarf'),
              pw.SizedBox(width: 10),
              _buildLegendItem(PdfColors.blue, 'Beatmung'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildQualityStatBox(
      String label, String value, PdfColor color) {
    return pw.Container(
      width: 140,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: color, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildQualityBar(
      String label, int count, double percent, PdfColor color, double maxWidth) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
            pw.Text(
              '$count (${percent.toStringAsFixed(1)}%)',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Container(
          height: 20,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: maxWidth * (percent / 100),
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildLegendItem(PdfColor color, String label) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(width: 15, height: 3, color: color),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }
}
