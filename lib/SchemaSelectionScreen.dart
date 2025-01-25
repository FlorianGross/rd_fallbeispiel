import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'MeasuresOverviewScreen.dart';

class SchemaSelectionScreen extends StatefulWidget {
  final Map<String, int> vehicleStatus;

  SchemaSelectionScreen({required this.vehicleStatus});

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
      'Abfrage kritische Blutungen',
    ],
    'a': [
      'Überprüfung Atemwege',
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
      'Rücken Hartspann'
    ],
    'A': [
      'Atemwege überprüfen',
      'Absaugbereitschaft',
      'Atemwegssicherung',
    ],
    'B': [
      'Auskultieren',
      'Atemhilfsmuskulatur',
      'Sp02',
      'Kontrollierte/Assistierte Beatmung',
      'Sauerstoffgabe',
    ],
    'C': [
      'Hauttonus',
      'Blutdruck',
      'Puls',
      'Recap',
      'EKG',
      'Lagerung',
      'Zugang IV / IO',
      'Volumengabe',
    ],
    'D': [
      'FAST',
      'Pupillenkontrolle',
      'GCS',
      'BZ',
    ],
    'E': [
      'Temperatur',
      'Body-Check',
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
    'Nachforderung': [
      'NEF',
      'RTW',
      'RTH',
      'KTW',
      'Feuerwehr',
      'Polizei',
      'THW',
      'Wasserrettung',
      'Bergwacht',
      'SEG',
      'Sonstige',
    ]
  };

  List<Map<String, dynamic>> completedActions = [];
  late Timer _timer;
  int _elapsedSeconds = 0;

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
    finishVehicles();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void generatePDF() async {
    final pdf = pw.Document();
    final missingActions = schemas.entries
        .expand((entry) => entry.value
            .map((action) => {'schema': entry.key, 'action': action}))
        .where((item) => !completedActions.any((e) =>
            e['schema'] == item['schema'] && e['action'] == item['action']))
        .toList();
    if (completedActions.isNotEmpty) {
      DateTime firstActionTime = completedActions.first['timestamp'];
      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context context) {
            return [
              pw.Text('Patientenversorgungsbericht',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Rettungsmittel:',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ...widget.vehicleStatus.entries.map((entry) => pw.Text(entry
                          .value !=
                      0
                  ? "${entry.key}: ${entry.value == 2 ? 'Auf Anfahrt' : entry.value == 1 ? 'Besetzt' : 'Frei'}"
                  : '')),
              pw.SizedBox(height: 20),
              pw.Text('Protokoll:',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ...completedActions.map((action) {
                Duration diff = action['timestamp'].difference(firstActionTime);
                String elapsedTime = "+${diff.inSeconds} Sekunden";
                return pw.Text(
                    "$elapsedTime ${action['schema']} ${action['action']}");
              }),
              pw.SizedBox(height: 20),
              pw.Text('Fehlende Maßnahmen:',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ...missingActions.map((action) =>
                  pw.Text("${action['schema']} - ${action['action']}")),
            ];
          },
        ),
      );
    }
    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
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
      ),
      body: ListView(
        children: schemas.keys.map((schema) {
          bool allCompleted = schemas[schema]!.every((action) =>
              completedActions
                  .any((e) => e['schema'] == schema && e['action'] == action));
          return Container(
            color: allCompleted ? Colors.green : Colors.transparent,
            child: ExpansionTile(
              title: Text(schema),
              backgroundColor: allCompleted ? Colors.green : Colors.transparent,
              children: schemas[schema]!.map((action) {
                bool isCompleted = completedActions
                    .any((e) => e['schema'] == schema && e['action'] == action);
                return ListTile(
                  title: Text(action),
                  tileColor: isCompleted ? Colors.green : Colors.grey,
                  onTap: () {
                    setState(() {
                      completedActions.add({
                        'schema': schema,
                        'action': action,
                        'timestamp': DateTime.now()
                      });
                    });
                  },
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
      floatingActionButton:
          Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(
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
          child: const Icon(Icons.list),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: null,
          onPressed: generatePDF,
          child: const Icon(Icons.print),
        ),
      ]),
    );
  }
}
