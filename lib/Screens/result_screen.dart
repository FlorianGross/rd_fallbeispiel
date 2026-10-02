import 'package:flutter/material.dart';
import '../measure_requirements.dart';
import '../models/cpr_summary.dart';
import '../models/medication.dart';
import '../models/resuscitation_notes.dart';
import '../services/history_service.dart';
import '../services/pdf_service.dart';
import '../utils/schema_icons.dart';
import '../utils/adaptive_colors.dart';
import '../widgets/bpm_chart.dart';
import '../widgets/responsive.dart';

class MeasuresOverviewScreen extends StatefulWidget {
  final List<CompletedAction> completedActions;
  final List<MissingAction> missingActions;
  final Qualification? userQualification;
  final List<Map<String, dynamic>>? bpmHistory;
  final List<Map<String, dynamic>>? ventilationHistory;
  final int? compressionCount;
  final int? ventilationCount;
  final DateTime? resuscitationStart;
  final String? sessionId;
  final String? scenarioName;

  /// Schemata, die bewertet wurden (null = alle)
  final Set<String>? scoredSchemas;

  /// Bereits gespeicherte Notiz (beim Öffnen aus dem Verlauf)
  final String? initialNotes;

  /// Aus dem Verlauf geöffnet (kein „automatisch gespeichert“-Hinweis)
  final bool fromHistory;

  /// Szenariodauer für den PDF-Bericht
  final int? durationSeconds;

  /// Gespeicherte Reanimations-Kennzahlen (beim Öffnen aus dem Verlauf, wo
  /// der Frequenzverlauf selbst nicht mehr vorliegt)
  final CprSummary? cprSummary;

  /// Dokumentierte Medikamentengaben
  final List<MedicationAdministration> medications;

  /// Zeitpunkte der Schocks (live aus dem Reanimations-Screen; aus dem
  /// Verlauf stehen sie in [cprSummary])
  final List<DateTime>? shockTimes;

  const MeasuresOverviewScreen({
    super.key,
    required this.completedActions,
    required this.missingActions,
    this.userQualification,
    this.bpmHistory,
    this.ventilationHistory,
    this.compressionCount,
    this.ventilationCount,
    this.resuscitationStart,
    this.sessionId,
    this.scenarioName,
    this.scoredSchemas,
    this.initialNotes,
    this.fromHistory = false,
    this.durationSeconds,
    this.cprSummary,
    this.medications = const [],
    this.shockTimes,
  });

  @override
  State<MeasuresOverviewScreen> createState() => _MeasuresOverviewScreenState();
}

class _MeasuresOverviewScreenState extends State<MeasuresOverviewScreen> {
  late DateTime firstTimeStamp;
  late final TextEditingController _notesCtrl;
  bool _savingNotes = false;

  @override
  void initState() {
    super.initState();
    if (widget.completedActions.isNotEmpty) {
      firstTimeStamp = widget.completedActions.first.timestamp;
    }
    _notesCtrl = TextEditingController(text: widget.initialNotes ?? '');
  }

  /// Bericht inkl. Szenario und aktueller Notiz – auch für Einträge aus dem
  /// Verlauf.
  Future<void> _exportPdf() async {
    try {
      await PdfService.generateNormalPdf(
        completedActions: widget.completedActions,
        missingActions: widget.missingActions,
        userQualification: widget.userQualification!,
        elapsedSeconds: widget.durationSeconds ?? 0,
        scenarioName: widget.scenarioName,
        notes: _notesCtrl.text,
        medications: widget.medications,
        medicationNotes: _medicationNotes,
      );
    } catch (e) {
      debugPrint('PDF-Export fehlgeschlagen: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF konnte nicht erstellt werden'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String _formatTimeDifference(int seconds) {
    if (seconds < 60) {
      return '+$seconds s';
    } else {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '+$minutes:${remainingSeconds.toString().padLeft(2, '0')} min';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              widget.userQualification != null
                  ? 'Maßnahmen Übersicht (${widget.userQualification!.name})'
                  : 'Maßnahmen Übersicht'
          ),
          actions: [
            if (widget.userQualification != null)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'Als PDF exportieren / teilen',
                onPressed: _exportPdf,
              ),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.redAccent, Colors.blueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(
                icon: const Icon(Icons.check_circle_outline, size: 20),
                child: Text(
                  'Durchgeführt\n(${widget.completedActions.length})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              Tab(
                icon: const Icon(Icons.warning_amber, size: 20),
                child: Text(
                  'Fehlend (Verpflichtend)\n(${widget.missingActions.length})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              Tab(
                icon: const Icon(Icons.analytics, size: 20),
                child: Text(
                  'Auswertung',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        body: ResponsiveCenter(
          // Die Auswertung enthält Diagramme – etwas mehr Breite als bei
          // reinen Formularen.
          maxWidth: 900,
          child: TabBarView(
            children: [
              // Completed Actions Tab
              _buildCompletedActionsView(),
              // Missing Actions Tab
              _buildMissingActionsView(),
              // Statistics Tab
              _buildStatisticsView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedActionsView() {
    if (widget.completedActions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Noch keine Maßnahmen durchgeführt',
              style: TextStyle(
                fontSize: 18,
                color: context.mutedText,
              ),
            ),
          ],
        ),
      );
    }

    // Sort by timestamp
    final sorted = List<CompletedAction>.from(widget.completedActions)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final action = sorted[index];
        final timeDiff = action.timestamp.difference(firstTimeStamp).inSeconds;
        final schema = action.schema;
        final actionName = action.action;

        // Check if this action is optional/expected for this qualification
        final requirement = MeasureRequirements.getRequirement(schema, actionName);
        final requirementLevel = widget.userQualification != null
            ? requirement?.getRequirementLevel(widget.userQualification!)
            : RequirementLevel.required;

        final isExpected = requirementLevel == RequirementLevel.expected;
        final isRequired = requirementLevel == RequirementLevel.required;

        // Determine color based on requirement level
        Color borderColor;
        Color backgroundColor;
        Color textColor;
        String? levelText;

        if (isRequired) {
          borderColor = Colors.green.shade200;
          backgroundColor = context.softBg(Colors.green);
          textColor = Colors.green.shade700;
          levelText = null; // No badge for required
        } else if (isExpected) {
          borderColor = Colors.amber.shade300;
          backgroundColor = context.softBg(Colors.amber);
          textColor = Colors.amber.shade700;
          levelText = 'Erwartet';
        } else {
          borderColor = Colors.blue.shade300;
          backgroundColor = context.softBg(Colors.blue);
          textColor = Colors.blue.shade700;
          levelText = 'Optional';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: borderColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            title: Row(
              children: [
                Icon(
                  getSchemaIcon(schema),
                  size: 18,
                  color: context.mutedText,
                ),
                const SizedBox(width: 6),
                Text(
                  schema,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (levelText != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Text(
                      levelText,
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                actionName,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.trackBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatTimeDifference(timeDiff),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: context.mutedText,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMissingActionsView() {
    if (widget.missingActions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration, size: 80, color: Colors.green.shade400),
            const SizedBox(height: 16),
            Text(
              'Alle verpflichtenden Maßnahmen durchgeführt!',
              style: TextStyle(
                fontSize: 18,
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (widget.userQualification != null)
              Text(
                'Für Qualifikation: ${widget.userQualification!.name}',
                style: TextStyle(
                  fontSize: 14,
                  color: context.mutedText,
                ),
              ),
          ],
        ),
      );
    }

    // Group by schema
    Map<String, List<MissingAction>> groupedMissing = {};
    for (var action in widget.missingActions) {
      final schema = action.schema;
      if (!groupedMissing.containsKey(schema)) {
        groupedMissing[schema] = [];
      }
      groupedMissing[schema]!.add(action);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Info Card about qualification
        if (widget.userQualification != null)
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: context.softBg(Colors.blue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade200, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Diese Liste zeigt nur verpflichtende Maßnahmen für deine Qualifikation: ${widget.userQualification!.name}',
                      style: TextStyle(
                        color: context.strongFg(Colors.blue),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        ...groupedMissing.entries.map((entry) {
          final schema = entry.key;
          final actions = entry.value;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.orange.shade300, width: 2),
            ),
            child: ExpansionTile(
              leading: Icon(
                getSchemaIcon(schema),
                color: Colors.orange.shade700,
                size: 28,
              ),
              title: Text(
                schema,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: context.strongFg(Colors.orange),
                ),
              ),
              subtitle: Text(
                '${actions.length} fehlende Maßnahme(n)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade700,
                ),
              ),
              children: actions.map((action) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.softBg(Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.warning_amber,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    title: Text(
                      action.action,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildStatisticsView() {
    // Vollständigkeit = erledigte Pflichtmaßnahmen / alle Pflichtmaßnahmen.
    // Optionale Extras dürfen fehlende Pflichtmaßnahmen nicht ausgleichen.
    final requiredDone = widget.userQualification != null
        ? MeasureRequirements.countCompletedRequiredActions(
            widget.completedActions,
            widget.userQualification!,
            onlySchemas: widget.scoredSchemas,
          )
        : widget.completedActions.length;
    final totalRequired = requiredDone + widget.missingActions.length;
    final completionRate =
        totalRequired > 0 ? (requiredDone / totalRequired * 100) : 0.0;

    // Count by requirement level
    int completedRequired = 0;
    int completedExpected = 0;
    int completedOptional = 0;

    for (var action in widget.completedActions) {
      final requirement = MeasureRequirements.getRequirement(
        action.schema,
        action.action,
      );

      if (widget.userQualification != null) {
        final level = requirement?.getRequirementLevel(widget.userQualification!);
        switch (level) {
          case RequirementLevel.required:
            completedRequired++;
            break;
          case RequirementLevel.expected:
            completedExpected++;
            break;
          case RequirementLevel.optional:
            completedOptional++;
            break;
          case RequirementLevel.notApplicable:
          case null:
          // Shouldn't happen for completed actions
            completedRequired++;
            break;
        }
      } else {
        completedRequired++;
      }
    }

    // Group by schema
    Map<String, int> completedBySchema = {};
    Map<String, int> totalBySchema = {};

    for (var action in widget.completedActions) {
      completedBySchema[action.schema] = (completedBySchema[action.schema] ?? 0) + 1;
      totalBySchema[action.schema] = (totalBySchema[action.schema] ?? 0) + 1;
    }

    for (var action in widget.missingActions) {
      totalBySchema[action.schema] = (totalBySchema[action.schema] ?? 0) + 1;
    }

    // Calculate time statistics
    Duration? totalDuration;
    Duration? averageTimeBetween;

    if (widget.completedActions.length >= 2) {
      final firstAction = widget.completedActions.first.timestamp;
      final lastAction = widget.completedActions.last.timestamp;
      totalDuration = lastAction.difference(firstAction);

      final totalSeconds = totalDuration.inSeconds;
      final actionCount = widget.completedActions.length - 1;
      if (actionCount > 0) {
        averageTimeBetween = Duration(seconds: totalSeconds ~/ actionCount);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sitzung gespeichert Banner
        if (widget.sessionId != null && !widget.fromHistory)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.softBg(Colors.green),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sitzung automatisch gespeichert',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        if (_cprSummary case final cpr?) _buildCprCard(cpr),

        if (widget.medications.isNotEmpty || _cprSummary != null)
          _buildMedicationCard(),

        // Qualification Info Card
        if (widget.userQualification != null)
          Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [context.softBg(Colors.indigo), context.softBg(Colors.purple)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.school, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Qualifikation',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            widget.userQualification!.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.scenarioName != null)
                            Text(
                              widget.scenarioName!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.indigo.shade400,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatChip(
                        Icons.check_circle,
                        '$completedRequired',
                        'Verpflichtend',
                        Colors.green,
                      ),
                      _buildStatChip(
                        Icons.star,
                        '$completedExpected',
                        'Erwartet',
                        Colors.amber,
                      ),
                      _buildStatChip(
                        Icons.add_circle,
                        '$completedOptional',
                        'Optional',
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Overall Statistics Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [context.softBg(Colors.blue), context.softBg(Colors.cyan)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bar_chart, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Gesamtübersicht',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Completion rate circle
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: CircularProgressIndicator(
                                value: completionRate / 100,
                                strokeWidth: 12,
                                backgroundColor: context.trackBg,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  completionRate >= 80 ? Colors.green :
                                  completionRate >= 60 ? Colors.orange : Colors.red,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${completionRate.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: completionRate >= 80 ? Colors.green :
                                    completionRate >= 60 ? Colors.orange : Colors.red,
                                  ),
                                ),
                                Text(
                                  'Vollständigkeit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatChip(
                            Icons.check_circle,
                            '${widget.completedActions.length}',
                            'Durchgeführt',
                            Colors.green,
                          ),
                          _buildStatChip(
                            Icons.cancel,
                            '${widget.missingActions.length}',
                            'Fehlend',
                            Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Time Statistics (if available)
        if (totalDuration != null) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer, color: Colors.purple.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Zeitstatistik',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTimeStatRow(
                    'Gesamtdauer',
                    '${totalDuration.inMinutes}:${(totalDuration.inSeconds % 60).toString().padLeft(2, '0')} min',
                  ),
                  if (averageTimeBetween != null)
                    _buildTimeStatRow(
                      'Ø Zeit zwischen Maßnahmen',
                      '${averageTimeBetween.inSeconds} s',
                    ),
                ],
              ),
            ),
          ),
        ],

        // Schema breakdown
        if (totalBySchema.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.category, color: Colors.orange.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Maßnahmen pro Schema',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...totalBySchema.entries.map((entry) {
                    final schema = entry.key;
                    final total = entry.value;
                    final completed = completedBySchema[schema] ?? 0;
                    final percentage = (completed / total * 100).toStringAsFixed(0);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(getSchemaIcon(schema), size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    schema,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Text(
                                '$completed/$total ($percentage%)',
                                style: TextStyle(
                                  color: context.mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: completed / total,
                            backgroundColor: context.trackBg,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              completed == total ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],

        // Notes card (only when session is saved)
        if (widget.sessionId != null) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note_alt, color: Colors.teal.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Notizen zur Übung',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Was lief gut? Was kann verbessert werden?',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _savingNotes
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: const Text('Notiz speichern'),
                      onPressed: _savingNotes
                          ? null
                          : () async {
                              setState(() => _savingNotes = true);
                              var saved = false;
                              try {
                                await HistoryService.updateSessionNotes(
                                    widget.sessionId!, _notesCtrl.text);
                                saved = true;
                              } catch (e) {
                                debugPrint('Notiz speichern fehlgeschlagen: $e');
                              } finally {
                                if (mounted) {
                                  setState(() => _savingNotes = false);
                                }
                              }
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(saved
                                      ? 'Notiz gespeichert!'
                                      : 'Notiz konnte nicht gespeichert werden'),
                                  backgroundColor:
                                      saved ? Colors.green : Colors.red,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  CprSummary? get _cprSummary =>
      widget.cprSummary ??
      (widget.compressionCount == null
          ? null
          : CprSummary.fromHistory(
              compressions: widget.compressionCount!,
              ventilations: widget.ventilationCount ?? 0,
              bpmHistory: widget.bpmHistory ?? const [],
              shockTimes: widget.shockTimes,
              startedAt: widget.resuscitationStart,
            ));

  /// Beschreibende Hinweise zu Adrenalin, Amiodaron und Schocks (nur bei
  /// Reanimationen)
  List<String> get _medicationNotes {
    final cpr = _cprSummary;
    if (cpr == null) return const [];
    return resuscitationMedicationNotes(
      medications: widget.medications,
      shockTimes: cpr.shockTimes ?? const [],
      resuscitationStart: cpr.startedAt ?? widget.resuscitationStart,
    );
  }

  /// Gegebene Medikamente (Zeit relativ zur ersten Maßnahme) und bei der
  /// Reanimation die Hinweise zu Adrenalin/Amiodaron/Schocks
  Widget _buildMedicationCard() {
    final meds = List<MedicationAdministration>.of(widget.medications)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final starts = [
      ...widget.completedActions.map((a) => a.timestamp),
      ...meds.map((m) => m.timestamp),
    ];
    final t0 = starts.isEmpty
        ? DateTime.now()
        : starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final notes = _medicationNotes;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vaccines, color: context.strongFg(Colors.indigo)),
                const SizedBox(width: 8),
                const Text('Medikamente',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            if (meds.isEmpty)
              Text('Keine Medikamente dokumentiert',
                  style: TextStyle(color: context.mutedText)),
            for (final m in meds)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        '+${formatOffset(m.timestamp.difference(t0))}',
                        style: TextStyle(color: context.mutedText),
                      ),
                    ),
                    Expanded(
                      child: Text(
                          '${m.medication.wirkstoff} ${m.dose} ${m.route}'),
                    ),
                  ],
                ),
              ),
            if (notes.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Hinweise zur Nachbesprechung',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: context.mutedText)),
              const SizedBox(height: 4),
              for (final n in notes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: context.mutedText),
                      const SizedBox(width: 6),
                      Expanded(child: Text(n)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Kennzahlen + Frequenzverlauf der Reanimation
  Widget _buildCprCard(CprSummary cpr) {
    final share = cpr.targetShare;
    // Status immer mit Symbol + Text, nie nur über die Farbe
    final (IconData statusIcon, Color statusColor, String statusText) =
        switch (share) {
      null => (Icons.help_outline, context.mutedText, 'keine Messung'),
      >= 0.8 => (Icons.check_circle, Colors.green, 'gut'),
      >= 0.5 => (Icons.warning_amber, Colors.orange, 'mäßig'),
      _ => (Icons.error_outline, Colors.red, 'niedrig'),
    };
    final showChart = (widget.bpmHistory?.isNotEmpty ?? false) &&
        widget.resuscitationStart != null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_heart, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Reanimation',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: [
                _cprTile('${cpr.compressions}', 'Kompressionen'),
                _cprTile('${cpr.ventilations}', 'Beatmungen'),
                _cprTile(
                  cpr.averageBpm > 0
                      ? '${cpr.averageBpm.toStringAsFixed(0)}/min'
                      : '–',
                  'Ø Frequenz',
                ),
                _cprTile(
                  share == null ? '–' : '${(share * 100).toStringAsFixed(0)} %',
                  'im Zielbereich',
                  status: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(statusText,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 11, color: statusColor)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showChart) ...[
              const SizedBox(height: 16),
              BpmChart(
                bpmHistory: widget.bpmHistory!,
                ventilationHistory: widget.ventilationHistory ?? const [],
                start: widget.resuscitationStart!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cprTile(String value, String label, {Widget? status}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.softBg(Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.onSurface,
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 8),
                Flexible(child: status),
              ],
            ],
          ),
          Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.mutedText)),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
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
    );
  }

  Widget _buildTimeStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}