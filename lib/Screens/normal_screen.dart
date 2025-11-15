import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'result_screen.dart';

class SchemaSelectionScreen extends StatefulWidget {
  final Map<String, int> vehicleStatus;

  const SchemaSelectionScreen({super.key, required this.vehicleStatus});

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
                firstActionTime = action['timestamp'];
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

  // --------- NEU: Hinweis & Quellen gemäß Guideline 1.4.1 ---------

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
                    '„retten – Rettungssanitäter“. Georg Thieme Verlag; 2024. '
                    'Online: https://shop.thieme.de/retten-Rettungssanitaeter/9783132434684',
              ),
              const SizedBox(height: 4),
              _buildReferenceEntry(
                'Buschmann C (Hrsg.). „Das ABCDE-Schema der Patientensicherheit '
                    'in der Notfallmedizin – Pearls and Pitfalls aus interdisziplinärer Sicht“. '
                    'Kohlhammer Verlag.',
              ),
              const SizedBox(height: 4),
              _buildReferenceEntry(
                'European Resuscitation Council (ERC). „ERC Guidelines 2025 / '
                    '2021 – Basic Life Support & Advanced Life Support“. '
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

  // ---------------------------------------------------------------

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
            icon: const Icon(Icons.info_outline),
            onPressed: _showMedicalSourcesDialog,
          ),
        ],
      ),
      body: ListView(
        children: [
          ...schemas.keys.map((schema) {
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
        ],
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
