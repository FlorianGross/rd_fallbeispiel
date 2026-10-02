import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rd_fallbeispiel/Screens/result_screen.dart';

import '../main.dart';
import '../measure_requirements.dart';
import '../models/cpr_summary.dart';
import '../models/medication.dart';
import '../models/resuscitation_notes.dart';
import '../models/scenario.dart';
import '../models/session_record.dart';
import '../services/history_service.dart';
import '../services/pdf_service.dart';
import '../utils/adaptive_colors.dart';
import '../widgets/medication_widgets.dart';
import '../widgets/responsive.dart';
import '../widgets/scenario_common.dart';
import 'scenario_session.dart';

class ResuscitationScreen extends StatefulWidget {
  final Map<String, VehicleStatus> vehicleStatus;
  final bool isChildResuscitation;
  final Map<String, int?> vehicleArrivalMinutes;
  final Qualification userQualification;
  final PredefinedScenario? scenario;

  const ResuscitationScreen({
    super.key,
    required this.vehicleStatus,
    required this.isChildResuscitation,
    required this.vehicleArrivalMinutes,
    required this.userQualification,
    this.scenario,
  });

  @override
  _ResuscitationScreenState createState() => _ResuscitationScreenState();
}

class _ResuscitationScreenState extends State<ResuscitationScreen>
    with TickerProviderStateMixin, ScenarioSessionMixin {
  Map<String, List<String>> get schemas {
    Map<String, List<String>> result = {};
    MeasureRequirements.requirements.forEach((schema, requirements) {
      result[schema] = requirements.map((req) => req.action).toList();
    });
    return result;
  }

  bool _isScored(String schema) =>
      MeasureRequirements.resuscitationSchemas.contains(schema);

  // BPM Functionality
  final List<DateTime> _tapTimestamps = [];
  double _smoothedBPM = 0;

  /// Längere Lücke zwischen zwei Kompressionen = Unterbrechung (Beatmung,
  /// Rhythmusanalyse, Helferwechsel). Die Frequenz wird dann neu gemessen,
  /// statt die Pause als langsame Kompression zu werten.
  static const Duration _maxCompressionGap = Duration(milliseconds: 2000);

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
    _markResuscitationStart(now);

    // Haptic feedback
    HapticFeedback.lightImpact();

    setState(() {
      if (_tapTimestamps.isNotEmpty &&
          now.difference(_tapTimestamps.last) > _maxCompressionGap) {
        _resetBpmMeasurement();
      }
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
    // Start resuscitation with first ventilation for children
    _markResuscitationStart(DateTime.now());

    // Haptic feedback
    HapticFeedback.mediumImpact();

    final now = DateTime.now();

    setState(() {
      _ventilationCount++;
      // Beatmungspause nicht in die Kompressionsfrequenz einrechnen
      _resetBpmMeasurement();

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

  void _resetBpmMeasurement() {
    _tapTimestamps.clear();
    _smoothedBPM = 0;
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
  bool _allExpanded = false;
  DateTime? resuscitationStart;

  /// Zeitpunkte der abgegebenen Schocks (Szenario-Uhr)
  final List<DateTime> _shockTimes = [];

  // AED / Rhythmuskontrolle
  /// Stand der Szenario-Uhr beim Reanimationsbeginn
  Duration? _reaniStartOffset;
  int _lastRhythmCycle = 0;


  /// Reanimationsdauer auf der Szenario-Uhr (ohne Pausen)
  Duration get _reaniElapsed => _reaniStartOffset == null
      ? Duration.zero
      : clock.elapsed - _reaniStartOffset!;

  void _markResuscitationStart(DateTime now) {
    if (resuscitationStart != null) return;
    resuscitationStart = now;
    _reaniStartOffset = clock.elapsed;
  }

  @override
  void initState() {
    super.initState();

    startScenarioSession(widget.vehicleArrivalMinutes);

    // Set ratio based on child/adult resuscitation
    _targetCompressionRatio = widget.isChildResuscitation ? 15 : 30;
    _targetVentilationRatio = 2;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isPaused) return;
      setState(() {
        // Ohne weitere Kompressionen soll keine veraltete (grüne) Frequenz
        // stehen bleiben.
        if (_tapTimestamps.isNotEmpty &&
            DateTime.now().difference(_tapTimestamps.last) >
                _maxCompressionGap) {
          _resetBpmMeasurement();
        }
      });
      // AED-Rhythmuskontrolle: alle 2 min nach Reanimationsstart erinnern.
      // Vergleich über den 2-min-Zyklus statt `% 120 == 0`, damit ein
      // verspäteter Timer-Tick (z. B. 119 → 121 s) keine Erinnerung verschluckt.
      if (_reaniStartOffset != null) {
        final cycle = _reaniElapsed.inSeconds ~/ 120;
        if (cycle > _lastRhythmCycle) {
          _lastRhythmCycle = cycle;
          _showRhythmCheckReminder();
        }
      }
    });

    // Check for vehicle arrivals every second
    _arrivalCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      checkVehicleArrivals();
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

    logRequestedVehicles(widget.vehicleStatus, completedActions);
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
      onlySchemas: MeasureRequirements.resuscitationSchemas,
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
      resuscitationDuration: _reaniElapsed,
      bpmHistory: _bpmHistory,
      ventilationHistory: _ventilationHistory,
      vehicleStatus: widget.vehicleStatus,
      scenarioName: widget.scenario?.name,
      medications: medications,
      medicationNotes: resuscitationMedicationNotes(
        medications: medications,
        shockTimes: _shockTimes,
        resuscitationStart: resuscitationStart,
        medicationsAllowed:
            canDocumentMedication(widget.userQualification),
      ),
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

  void _showRhythmCheckReminder() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Row(
          children: [
            Icon(Icons.monitor_heart, color: Colors.white, size: 32),
            SizedBox(width: 12),
            Text(
              'Rhythmuskontrolle!',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          '2-Minuten-Zyklus abgelaufen.\n\n'
          '→ CPR kurz stoppen\n'
          '→ Herzrhythmus analysieren\n'
          '→ Ggf. Defibrillation',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: const Text(
              'Verstanden – CPR fortsetzen',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmEnd({bool fromBack = false}) => showEndScenarioDialog(
        context,
        fromBack: fromBack,
        onEnd: _endScenario,
        onDiscard: _discardScenario,
      );

  /// Verlässt das Szenario ohne Speichern (nur nach Rückfrage).
  void _discardScenario() {
    if (ended) return;
    ended = true;
    _timer.cancel();
    _arrivalCheckTimer.cancel();
    Navigator.of(context).pop();
  }

  Future<void> _endScenario() async {
    if (ended) return;
    ended = true;
    _timer.cancel();
    _arrivalCheckTimer.cancel();
    clock.stop();
    // Bei der Reanimation werden nur CPR-relevante Schemata bewertet –
    // SAMPLERS, OPQRST, STU usw. sind während einer CPR nicht zu erwarten.
    final missingActions = MeasureRequirements.calculateMissingRequiredActions(
      completedActions,
      widget.userQualification,
      onlySchemas: MeasureRequirements.resuscitationSchemas,
    );

    // Auto-save session to history
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final record = SessionRecord(
      id: sessionId,
      // Start = Öffnen des Szenarios, passend zu durationSeconds
      startTime: scenarioStart,
      durationSeconds: elapsedSeconds,
      qualification: widget.userQualification.name,
      isResuscitation: true,
      isChildResuscitation: widget.isChildResuscitation,
      completedCount: completedActions.length,
      missingCount: missingActions.length,
      requiredCompletedCount: MeasureRequirements.countCompletedRequiredActions(
        completedActions,
        widget.userQualification,
        onlySchemas: MeasureRequirements.resuscitationSchemas,
      ),
      scenarioName: widget.scenario?.name,
      completedActions: List.of(completedActions),
      missingActions: missingActions,
      scoredSchemas: MeasureRequirements.resuscitationSchemas.toList(),
      cpr: CprSummary.fromHistory(
        compressions: _compressionCount,
        ventilations: _ventilationCount,
        bpmHistory: _bpmHistory,
        shockTimes: List.of(_shockTimes),
        startedAt: resuscitationStart,
      ),
      medications: List.of(medications),
    );
    await HistoryService.saveSession(record);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MeasuresOverviewScreen(
          completedActions: completedActions,
          missingActions: missingActions,
          userQualification: widget.userQualification,
          bpmHistory: _bpmHistory,
          ventilationHistory: _ventilationHistory,
          compressionCount: _compressionCount,
          ventilationCount: _ventilationCount,
          resuscitationStart: resuscitationStart,
          sessionId: sessionId,
          scenarioName: widget.scenario?.name,
          scoredSchemas: MeasureRequirements.resuscitationSchemas,
          durationSeconds: elapsedSeconds,
          medications: List.of(medications),
          shockTimes: List.of(_shockTimes),
        ),
      ),
    );
  }

  /// Schock dokumentieren; der erste Schock hakt „Defibrillation“ ab.
  void _registerShock() {
    HapticFeedback.heavyImpact();
    setState(() {
      final now = scenarioNow;
      _shockTimes.add(now);
      if (!completedActions
          .any((e) => e.schema == 'Maßnahmen' && e.action == 'Defibrillation')) {
        completedActions.add(CompletedAction(
          schema: 'Maßnahmen',
          action: 'Defibrillation',
          timestamp: now,
        ));
      }
    });
  }

  /// Zeit seit der letzten Adrenalin-Gabe (Szenario-Uhr), null = noch keine
  Duration? get _sinceLastAdrenalin {
    final times = medications
        .where((m) => m.medication.wirkstoff == 'Adrenalin')
        .map((m) => m.timestamp);
    if (times.isEmpty) return null;
    final last = times.reduce((a, b) => a.isAfter(b) ? a : b);
    return scenarioNow.difference(last);
  }

  /// Schock-Taste, Schnellzugriff auf Adrenalin/Amiodaron und die Zeit seit
  /// dem letzten Adrenalin. Bewusst nur eine Anzeige (grün < 3 min,
  /// orange 3–5 min, rot > 5 min) und kein weiterer Dialog.
  Widget _buildCprActionRow({bool compact = false}) {
    final canMeds = canDocumentMedication(widget.userQualification);
    final since = _sinceLastAdrenalin;
    final sinceColor = since == null
        ? context.mutedText
        : since < const Duration(minutes: 3)
            ? Colors.green
            : since <= const Duration(minutes: 5)
                ? Colors.orange
                : Colors.red;
    final shocks = _shockTimes.length;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 4 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Im kompakten Panel kurze Beschriftungen ohne Symbol, damit alle
          // drei Tasten in eine Zeile passen.
          Wrap(
            spacing: compact ? 4 : 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _cprActionButton(
                label: shocks == 0 ? 'Schock' : 'Schock ($shocks)',
                icon: Icons.bolt,
                compact: compact,
                color: context.strongFg(Colors.amber),
                onPressed: _registerShock,
              ),
              if (canMeds) ...[
                _cprActionButton(
                  label: compact ? 'Adren.' : 'Adrenalin',
                  icon: Icons.vaccines,
                  compact: compact,
                  onPressed: () => addMedication(
                    completedActions,
                    preset: MedicationCatalog.adrenalin,
                    presetRoute: 'i.v.',
                  ),
                ),
                _cprActionButton(
                  label: compact ? 'Amio' : 'Amiodaron',
                  icon: Icons.vaccines,
                  compact: compact,
                  onPressed: () => addMedication(
                    completedActions,
                    preset: MedicationCatalog.amiodaron,
                    presetRoute: 'i.v.',
                  ),
                ),
              ],
            ],
          ),
          if (canMeds && since != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: sinceColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Letztes Adrenalin vor ${formatOffset(since)} min',
                      style: TextStyle(
                          color: sinceColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cprActionButton({
    required String label,
    required IconData icon,
    required bool compact,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: color,
      visualDensity: compact ? VisualDensity.compact : null,
      padding: compact ? const EdgeInsets.symmetric(horizontal: 10) : null,
    );
    return compact
        ? OutlinedButton(onPressed: onPressed, style: style, child: Text(label))
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: Text(label),
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
            colors: [context.softBg(Colors.red), context.softBg(Colors.blue)],
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
                  color: context.softBg(Colors.orange),
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
                        color: context.mutedText,
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
                Flexible(
                  child: _buildStatCard(
                    icon: Icons.compress,
                    label: 'Kompressionen',
                    value: '$_compressionCount',
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _buildStatCard(
                    icon: Icons.air,
                    label: 'Beatmungen',
                    value: '$_ventilationCount',
                    color: Colors.blue,
                  ),
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
                      Flexible(
                        child: Text(
                          'Bis zur Beatmung: ${_targetCompressionRatio - _cycleCompressions} Kompressionen',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
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
                    backgroundColor: context.trackBg,
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
                    style: TextStyle(fontSize: 12, color: context.mutedText),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            // Time since start
            if (resuscitationStart != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: context.softBg(Colors.amber),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, size: 20, color: Colors.amber),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Reanimation seit: ${_reaniElapsed.inMinutes}:${(_reaniElapsed.inSeconds % 60).toString().padLeft(2, '0')} min',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
              color: context.mutedText,
            ),
          ),
        ],
      ),
    );
  }

  static const double _cprPanelWidth = 380;
  static const double _compactCprPanelWidth = 280;

  /// Pause-Banner und ankommende Rettungsmittel über der Schema-Liste.
  List<Widget> _buildStatusSection() {
    return [
      if (isPaused)
        Container(
          width: double.infinity,
          color: Colors.amber.shade700,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pause_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Timer pausiert',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      VehicleArrivalCard(
        vehicleStatus: widget.vehicleStatus,
        arrivalTimes: vehicleArrivalTimes,
        arrivedVehicles: arrivedVehicles,
        now: scenarioNow,
      ),
      if (canDocumentMedication(widget.userQualification))
        MedicationCard(
          administrations: medications,
          formatTimestamp: relativeTime,
          onAdd: () => addMedication(completedActions),
          onRemove: removeMedication,
        ),
    ];
  }

  /// Schema-Karten, CPR-relevante (bewertete) Schemata zuerst.
  List<Widget> _buildSchemaCards() {
    final ordered = [
      ...schemas.keys.where(_isScored),
      ...schemas.keys.where((s) => !_isScored(s)),
    ];
    return ordered
        .map((schema) => SchemaCard(
              schema: schema,
              actions: schemas[schema]!,
              completedActions: completedActions,
              qualification: widget.userQualification,
              expanded: _allExpanded,
              unscoredHint: _isScored(schema)
                  ? null
                  : 'Nicht bewertet bei der Reanimation',
              formatTimestamp: relativeTime,
              onComplete: (action) => setState(() {
                completedActions.add(CompletedAction(
                  schema: schema,
                  action: action,
                  timestamp: scenarioNow,
                ));
              }),
              onUndo: (action) => setState(() {
                completedActions.removeWhere(
                    (e) => e.schema == schema && e.action == action);
              }),
            ))
        .toList();
  }

  /// Beatmungs-Taste. Im CPR-Bedienfeld ([inPanel]) als breite Taste über
  /// die volle Panelbreite, sonst als schwebender Button.
  Widget _buildVentilationButton({bool inPanel = false, bool compact = false}) {
    final label = widget.isChildResuscitation && !_initialVentilationsComplete
        ? 'Initial $_initialVentilationCount/$_requiredInitialVentilations'
        : (_cycleCompressions >= _targetCompressionRatio
            ? 'Beatmung!'
            : 'Beatmung');
    final color = widget.isChildResuscitation && !_initialVentilationsComplete
        ? Colors.orange
        : (_cycleCompressions >= _targetCompressionRatio
            ? Colors.orange
            : Colors.blue);
    // Im Panel ohne Puls-Skalierung: Die breite Taste würde sonst über den
    // Panelrand hinauswachsen.
    if (inPanel) {
      return SizedBox(
        height: compact ? 52 : 72,
        child: FilledButton.icon(
          onPressed: _registerVentilation,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.air, size: 32),
          label: Text(label,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      );
    }
    return ScaleTransition(
      scale: _ventilationAnimation,
      child: FloatingActionButton.extended(
        heroTag: 'ventilation',
        onPressed: _registerVentilation,
        icon: const Icon(Icons.air, size: 32),
        label: Text(label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: color,
      ),
    );
  }

  /// Kompressions-Taste (Frequenzmessung per Antippen). Im CPR-Bedienfeld
  /// ([inPanel]) als große Fläche, damit sie im Takt sicher getroffen wird.
  Widget _buildCompressionButton({bool inPanel = false, bool compact = false}) {
    if (inPanel) {
      return SizedBox(
        height: compact ? 96 : 160,
        child: FilledButton(
          onPressed: _registerTap,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, size: compact ? 40 : 64),
              const SizedBox(height: 4),
              const Text('Kompression',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }
    return ScaleTransition(
      scale: _pulseAnimation,
      child: FloatingActionButton.large(
        heroTag: 'compression',
        onPressed: _registerTap,
        backgroundColor: Colors.red,
        child: const Icon(Icons.favorite, size: 48),
      ),
    );
  }

  /// Festes CPR-Bedienfeld rechts im breiten Layout (Tablet): oben die
  /// Kennzahlen, unten große Tasten für Kompression und Beatmung. Im
  /// Querformat auf dem Smartphone ([compact]) mit verdichteten Kennzahlen
  /// und kleineren Tasten.
  Widget _buildCprPanel({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              if (resuscitationStart == null)
                Padding(
                  padding: EdgeInsets.all(compact ? 12 : 24),
                  child: Text(
                    widget.isChildResuscitation
                        ? 'Mit der ersten Initialbeatmung startet die Reanimation.'
                        : 'Mit der ersten Kompression startet die Reanimation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedText),
                  ),
                )
              else if (compact)
                _buildCompactCprStats()
              else
                _buildReanimationDashboard(),
              _buildCprActionRow(compact: compact),
            ],
          ),
        ),
        Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(12, 4, 12, 12)
              : const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildVentilationButton(inPanel: true, compact: compact),
              SizedBox(height: compact ? 12 : 24),
              _buildCompressionButton(inPanel: true, compact: compact),
            ],
          ),
        ),
      ],
    );
  }

  /// Verdichtete Kennzahlen für das kompakte CPR-Bedienfeld: Frequenz,
  /// Zähler und Fortschritt bis zur nächsten Beatmung.
  Widget _buildCompactCprStats() {
    final initialPhase =
        widget.isChildResuscitation && !_initialVentilationsComplete;
    Widget tile(String value, String label, Color color) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: TextStyle(fontSize: 11, color: context.mutedText)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              tile(_bpm.toStringAsFixed(0), 'BPM', _getBPMColor()),
              tile('$_compressionCount', 'Kompr.', Colors.red),
              tile('$_ventilationCount', 'Beatm.', Colors.blue),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            initialPhase
                ? 'Initialbeatmungen: $_initialVentilationCount / $_requiredInitialVentilations'
                : 'Bis zur Beatmung: ${_targetCompressionRatio - _cycleCompressions}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: initialPhase
                ? _initialVentilationCount / _requiredInitialVentilations
                : _cycleCompressions / _targetCompressionRatio,
            backgroundColor: context.trackBg,
            valueColor: AlwaysStoppedAnimation<Color>(
              initialPhase || _cycleCompressions >= _targetCompressionRatio
                  ? Colors.orange
                  : Colors.green,
            ),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Seitliches CPR-Bedienfeld auf Tablets und – kompakt – auf Smartphones
    // im Querformat, wo die schwebenden Tasten fast die ganze Liste verdecken.
    final compact = isCompactLandscape(context);
    final sidePanel = isWideLayout(context) || compact;
    return PopScope(
      // Zurück-Taste/-Geste soll eine laufende Reanimation nicht
      // kommentarlos verwerfen.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEnd(fromBack: true);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text('Reanimation – $formattedTime (${widget.userQualification.name})'),
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
          // Pause/Weiter
          IconButton(
            icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: isPaused ? 'Timer fortsetzen' : 'Timer pausieren',
            onPressed: togglePause,
          ),
          // Alle Expand / Collapse
          IconButton(
            icon: Icon(_allExpanded ? Icons.unfold_less : Icons.unfold_more),
            tooltip: _allExpanded ? 'Alle einklappen' : 'Alle ausklappen',
            onPressed: () => setState(() => _allExpanded = !_allExpanded),
          ),
          // Dark Mode
          IconButton(
            icon: Icon(
              themeModeNotifier.value == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Dark Mode umschalten',
            onPressed: () {
              themeModeNotifier.value =
                  themeModeNotifier.value == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
            },
          ),
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
                    onlySchemas: MeasureRequirements.resuscitationSchemas,
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
                    scoredSchemas: MeasureRequirements.resuscitationSchemas,
                    medications: List.of(medications),
                    shockTimes: List.of(_shockTimes),
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
            onPressed: () => showMedicalSourcesDialog(
              context,
              schemaSummary: 'SSSS, WASB, (c)ABCDE, SAMPLER, 4H/4T, '
                  'Maßnahmen der Reanimation',
              lastReference:
                  'Thieme via medici – notfallmedizinische Basisdiagnostik '
                  'mit (c)ABCDE- und SAMPLER-Schema.',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle, color: Colors.white),
            tooltip: 'Fallbeispiel beenden',
            onPressed: _confirmEnd,
          ),
        ],
      ),
      body: sidePanel
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      ..._buildStatusSection(),
                      ColumnFlow(
                        // Rechts sitzt das CPR-Bedienfeld, daher eine Spalte
                        // weniger als im Normalmodus.
                        columns: math.max(
                            1,
                            schemaColumnCount(
                                    MediaQuery.sizeOf(context).width) -
                                1),
                        children: _buildSchemaCards(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: compact ? _compactCprPanelWidth : _cprPanelWidth,
                  // Im Querformat kann die Kamera-Aussparung rechts liegen.
                  child: SafeArea(
                    left: false,
                    child: _buildCprPanel(compact: compact),
                  ),
                ),
              ],
            )
          : ListView(
              children: [
                if (resuscitationStart != null) _buildReanimationDashboard(),
                _buildCprActionRow(),
                ..._buildStatusSection(),
                ..._buildSchemaCards(),
                const SizedBox(height: 100), // Space for FABs
              ],
            ),
      floatingActionButton: sidePanel
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildVentilationButton(),
                const SizedBox(height: 16),
                _buildCompressionButton(),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    ),
    );
  }
}
