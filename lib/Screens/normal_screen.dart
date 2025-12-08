import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'result_screen.dart';

class SchemaSelectionScreen extends StatefulWidget {
  final Map<String, int> vehicleStatus;
  final Map<String, DateTime?> vehicleArrivalTimes;

  const SchemaSelectionScreen({
    super.key,
    required this.vehicleStatus,
    required this.vehicleArrivalTimes,
  });

  @override
  _SchemaSelectionScreenState createState() => _SchemaSelectionScreenState();
}

class _SchemaSelectionScreenState extends State<SchemaSelectionScreen> {
  Map<String, List<String>> schemas = {
    'SSSS': [
      'Scene',
      'Safety',
      'Situation',
      'Support',
    ],
    'Erster Eindruck': [
      'Zyanose',
      'Austreten Flüssigkeiten',
      'Hauttonus',
      'Pathologische Atemgeräusche',
      'Allgemeinzustand'
    ],
    'WASB': [
      'Wach',
      'Ansprechbar',
      'Schmerzreiz',
      'Bewusstlos',
    ],
    'c/x': [
      'Kritische Blutungen',
    ],
    'a': [
      'Atemwege Frei',
      'Schleimhautfarbe',
      'Schleimhautfeuchtigkeit',
      'Zahnstatus',
    ],
    'b': [
      'Atemfrequenz',
      'Atemzugvolumen',
    ],
    'c': [
      'Pulsfrequenz',
      'Tastbarkeit',
      'Rythmik',
      'Recap',
    ],
    'STU': [
      'Rückenlage',
      'Kopf-Fixierung',
      'Blutungen Kopf',
      'Gesichtsknochen',
      'Austritt Flüssigkeiten Nase',
      'Austritt Flüssigkeiten Ohr',
      'Pupillen Isokor',
      'Battlesigns',
      'HWS Stufenbildung',
      'HWS Hartspann',
      'Trachea zentral',
      'Halsvenenstauung',
      'Thorax 2 Ebenen',
      'Auskultation',
      'Abdomen Palpation',
      'Abdomen Abwehrspannung',
      'Abdomen Druckschmerz',
      'Beckenstabilität',
      'Oberschenkel Volumen',
      'Oberschenkel 2 Ebenen',
      'pDMS Beine',
      'pDMS Arme',
      'Achsengerechte Drehung',
      'Rücken Stufenbildung',
      'Rücken Hartspann',
    ],
    'A': [
      'Reevaluation Atemwege',
    ],
    'B': [
      'Auskultation Beidseits',
      'Auskultation Atemgeräusche',
      'Atemhilfsmuskulatur',
      'Sp02',
      'etCO2',
      'Atemmuster',
    ],
    'C': [
      'Blutdruck',
      'Puls',
      'Recap',
      'EKG',
    ],
    'D': [
      'Pupillenkontrolle',
      'GCS',
      'BZ',
    ],
    'E': [
      'Temperatur',
      'Body-Check',
      'Exikkose',
      'Ödeme',
      'Verletzungen',
      'Einstichstellen',
      'Insulinpumpe',
      'Wärmeerhalt'
    ],
    'BE-FAST': [
      'Balance',
      'Eyes',
      'Face',
      'Arms',
      'Speech',
      'Time',
    ],
    'ZOPS': [
      'Zeit',
      'Ort',
      'Person',
      'Situation',
    ],
    'SAMPLERS': [
      'Symptome',
      'Allergien',
      'Medikamente',
      'Patientenvorgeschichte',
      'Letzte Mahlzeit / Flüssigkeits Aufnahme,...',
      'Ereignis',
      'Risikofaktoren',
      'Schwangerschaft'
    ],
    'OPQRST': [
      'Onset',
      'Provocation',
      'Quality',
      'Radiation',
      'Severity',
      'Time',
    ],
    'Maßnahmen': [
      'Sauerstoffgabe',
      'Beatmung (kontrolliert/assistiert)',
      'Intubation',
      'Lagerung',
      'Defibrillation',
      'Reanimation',
    ],
    'Maßnahmen (erweitert)': [
      'Zugang IV / IO',
      'Volumengabe',
      'Medikamentengabe',
      'Thoraxdrainage',
      'Perikardpunktion',
      'Thorakotomie',
      'Larynxtubus',
    ],
    'Nachforderung': [
      'NEF',
      'RTW',
      'RTH',
      'KTW',
      'Feuerwehr',
      'Polizei',
      'PSNV',
      'Sonstige',
    ],
  };

  List<Map<String, dynamic>> completedActions = [];
  late Timer _timer;
  late Timer _arrivalCheckTimer;
  int _elapsedSeconds = 0;

  // Track which vehicles have shown arrival notification
  Set<String> _arrivedVehicles = {};

  // Set selectedVehicles to be finished
  void finishVehicles() {
    setState(() {
      widget.vehicleStatus.forEach((key, value) {
        if (value == 2 &&
            !completedActions.any(
                    (e) => e['schema'] == 'Nachforderung' && e['action'] == key)) {
          completedActions.add({
            'schema': 'Nachforderung',
            'action': key,
            'timestamp': DateTime.now()
          });
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });

    // Check for vehicle arrivals every second
    _arrivalCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkVehicleArrivals();
    });

    finishVehicles();
  }

  void _checkVehicleArrivals() {
    final now = DateTime.now();
    widget.vehicleArrivalTimes.forEach((vehicle, arrivalTime) {
      if (arrivalTime != null &&
          !_arrivedVehicles.contains(vehicle) &&
          now.isAfter(arrivalTime)) {
        _arrivedVehicles.add(vehicle);
        _showVehicleArrivalDialog(vehicle);
      }
    });
  }

  void _showVehicleArrivalDialog(String vehicle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.local_shipping, color: Colors.blue.shade700, size: 32),
            const SizedBox(width: 12),
            const Text('Rettungsmittel eingetroffen!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Text(
                vehicle,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ist am Einsatzort angekommen.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Verstanden',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _arrivalCheckTimer.cancel();
    super.dispose();
  }

  void generatePDF() async {
    final pdf = pw.Document();
    final missingActions = schemas.entries
        .expand((entry) => entry.value
        .map((action) => {'schema': entry.key, 'action': action}))
        .where((item) => !completedActions.any(
            (e) => e['schema'] == item['schema'] && e['action'] == item['action']))
        .toList();

    if (completedActions.isNotEmpty) {
      DateTime firstActionTime = completedActions.first['timestamp'];
      final now = DateTime.now();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header with gradient-like effect
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
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
                      'Strukturierte Patientenversorgung',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey300,
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

              // Summary Statistics
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green200, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatBox('Durchgeführt', '${completedActions.length}', PdfColors.green),
                    _buildStatBox('Fehlend', '${missingActions.length}', PdfColors.orange),
                    _buildStatBox('Dauer', '${_elapsedSeconds ~/ 60} min', PdfColors.blue),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Vehicle Status Section
              if (widget.vehicleStatus.entries.any((e) => e.value != 0)) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue200, width: 2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 4,
                            height: 20,
                            color: PdfColors.blue,
                          ),
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
                      ...widget.vehicleStatus.entries
                          .where((entry) => entry.value != 0)
                          .map((entry) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 8,
                              height: 8,
                              decoration: pw.BoxDecoration(
                                color: entry.value == 2 ? PdfColors.red : PdfColors.blue,
                                shape: pw.BoxShape.circle,
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Text(
                              "${entry.key}: ${entry.value == 2 ? 'Auf Anfahrt' : 'Besetzt'}",
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // Timeline Section
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green200, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 4,
                          height: 20,
                          color: PdfColors.green,
                        ),
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
                      Duration diff = action['timestamp'].difference(firstActionTime);
                      String elapsedTime = "+${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')} min";
                      firstActionTime = action['timestamp'];

                      return pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 6),
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: index % 2 == 0 ? PdfColors.white : PdfColors.green100,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
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
                                action['schema'],
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 5,
                              child: pw.Text(
                                action['action'],
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey300,
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
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

              // Missing Actions Section (only if there are any)
              if (missingActions.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange50,
                    border: pw.Border.all(color: PdfColors.orange200, width: 2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 4,
                            height: 20,
                            color: PdfColors.orange,
                          ),
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
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
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
                              "${action['schema']} - ${action['action']}",
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

  pw.Widget _buildStatBox(String label, String value, PdfColor color) {
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
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  void _showMedicalSourcesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hinweis & Quellen'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Diese App stellt ausschließlich Fallbeispiele und '
                    'Trainingsschemata für Ausbildung und Fortbildung im Rettungsdienst dar. '
                    'Sie ersetzt keine medizinische Beratung, Diagnostik oder Therapieempfehlung.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Die hier dargestellten Schemata (z. B. (c)ABCDE, SAMPLER, '
                    'OPQRST, BE-FAST, WASB, STU, A–E, Maßnahmen) orientieren sich u. a. an:',
              ),
              const SizedBox(height: 8),
              _buildReferenceEntry(
                'Drache D, Conrad A, Brand A, Frenzel J, Kaiserauer E. '
                    '„retten – Rettungssanitäter". Georg Thieme Verlag; 2024. '
                    'Online: https://shop.thieme.de/retten-Rettungssanitaeter/9783132434684',
              ),
              const SizedBox(height: 4),
              _buildReferenceEntry(
                'Buschmann C (Hrsg.). „Das ABCDE-Schema der Patientensicherheit '
                    'in der Notfallmedizin – Pearls and Pitfalls aus interdisziplinärer Sicht". '
                    'Kohlhammer Verlag.',
              ),
              const SizedBox(height: 4),
              _buildReferenceEntry(
                'European Resuscitation Council (ERC). „ERC Guidelines 2025 / '
                    '2021 – Basic Life Support & Advanced Life Support". '
                    'Online: https://www.erc.edu',
              ),
              const SizedBox(height: 4),
              _buildReferenceEntry(
                'Thieme via medici – notfallmedizinische Basisdiagnostik mit '
                    '(c)ABCDE- und SAMPLER-Schema.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Die Umsetzung im Rahmen dieser App dient ausschließlich dem '
                    'strukturierten Training von Einsatzkräften.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  static Widget _buildReferenceEntry(String text) {
    return Text(
      '• $text',
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildVehicleArrivalCard() {
    // Filter vehicles that are coming (status 2) and have arrival times
    final incomingVehicles = widget.vehicleStatus.entries
        .where((e) => e.value == 2 && widget.vehicleArrivalTimes[e.key] != null)
        .toList();

    if (incomingVehicles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.orange.shade50, Colors.red.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Ankommende Rettungsmittel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...incomingVehicles.map((entry) {
              final vehicle = entry.key;
              final arrivalTime = widget.vehicleArrivalTimes[vehicle]!;
              final now = DateTime.now();
              final diff = arrivalTime.difference(now);
              final hasArrived = _arrivedVehicles.contains(vehicle);

              String timeText;
              Color statusColor;
              IconData statusIcon;

              if (hasArrived) {
                timeText = 'Eingetroffen!';
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
              } else if (diff.isNegative) {
                timeText = 'Ankunft!';
                statusColor = Colors.green;
                statusIcon = Icons.notifications_active;
              } else {
                final minutes = diff.inMinutes;
                final seconds = diff.inSeconds % 60;
                timeText = '${minutes}:${seconds.toString().padLeft(2, '0')} min';
                statusColor = diff.inMinutes <= 2 ? Colors.orange : Colors.blue;
                statusIcon = Icons.access_time;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor,
                    width: hasArrived ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (!hasArrived && !diff.isNegative)
                              Text(
                                'Erwartet um ${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')} Uhr',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schemata Auswahl - Zeit: $_elapsedSeconds s'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.redAccent, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Übersicht',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  final missingActions = schemas.entries
                      .expand((entry) => entry.value.map(
                          (action) => {'schema': entry.key, 'action': action}))
                      .where((item) => !completedActions.any((e) =>
                  e['schema'] == item['schema'] &&
                      e['action'] == item['action']))
                      .toList();
                  return MeasuresOverviewScreen(
                      completedActions: completedActions,
                      missingActions: missingActions);
                }),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'PDF erstellen',
            onPressed: generatePDF,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Hinweise & Quellen',
            onPressed: _showMedicalSourcesDialog,
          ),
        ],
      ),
      body: ListView(
        children: [
          // Vehicle arrival status
          _buildVehicleArrivalCard(),

          ...schemas.keys.map((schema) {
            bool allCompleted = schemas[schema]!.every((action) =>
                completedActions
                    .any((e) => e['schema'] == schema && e['action'] == action));

            // Get icon for schema
            IconData schemaIcon = Icons.checklist;
            if (schema.contains('Atemwege') || schema == 'a' || schema == 'A') {
              schemaIcon = Icons.air;
            } else if (schema.contains('Atmung') || schema == 'b' || schema == 'B') {
              schemaIcon = Icons.wind_power;
            } else if (schema.contains('Kreislauf') || schema == 'c' || schema == 'C') {
              schemaIcon = Icons.favorite;
            } else if (schema == 'SSSS') {
              schemaIcon = Icons.security;
            } else if (schema == 'WASB') {
              schemaIcon = Icons.psychology;
            } else if (schema == 'STU') {
              schemaIcon = Icons.personal_injury;
            } else if (schema == 'D') {
              schemaIcon = Icons.visibility;
            } else if (schema == 'E') {
              schemaIcon = Icons.thermostat;
            } else if (schema == 'BE-FAST') {
              schemaIcon = Icons.emergency;
            } else if (schema == 'ZOPS') {
              schemaIcon = Icons.quiz;
            } else if (schema.contains('Maßnahmen')) {
              schemaIcon = Icons.medical_services;
            } else if (schema == 'SAMPLERS') {
              schemaIcon = Icons.history_edu;
            } else if (schema == 'OPQRST') {
              schemaIcon = Icons.description;
            } else if (schema == 'Nachforderung') {
              schemaIcon = Icons.phone_in_talk;
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: allCompleted ? 4 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: allCompleted ? Colors.green : Colors.grey.shade300,
                  width: allCompleted ? 2 : 1,
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  leading: Icon(
                    schemaIcon,
                    color: allCompleted ? Colors.green : Colors.grey.shade600,
                  ),
                  title: Text(
                    schema,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: allCompleted ? Colors.green.shade800 : Colors.black87,
                    ),
                  ),
                  trailing: allCompleted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.expand_more),
                  backgroundColor: allCompleted
                      ? Colors.green.withOpacity(0.1)
                      : Colors.transparent,
                  children: schemas[schema]!.map((action) {
                    bool isCompleted = completedActions.any(
                            (e) => e['schema'] == schema && e['action'] == action);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isCompleted
                            ? Colors.green.shade100
                            : Colors.grey.shade100,
                      ),
                      child: ListTile(
                        leading: Icon(
                          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isCompleted ? Colors.green : Colors.grey,
                        ),
                        title: Text(
                          action,
                          style: TextStyle(
                            color: isCompleted ? Colors.green.shade900 : Colors.black87,
                            fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        onTap: isCompleted
                            ? null
                            : () {
                          setState(() {
                            completedActions.add({
                              'schema': schema,
                              'action': action,
                              'timestamp': DateTime.now()
                            });
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 20), // Bottom padding
        ],
      ),
    );
  }
}