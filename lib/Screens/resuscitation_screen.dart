import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:rd_fallbeispiel/Screens/result_screen.dart';

class ResuscitationScreen extends StatefulWidget {
  final Map<String, int> vehicleStatus;
  final bool isChildResuscitation;
  final Map<String, DateTime?> vehicleArrivalTimes;

  const ResuscitationScreen({
    super.key,
    required this.vehicleStatus,
    required this.isChildResuscitation,
    required this.vehicleArrivalTimes,
  });

  @override
  _ResuscitationScreenState createState() => _ResuscitationScreenState();
}

class _ResuscitationScreenState extends State<ResuscitationScreen>
    with TickerProviderStateMixin {
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
    ],
    'b': [
      'Atmung vorhanden',
    ],
    'c': [
      'Kreislauf vorhanden',
    ],
    '4H': [
      'Hypovolämie',
      'Hypoxie',
      'Hypothermie',
      'Hypo-/Hyperkaliämie oder Hypo-/Hyperglykämie',
    ],
    'HITS': [
      'Herzbeuteltamponade',
      'Intoxikation',
      'Trombembolie',
      'Spannungspneumothorax',
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

  // BPM Functionality
  final List<DateTime> _tapTimestamps = [];
  double _smoothedBPM = 0;

  // Ventilation tracking
  int _compressionCount = 0;
  int _ventilationCount = 0;
  int _cycleCompressions = 0;
  late int _targetCompressionRatio;
  late int _targetVentilationRatio;

  // Initial ventilations for children
  bool _initialVentilationsComplete = false;
  int _initialVentilationCount = 0;
  static const int _requiredInitialVentilations = 5;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _ventilationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _ventilationAnimation;

  void _registerTap() {
    // For children, require initial ventilations first
    if (widget.isChildResuscitation && !_initialVentilationsComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erst ${_requiredInitialVentilations} Initialbeatmungen! (${_initialVentilationCount}/$_requiredInitialVentilations)',
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final now = DateTime.now();
    resuscitationStart ??= now;

    // Haptic feedback
    HapticFeedback.lightImpact();

    setState(() {
      _tapTimestamps.add(now);
      if (_tapTimestamps.length > 5) {
        _tapTimestamps.removeAt(0);
      }
      _calculateSmoothedBPM();

      // Compression counting
      _compressionCount++;
      _cycleCompressions++;

      // Trigger pulse animation
      _pulseController.forward(from: 0);
    });
  }

  void _registerVentilation() {
    if (resuscitationStart == null) {
      // Start resuscitation with first ventilation for children
      resuscitationStart = DateTime.now();
    }

    // Haptic feedback
    HapticFeedback.mediumImpact();

    setState(() {
      _ventilationCount++;

      // Handle initial ventilations for children
      if (widget.isChildResuscitation && !_initialVentilationsComplete) {
        _initialVentilationCount++;
        if (_initialVentilationCount >= _requiredInitialVentilations) {
          _initialVentilationsComplete = true;
        }
      } else {
        _cycleCompressions = 0; // Reset cycle counter only after initial ventilations
      }

      // Trigger ventilation animation
      _ventilationController.forward(from: 0);
    });
  }

  void _calculateSmoothedBPM() {
    if (_tapTimestamps.length < 2) {
      _smoothedBPM = 0;
      return;
    }

    final intervals = <int>[];
    for (int i = 1; i < _tapTimestamps.length; i++) {
      intervals.add(
          _tapTimestamps[i].difference(_tapTimestamps[i - 1]).inMilliseconds);
    }

    if (intervals.isEmpty) return;

    final averageInterval =
        intervals.reduce((a, b) => a + b) / intervals.length;
    _smoothedBPM = 60000 / averageInterval;
  }

  double get _bpm => _smoothedBPM;

  Color _getBPMColor() {
    if (_bpm == 0) return Colors.grey;
    if (_bpm >= 100 && _bpm <= 120) return Colors.green;
    if (_bpm >= 90 && _bpm <= 130) return Colors.orange;
    return Colors.red;
  }

  // Other
  List<Map<String, dynamic>> completedActions = [];
  late Timer _timer;
  late Timer _arrivalCheckTimer;
  int _elapsedSeconds = 0;
  DateTime? resuscitationStart;

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

    // Set ratio based on child/adult resuscitation
    _targetCompressionRatio = widget.isChildResuscitation ? 15 : 30;
    _targetVentilationRatio = 2;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });

    // Check for vehicle arrivals every second
    _arrivalCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkVehicleArrivals();
    });

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _ventilationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _ventilationAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _ventilationController, curve: Curves.easeInOut),
    );

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
    _pulseController.dispose();
    _ventilationController.dispose();
    super.dispose();
  }

  void generatePDF() async {
    final pdf = pw.Document();
    final missingActions = schemas.entries
        .expand((entry) => entry.value
        .map((action) => {'schema': entry.key, 'action': action}))
        .where((item) => !completedActions
        .any((e) => e['schema'] == item['schema'] && e['action'] == item['action']))
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
                      'Reanimation - ${widget.isChildResuscitation ? "Kind/Säugling" : "Erwachsener"}',
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

              // Reanimation Statistics Section
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red50,
                  border: pw.Border.all(color: PdfColors.red200, width: 2),
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
                          color: PdfColors.red,
                        ),
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
                        _buildStatBox('Kompressionen', '$_compressionCount', PdfColors.red),
                        _buildStatBox('Beatmungen', '$_ventilationCount', PdfColors.blue),
                        _buildStatBox('Verhältnis', '$_targetCompressionRatio:$_targetVentilationRatio', PdfColors.green),
                      ],
                    ),
                    if (resuscitationStart != null) ...[
                      pw.SizedBox(height: 10),
                      pw.Divider(color: PdfColors.red200),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'Reanimationsdauer: ${DateTime.now().difference(resuscitationStart!).inMinutes} Minuten',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      if (_bpm > 0)
                        pw.Text(
                          'Durchschnittliche Frequenz: ${_bpm.toStringAsFixed(0)} BPM',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Vehicle Status Section
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
                'Die hier dargestellten Schemata (z. B. SSSS, WASB, (c)ABCDE, '
                    'SAMPLER, 4H/4T, Maßnahmen der Reanimation) orientieren sich u. a. an:',
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
                'Thieme via medici / notfallmedizinische Basisdiagnostik '
                    'mit (c)ABCDE- und SAMPLER-Schema.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Die Umsetzung im Rahmen dieser App dient ausschließlich dem '
                    'strukturieren Training von Einsatzkräften.',
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

  void _showRatioChangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verhältnis ändern'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Synchrone Beatmung:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              ListTile(
                title: const Text('30:2'),
                subtitle: const Text('Standard Erwachsene'),
                leading: Radio<String>(
                  value: '30:2',
                  groupValue: '$_targetCompressionRatio:$_targetVentilationRatio',
                  onChanged: (value) {
                    setState(() {
                      _targetCompressionRatio = 30;
                      _targetVentilationRatio = 2;
                      _cycleCompressions = 0;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
              ListTile(
                title: const Text('15:2'),
                subtitle: const Text('Kinder mit 2 Helfern'),
                leading: Radio<String>(
                  value: '15:2',
                  groupValue: '$_targetCompressionRatio:$_targetVentilationRatio',
                  onChanged: (value) {
                    setState(() {
                      _targetCompressionRatio = 15;
                      _targetVentilationRatio = 2;
                      _cycleCompressions = 0;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Asynchrone Beatmung (nach Intubation):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              ListTile(
                title: const Text('10:1'),
                subtitle: const Text('Nach gesichertem Atemweg'),
                leading: Radio<String>(
                  value: '10:1',
                  groupValue: '$_targetCompressionRatio:$_targetVentilationRatio',
                  onChanged: (value) {
                    setState(() {
                      _targetCompressionRatio = 10;
                      _targetVentilationRatio = 1;
                      _cycleCompressions = 0;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  Widget _buildReanimationDashboard() {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.red.shade50, Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Initial Ventilations Warning for Children
            if (widget.isChildResuscitation && !_initialVentilationsComplete)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'INITIALBEATMUNGEN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_initialVentilationCount / $_requiredInitialVentilations Beatmungen',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: _initialVentilationCount / _requiredInitialVentilations,
                            backgroundColor: Colors.orange.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                            minHeight: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // BPM Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite, color: _getBPMColor(), size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bpm.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _getBPMColor(),
                      ),
                    ),
                    Text(
                      'BPM (Ziel: 100-120)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Compression/Ventilation Ratio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  icon: Icons.compress,
                  label: 'Kompressionen',
                  value: '$_compressionCount',
                  color: Colors.red,
                ),
                _buildStatCard(
                  icon: Icons.air,
                  label: 'Beatmungen',
                  value: '$_ventilationCount',
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress to next ventilation (only show after initial ventilations)
            if (!widget.isChildResuscitation || _initialVentilationsComplete)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bis zur Beatmung: ${_targetCompressionRatio - _cycleCompressions} Kompressionen',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: _showRatioChangeDialog,
                        tooltip: 'Verhältnis ändern',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _cycleCompressions / _targetCompressionRatio,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _cycleCompressions >= _targetCompressionRatio
                          ? Colors.orange
                          : Colors.green,
                    ),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Verhältnis: $_targetCompressionRatio:$_targetVentilationRatio ${_targetCompressionRatio == 10 && _targetVentilationRatio == 1 ? "(Asynchron - Intubiert)" : widget.isChildResuscitation ? "(Kind)" : "(Erwachsener)"}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            // Time since start
            if (resuscitationStart != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, size: 20, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Reanimation seit: ${DateTime.now().difference(resuscitationStart!).inMinutes}:${(DateTime.now().difference(resuscitationStart!).inSeconds % 60).toString().padLeft(2, '0')} min',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
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
        title: Text('Reanimation Schema - Zeit: $_elapsedSeconds s'),
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
          if (resuscitationStart != null) _buildReanimationDashboard(),

          // Vehicle arrival status
          _buildVehicleArrivalCard(),

          ...schemas.keys.map((schema) {
            bool allCompleted = schemas[schema]!.every((action) =>
                completedActions.any(
                        (e) => e['schema'] == schema && e['action'] == action));

            // Get icon for schema
            IconData schemaIcon = Icons.checklist;
            if (schema.contains('Atemwege') || schema == 'a') {
              schemaIcon = Icons.air;
            } else if (schema.contains('Atmung') || schema == 'b' || schema == 'B') {
              schemaIcon = Icons.wind_power;
            } else if (schema.contains('Kreislauf') || schema == 'c' || schema == 'C') {
              schemaIcon = Icons.favorite;
            } else if (schema == 'SSSS') {
              schemaIcon = Icons.security;
            } else if (schema == 'WASB') {
              schemaIcon = Icons.psychology;
            } else if (schema.contains('Maßnahmen')) {
              schemaIcon = Icons.medical_services;
            } else if (schema == 'SAMPLERS') {
              schemaIcon = Icons.history_edu;
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
          }),
          const SizedBox(height: 100), // Space for FABs
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Ventilation Button
          ScaleTransition(
            scale: _ventilationAnimation,
            child: FloatingActionButton.extended(
              heroTag: 'ventilation',
              onPressed: _registerVentilation,
              icon: const Icon(Icons.air, size: 32),
              label: Text(
                widget.isChildResuscitation && !_initialVentilationsComplete
                    ? 'Initial ${_initialVentilationCount}/$_requiredInitialVentilations'
                    : (_cycleCompressions >= _targetCompressionRatio ? 'Beatmung!' : 'Beatmung'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              backgroundColor: widget.isChildResuscitation && !_initialVentilationsComplete
                  ? Colors.orange
                  : (_cycleCompressions >= _targetCompressionRatio ? Colors.orange : Colors.blue),
            ),
          ),
          const SizedBox(height: 16),

          // Compression Button
          ScaleTransition(
            scale: _pulseAnimation,
            child: FloatingActionButton.large(
              heroTag: 'compression',
              onPressed: _registerTap,
              backgroundColor: Colors.red,
              child: const Icon(Icons.favorite, size: 48),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}