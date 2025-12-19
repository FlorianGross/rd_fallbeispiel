import 'package:flutter/material.dart';
import '../measure_requirements.dart';

class MeasuresOverviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> completedActions;
  final List<Map<String, dynamic>> missingActions;
  final Qualification? userQualification;
  final List<Map<String, dynamic>>? bpmHistory;
  final List<Map<String, dynamic>>? ventilationHistory;
  final int? compressionCount;
  final int? ventilationCount;
  final DateTime? resuscitationStart;

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
  });

  @override
  State<MeasuresOverviewScreen> createState() => _MeasuresOverviewScreenState();
}

class _MeasuresOverviewScreenState extends State<MeasuresOverviewScreen> {
  late DateTime firstTimeStamp;

  @override
  initState() {
    super.initState();
    if (widget.completedActions.isNotEmpty) {
      firstTimeStamp = widget.completedActions[0]['timestamp'] as DateTime;
    }
  }

  IconData _getSchemaIcon(String schema) {
    if (schema.contains('Atemwege') || schema == 'a' || schema == 'A') {
      return Icons.air;
    } else if (schema.contains('Atmung') || schema == 'b' || schema == 'B') {
      return Icons.wind_power;
    } else if (schema.contains('Kreislauf') || schema == 'c' || schema == 'C') {
      return Icons.favorite;
    } else if (schema == 'SSSS') {
      return Icons.security;
    } else if (schema == 'WASB') {
      return Icons.psychology;
    } else if (schema == 'STU') {
      return Icons.personal_injury;
    } else if (schema == 'D') {
      return Icons.visibility;
    } else if (schema == 'E') {
      return Icons.thermostat;
    } else if (schema == 'BE-FAST') {
      return Icons.emergency;
    } else if (schema == 'ZOPS') {
      return Icons.quiz;
    } else if (schema.contains('Maßnahmen')) {
      return Icons.medical_services;
    } else if (schema == 'SAMPLERS') {
      return Icons.history_edu;
    } else if (schema == 'OPQRST') {
      return Icons.description;
    } else if (schema == 'Nachforderung') {
      return Icons.phone_in_talk;
    } else if (schema == '4H') {
      return Icons.water_drop;
    } else if (schema == 'HITS') {
      return Icons.coronavirus;
    }
    return Icons.checklist;
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
        body: TabBarView(
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
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // Sort by timestamp
    final sorted = List<Map<String, dynamic>>.from(widget.completedActions);
    sorted.sort((a, b) {
      final timeA = a['timestamp'] as DateTime;
      final timeB = b['timestamp'] as DateTime;
      return timeA.compareTo(timeB);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final action = sorted[index];
        final timestamp = action['timestamp'] as DateTime;
        final timeDiff = timestamp.difference(firstTimeStamp).inSeconds;
        final schema = action['schema'] as String;
        final actionName = action['action'] as String;

        // Check if this action is optional/expected for this qualification
        final requirement = MeasureRequirements.getRequirement(schema, actionName);
        final requirementLevel = widget.userQualification != null
            ? requirement?.getRequirementLevel(widget.userQualification!)
            : RequirementLevel.required;

        final isOptional = requirementLevel == RequirementLevel.optional;
        final isExpected = requirementLevel == RequirementLevel.expected;
        final isRequired = requirementLevel == RequirementLevel.required;

        // Determine color based on requirement level
        Color borderColor;
        Color backgroundColor;
        Color textColor;
        String? levelText;

        if (isRequired) {
          borderColor = Colors.green.shade200;
          backgroundColor = Colors.green.shade50;
          textColor = Colors.green.shade700;
          levelText = null; // No badge for required
        } else if (isExpected) {
          borderColor = Colors.amber.shade300;
          backgroundColor = Colors.amber.shade50;
          textColor = Colors.amber.shade700;
          levelText = 'Erwartet';
        } else {
          borderColor = Colors.blue.shade300;
          backgroundColor = Colors.blue.shade50;
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
                  _getSchemaIcon(schema),
                  size: 18,
                  color: Colors.grey.shade700,
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
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatTimeDifference(timeDiff),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey.shade800,
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
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
      );
    }

    // Group by schema
    Map<String, List<Map<String, dynamic>>> groupedMissing = {};
    for (var action in widget.missingActions) {
      final schema = action['schema'] as String;
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
            color: Colors.blue.shade50,
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
                        color: Colors.blue.shade900,
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
                _getSchemaIcon(schema),
                color: Colors.orange.shade700,
                size: 28,
              ),
              title: Text(
                schema,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.orange.shade900,
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
                final actionName = action['action'] as String;
                final requiredQual = action['requiredQualification'] as Qualification?;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
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
                      actionName,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: requiredQual != null
                        ? Text(
                      'Erfordert: ${requiredQual.name}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    )
                        : null,
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
    // Calculate statistics
    final totalActions = widget.completedActions.length + widget.missingActions.length;
    final completionRate = totalActions > 0
        ? (widget.completedActions.length / totalActions * 100)
        : 0.0;

    // Count by requirement level
    int completedRequired = 0;
    int completedExpected = 0;
    int completedOptional = 0;

    for (var action in widget.completedActions) {
      final requirement = MeasureRequirements.getRequirement(
        action['schema'] as String,
        action['action'] as String,
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
      final schema = action['schema'] as String;
      completedBySchema[schema] = (completedBySchema[schema] ?? 0) + 1;
    }

    for (var action in widget.completedActions) {
      final schema = action['schema'] as String;
      totalBySchema[schema] = (totalBySchema[schema] ?? 0) + 1;
    }

    for (var action in widget.missingActions) {
      final schema = action['schema'] as String;
      totalBySchema[schema] = (totalBySchema[schema] ?? 0) + 1;
    }

    // Calculate time statistics
    Duration? totalDuration;
    Duration? averageTimeBetween;

    if (widget.completedActions.length >= 2) {
      final firstAction = widget.completedActions.first['timestamp'] as DateTime;
      final lastAction = widget.completedActions.last['timestamp'] as DateTime;
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
                  colors: [Colors.indigo.shade50, Colors.purple.shade50],
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
                colors: [Colors.blue.shade50, Colors.cyan.shade50],
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
                                backgroundColor: Colors.grey.shade300,
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
                                    color: Colors.grey.shade700,
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
                                  Icon(_getSchemaIcon(schema), size: 16),
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
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: completed / total,
                            backgroundColor: Colors.grey.shade200,
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
      ],
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
            color: Colors.grey.shade700,
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