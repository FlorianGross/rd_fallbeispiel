import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rd_fallbeispiel/Screens/result_screen.dart';

import '../measure_requirements.dart';
import '../services/pdf_service.dart';
import '../utils/schema_icons.dart';

class ResuscitationScreen extends StatefulWidget {
  final Map<String, VehicleStatus> vehicleStatus;
  final bool isChildResuscitation;
  final Map<String, DateTime?> vehicleArrivalTimes;
  final Qualification userQualification;

  const ResuscitationScreen({
    super.key,
    required this.vehicleStatus,
    required this.isChildResuscitation,
    required this.vehicleArrivalTimes,
    required this.userQualification,
  });

  @override
  _ResuscitationScreenState createState() => _ResuscitationScreenState();
}

class _ResuscitationScreenState extends State<ResuscitationScreen>
    with TickerProviderStateMixin {
  Map<String, List<String>> get schemas {
    Map<String, List<String>> result = {};
    MeasureRequirements.requirements.forEach((schema, requirements) {
      result[schema] = requirements.map((req) => req.action).toList();
    });
    return result;
  }

  // BPM Functionality
  final List<DateTime> _tapTimestamps = [];
  double _smoothedBPM = 0;

  // BPM History tracking for graph
  List<Map<String, dynamic>> _bpmHistory = [];
  List<Map<String, dynamic>> _ventilationHistory = [];

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

      // Record BPM history for graph
      if (_bpm > 0) {
        _bpmHistory.add({
          'timestamp': now,
          'bpm': _bpm,
        });
      }

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

    final now = DateTime.now();

    setState(() {
      _ventilationCount++;

      // Record ventilation history for graph
      _ventilationHistory.add({
        'timestamp': now,
        'count': _ventilationCount,
      });

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
    if (_bpm >= BpmThresholds.optimalMin && _bpm <= BpmThresholds.optimalMax) {
      return Colors.green;
    }
    if (_bpm >= BpmThresholds.acceptableMin && _bpm <= BpmThresholds.acceptableMax) {
      return Colors.orange;
    }
    return Colors.red;
  }

  // Other
  List<CompletedAction> completedActions = [];
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
        if (value == VehicleStatus.kommt &&
            !completedActions.any(
                (e) => e.schema == 'Nachforderung' && e.action == key)) {
          completedActions.add(CompletedAction(
            schema: 'Nachforderung',
            action: key,
            timestamp: DateTime.now(),
          ));
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

  Future<void> generatePDF() async {
    final missingActions = MeasureRequirements.calculateMissingRequiredActions(
      completedActions,
      widget.userQualification,
    );
    await PdfService.generateResuscitationPdf(
      completedActions: completedActions,
      missingActions: missingActions,
      userQualification: widget.userQualification,
      isChildResuscitation: widget.isChildResuscitation,
      compressionCount: _compressionCount,
      ventilationCount: _ventilationCount,
      targetCompressionRatio: _targetCompressionRatio,
      targetVentilationRatio: _targetVentilationRatio,
      resuscitationStart: resuscitationStart,
      bpm: _bpm,
      bpmHistory: _bpmHistory,
      ventilationHistory: _ventilationHistory,
      vehicleStatus: widget.vehicleStatus,
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
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleArrivalCard() {
    // Filter vehicles that are coming and have arrival times
    final incomingVehicles = widget.vehicleStatus.entries
        .where((e) =>
            e.value == VehicleStatus.kommt &&
            widget.vehicleArrivalTimes[e.key] != null)
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
        title: Text('Reanimation - Zeit: $_elapsedSeconds s (${widget.userQualification.name})'),
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
                  final missingActions = MeasureRequirements.calculateMissingRequiredActions(
                    completedActions,
                    widget.userQualification,
                  );
                  return MeasuresOverviewScreen(
                    completedActions: completedActions,
                    missingActions: missingActions,
                    userQualification: widget.userQualification,
                    bpmHistory: _bpmHistory,
                    ventilationHistory: _ventilationHistory,
                    compressionCount: _compressionCount,
                    ventilationCount: _ventilationCount,
                    resuscitationStart: resuscitationStart,
                  );
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
                    (e) => e.schema == schema && e.action == action));

            final schemaIcon = getSchemaIcon(schema);

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
                        (e) => e.schema == schema && e.action == action);

                    // Get requirement info
                    final requirement = MeasureRequirements.getRequirement(schema, action);
                    final isOptional = requirement?.isOptionalFor(widget.userQualification) ?? false;
                    final canPerform = requirement?.canPerformWithQualification(widget.userQualification) ?? true;
                    final requirementLevel = requirement?.getRequirementLevel(widget.userQualification);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isCompleted
                            ? Colors.green.shade100
                            : (isOptional ? Colors.blue.shade50 : Colors.grey.shade100),
                        border: isOptional && !isCompleted
                            ? Border.all(color: Colors.blue.shade300, width: 1.5)
                            : null,
                      ),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isCompleted ? Colors.green : (isOptional ? Colors.blue : Colors.grey),
                            ),
                            if (isOptional && !isCompleted) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.help_outline, color: Colors.blue.shade600, size: 16),
                            ],
                            if (!canPerform) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.lock, color: Colors.orange.shade700, size: 16),
                            ],
                          ],
                        ),
                        title: Text(
                          action,
                          style: TextStyle(
                            color: isCompleted
                                ? Colors.green.shade900
                                : (!canPerform ? Colors.grey.shade600 : Colors.black87),
                            fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
                            decoration: !canPerform ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: !canPerform
                            ? Text(
                          'Nicht verfügbar für ${widget.userQualification.name}',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                            : (isOptional
                            ? Text(
                          requirementLevel == RequirementLevel.expected ? 'Erwartet' : 'Optional',
                          style: TextStyle(
                            color: requirementLevel == RequirementLevel.expected
                                ? Colors.amber.shade700
                                : Colors.blue.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                            : null),
                        onTap: (isCompleted || !canPerform)
                            ? null
                            : () {
                                setState(() {
                                  completedActions.add(CompletedAction(
                                    schema: schema,
                                    action: action,
                                    timestamp: DateTime.now(),
                                  ));
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