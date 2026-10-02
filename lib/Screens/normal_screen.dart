import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../measure_requirements.dart';
import '../models/scenario.dart';
import '../models/session_record.dart';
import '../services/history_service.dart';
import '../services/pdf_service.dart';
import '../utils/adaptive_colors.dart';
import '../widgets/responsive.dart';
import '../widgets/scenario_common.dart';
import 'result_screen.dart';
import 'scenario_session.dart';

class SchemaSelectionScreen extends StatefulWidget {
  final Map<String, VehicleStatus> vehicleStatus;
  final Map<String, int?> vehicleArrivalMinutes;
  final Qualification userQualification;
  /// Gewähltes Fallbeispiel (optional). Bestimmt, welche Schemata bewertet
  /// werden, und liefert das Fallbild.
  final PredefinedScenario? scenario;

  const SchemaSelectionScreen({
    super.key,
    required this.vehicleStatus,
    required this.vehicleArrivalMinutes,
    required this.userQualification,
    this.scenario,
  });

  @override
  _SchemaSelectionScreenState createState() => _SchemaSelectionScreenState();
}

class _SchemaSelectionScreenState extends State<SchemaSelectionScreen>
    with ScenarioSessionMixin {
  // Verwende die Requirements aus dem Model
  Map<String, List<String>> get schemas {
    Map<String, List<String>> result = {};
    MeasureRequirements.requirements.forEach((schema, requirements) {
      result[schema] = requirements.map((req) => req.action).toList();
    });
    return result;
  }

  List<CompletedAction> completedActions = [];
  late Timer _timer;
  late Timer _arrivalCheckTimer;
  bool _allExpanded = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();


  /// Anzahl vollständig abgehakter Schemata (nur verpflichtende + erwartete)
  /// Bewertete Schemata (null = alle, wenn kein Szenario gewählt ist)
  Set<String>? get _scoredSchemas => widget.scenario?.scoredSchemas;

  bool _isScored(String schema) => _scoredSchemas?.contains(schema) ?? true;

  /// Bewertete Schemata zuerst, nicht bewertete am Ende (Reihenfolge sonst
  /// wie im Katalog).
  List<String> get _orderedSchemas => [
        ...schemas.keys.where(_isScored),
        ...schemas.keys.where((s) => !_isScored(s)),
      ];

  List<MissingAction> _missingActions() =>
      MeasureRequirements.calculateMissingRequiredActions(
        completedActions,
        widget.userQualification,
        onlySchemas: _scoredSchemas,
      );

  /// Schemata, die in den Fortschritt eingehen: bewertet und mit mindestens
  /// einer verpflichtenden/erwarteten Maßnahme für diese Qualifikation.
  Iterable<String> get _progressSchemas => schemas.keys.where((schema) =>
      _isScored(schema) &&
      MeasureRequirements.hasCountedMeasures(
          schema, widget.userQualification));

  int get _completedSchemaCount {
    return _progressSchemas
        .where((schema) => MeasureRequirements.isSchemaComplete(
            schema, completedActions, widget.userQualification))
        .length;
  }

  @override
  void initState() {
    super.initState();

    startScenarioSession(widget.vehicleArrivalMinutes);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused) setState(() {});
    });

    // Check for vehicle arrivals every second
    _arrivalCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      checkVehicleArrivals();
    });

    logRequestedVehicles(widget.vehicleStatus, completedActions);
  }

  @override
  void dispose() {
    _timer.cancel();
    _arrivalCheckTimer.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> generatePDF() async {
    final missingActions = _missingActions();
    await PdfService.generateNormalPdf(
      completedActions: completedActions,
      missingActions: missingActions,
      userQualification: widget.userQualification,
      elapsedSeconds: elapsedSeconds,
      scenarioName: widget.scenario?.name,
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
    final missingActions = _missingActions();

    // Auto-save session to history
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final record = SessionRecord(
      id: sessionId,
      startTime: scenarioStart,
      durationSeconds: elapsedSeconds,
      qualification: widget.userQualification.name,
      isResuscitation: false,
      completedCount: completedActions.length,
      missingCount: missingActions.length,
      requiredCompletedCount: MeasureRequirements.countCompletedRequiredActions(
        completedActions,
        widget.userQualification,
        onlySchemas: _scoredSchemas,
      ),
      scenarioName: widget.scenario?.name,
      completedActions: List.of(completedActions),
      missingActions: missingActions,
      scoredSchemas: _scoredSchemas?.toList(),
    );
    await HistoryService.saveSession(record);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MeasuresOverviewScreen(
          completedActions: completedActions,
          missingActions: missingActions,
          userQualification: widget.userQualification,
          sessionId: sessionId,
          scenarioName: widget.scenario?.name,
          scoredSchemas: _scoredSchemas,
          durationSeconds: elapsedSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate missing required actions for this user
    final missingActions = _missingActions();

    return PopScope(
      // Zurück-Taste/-Geste soll ein laufendes Fallbeispiel nicht
      // kommentarlos verwerfen.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEnd(fromBack: true);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(
            'Schemata – $formattedTime (${widget.userQualification.name})'),
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
                  return MeasuresOverviewScreen(
                    completedActions: completedActions,
                    missingActions: missingActions,
                    userQualification: widget.userQualification,
                    scenarioName: widget.scenario?.name,
                    scoredSchemas: _scoredSchemas,
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
              schemaSummary:
                  '(c)ABCDE, SAMPLER, OPQRST, BE-FAST, WASB, STU, A–E, Maßnahmen',
              lastReference:
                  'Thieme via medici – notfallmedizinische Basisdiagnostik mit '
                  '(c)ABCDE- und SAMPLER-Schema.',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle, color: Colors.white),
            tooltip: 'Fallbeispiel beenden',
            onPressed: _confirmEnd,
          ),
        ],
      ),
      body: Column(
        children: [
          // Gesamtfortschrittsbalken
          _buildProgressBar(),
          if (widget.scenario != null) _buildScenarioCard(widget.scenario!),
          // Pause-Banner
          if (isPaused)
            Container(
              width: double.infinity,
              color: Colors.amber.shade700,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause_circle, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Timer pausiert',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          // Schema-Suchleiste
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Schema suchen...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: ListView(
        children: [
          // Vehicle arrival status
          VehicleArrivalCard(
            vehicleStatus: widget.vehicleStatus,
            arrivalTimes: vehicleArrivalTimes,
            arrivedVehicles: arrivedVehicles,
            now: scenarioNow,
          ),

          ColumnFlow(
            columns: schemaColumnCount(MediaQuery.sizeOf(context).width),
            children: _orderedSchemas.where((schema) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return schema.toLowerCase().contains(q) ||
                (schemas[schema] ?? [])
                    .any((a) => a.toLowerCase().contains(q));
          }).map((schema) => SchemaCard(
                schema: schema,
                actions: schemas[schema]!,
                completedActions: completedActions,
                qualification: widget.userQualification,
                expanded: _allExpanded,
                unscoredHint: _isScored(schema)
                    ? null
                    : 'Nicht bewertet in diesem Szenario',
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
              )).toList(),
          ),
              const SizedBox(height: 20), // Bottom padding
            ],
          ),
          ),
        ],
      ),
    ),
    );
  }

  /// Fallbild des gewählten Szenarios – einklappbar, damit es während des
  /// Trainings nachgelesen werden kann, ohne Platz zu blockieren.
  Widget _buildScenarioCard(PredefinedScenario scenario) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scenario.color.withAlpha(100), width: 1.5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(scenario.icon, color: scenario.color),
          title: Text(
            scenario.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Fallbild anzeigen',
            style: TextStyle(fontSize: 12, color: context.mutedText),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(scenario.clinicalPicture),
            if (scenario.extraSchemas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Zusätzlich bewertet: ${scenario.extraSchemas.join(', ')}',
                style: TextStyle(fontSize: 12, color: context.mutedText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = _progressSchemas.length;
    final done = _completedSchemaCount;
    final progress = total > 0 ? done / total : 0.0;
    final color = progress >= 1.0
        ? Colors.green
        : progress >= 0.5
            ? Colors.blue
            : Colors.orange;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fortschritt: $done / $total Schemata',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)} %',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: context.trackBg,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}