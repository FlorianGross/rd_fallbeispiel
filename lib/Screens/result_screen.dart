import 'package:flutter/material.dart';

class MeasuresOverviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> completedActions;
  final List<Map<String, dynamic>> missingActions;
  final List<Map<String, dynamic>>? bpmHistory;
  final List<Map<String, dynamic>>? ventilationHistory;
  final int? compressionCount;
  final int? ventilationCount;
  final DateTime? resuscitationStart;

  const MeasuresOverviewScreen({
    super.key,
    required this.completedActions,
    required this.missingActions,
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
          title: const Text('Maßnahmen Übersicht'),
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
                  'Fehlend\n(${widget.missingActions.length})',
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

  Widget _buildStatisticsView() {
    // Calculate statistics
    final totalActions = widget.completedActions.length + widget.missingActions.length;
    final completionRate = totalActions > 0
        ? (widget.completedActions.length / totalActions * 100)
        : 0.0;

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
        // Overall Statistics Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.purple.shade50],
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

        const SizedBox(height: 16),

        // Time Statistics Card
        if (totalDuration != null)
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.orange.shade50, Colors.amber.shade50],
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
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.access_time, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Zeitstatistik',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildTimeStatRow(
                    'Gesamtdauer',
                    '${totalDuration.inMinutes}:${(totalDuration.inSeconds % 60).toString().padLeft(2, '0')} min',
                    Icons.timer,
                  ),
                  const Divider(height: 20),
                  _buildTimeStatRow(
                    'Durchschn. Zeit/Maßnahme',
                    averageTimeBetween != null
                        ? '${averageTimeBetween.inSeconds} s'
                        : 'N/A',
                    Icons.speed,
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Schema Breakdown Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.green.shade50, Colors.teal.shade50],
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
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.category, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Schemata-Übersicht',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                ...totalBySchema.entries.map((entry) {
                  final schema = entry.key;
                  final total = entry.value;
                  final completed = completedBySchema[schema] ?? 0;
                  final percentage = (completed / total * 100);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(_getSchemaIcon(schema), size: 20, color: Colors.grey.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  schema,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$completed/$total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: percentage == 100 ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percentage == 100 ? Colors.green :
                            percentage >= 50 ? Colors.orange : Colors.red,
                          ),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Reanimation Statistics (if available)
        if (widget.bpmHistory != null && widget.bpmHistory!.isNotEmpty)
          _buildReanimationStatistics(),

        const SizedBox(height: 16),

        // Performance Badge
        Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: completionRate >= 80
                    ? [Colors.green.shade400, Colors.green.shade600]
                    : completionRate >= 60
                    ? [Colors.orange.shade400, Colors.orange.shade600]
                    : [Colors.red.shade400, Colors.red.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  completionRate >= 80 ? Icons.emoji_events :
                  completionRate >= 60 ? Icons.thumb_up : Icons.info,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  completionRate >= 80 ? 'Hervorragend!' :
                  completionRate >= 60 ? 'Gut gemacht!' : 'Verbesserungspotential',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  completionRate >= 80
                      ? 'Sehr gründliche Patientenversorgung'
                      : completionRate >= 60
                      ? 'Solide Leistung, einige Punkte wurden ausgelassen'
                      : 'Achte auf die fehlenden Maßnahmen',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color) {
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

  Widget _buildTimeStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade900,
          ),
        ),
      ],
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
              'Keine Maßnahmen durchgeführt',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: widget.completedActions.length,
      itemBuilder: (context, index) {
        final action = widget.completedActions[index];

        if (index == 0) {
          firstTimeStamp = widget.completedActions[0]['timestamp'] as DateTime;
        } else {
          firstTimeStamp =
          widget.completedActions[index - 1]['timestamp'] as DateTime;
        }

        final timeDiff = ((action['timestamp'] as DateTime)
            .difference(firstTimeStamp))
            .inSeconds;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.green.shade200, width: 1),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.green.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _getSchemaIcon(action['schema']),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      action['schema'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      action['action'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimeDifference(timeDiff),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
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
            Icon(Icons.check_circle, size: 80, color: Colors.green.shade400),
            const SizedBox(height: 16),
            Text(
              'Alle Maßnahmen durchgeführt!',
              style: TextStyle(
                fontSize: 18,
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hervorragende Arbeit!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // Group missing actions by schema
    Map<String, List<String>> groupedActions = {};
    for (var action in widget.missingActions) {
      final schema = action['schema'] as String;
      final actionName = action['action'] as String;

      if (!groupedActions.containsKey(schema)) {
        groupedActions[schema] = [];
      }
      groupedActions[schema]!.add(actionName);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: groupedActions.length,
      itemBuilder: (context, index) {
        final schema = groupedActions.keys.elementAt(index);
        final actions = groupedActions[schema]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange.shade200, width: 1),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _getSchemaIcon(schema),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      schema,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${actions.length} fehlend',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              children: actions.map((action) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.radio_button_unchecked,
                      color: Colors.orange.shade400,
                      size: 20,
                    ),
                    title: Text(
                      action,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReanimationStatistics() {
    final bpmHistory = widget.bpmHistory!;
    final avgBPM = bpmHistory.map((e) => e['bpm'] as double).reduce((a, b) => a + b) / bpmHistory.length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.red.shade50, Colors.pink.shade50],
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
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Reanimations-Auswertung',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              padding: const EdgeInsets.all(16),
              child: CustomPaint(
                painter: BPMLineGraphPainter(
                  bpmHistory: bpmHistory,
                  ventilationHistory: widget.ventilationHistory ?? [],
                  resuscitationStart: widget.resuscitationStart,
                ),
                child: Container(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Durchschnitt: ${avgBPM.toStringAsFixed(0)} BPM'),
          ],
        ),
      ),
    );
  }
}

class BPMLineGraphPainter extends CustomPainter {
  final List<Map<String, dynamic>> bpmHistory;
  final List<Map<String, dynamic>> ventilationHistory;
  final DateTime? resuscitationStart;

  BPMLineGraphPainter({
    required this.bpmHistory,
    required this.ventilationHistory,
    this.resuscitationStart,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bpmHistory.isEmpty || resuscitationStart == null) return;

    final padding = 40.0;
    final graphWidth = size.width - 2 * padding;
    final graphHeight = size.height - 2 * padding;

    final startTime = resuscitationStart!;
    final endTime = bpmHistory.last['timestamp'] as DateTime;
    final totalSeconds = endTime.difference(startTime).inSeconds.toDouble();

    if (totalSeconds <= 0) return;

    const minBPM = 0.0;
    const maxBPM = 150.0;

    // Draw target zone backgrounds (100-120 BPM)
    final targetMinY = padding + graphHeight * (1 - (100 - minBPM) / (maxBPM - minBPM));
    final targetMaxY = padding + graphHeight * (1 - (120 - minBPM) / (maxBPM - minBPM));

    final targetZonePaint = Paint()
      ..color = Colors.green.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTRB(padding, targetMaxY, size.width - padding, targetMinY),
      targetZonePaint,
    );

    // Draw acceptable zone backgrounds (90-100 and 120-130 BPM)
    final acceptable1MinY = padding + graphHeight * (1 - (90 - minBPM) / (maxBPM - minBPM));
    final acceptable1MaxY = padding + graphHeight * (1 - (100 - minBPM) / (maxBPM - minBPM));

    final acceptable2MinY = padding + graphHeight * (1 - (120 - minBPM) / (maxBPM - minBPM));
    final acceptable2MaxY = padding + graphHeight * (1 - (130 - minBPM) / (maxBPM - minBPM));

    final acceptableZonePaint = Paint()
      ..color = Colors.orange.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTRB(padding, acceptable1MaxY, size.width - padding, acceptable1MinY),
      acceptableZonePaint,
    );

    canvas.drawRect(
      Rect.fromLTRB(padding, acceptable2MaxY, size.width - padding, acceptable2MinY),
      acceptableZonePaint,
    );

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    for (int i = 0; i <= 5; i++) {
      final y = padding + graphHeight * i / 5;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // Draw BPM line segments with color coding
    for (int i = 1; i < bpmHistory.length; i++) {
      final prevData = bpmHistory[i - 1];
      final currData = bpmHistory[i];

      final prevTime = (prevData['timestamp'] as DateTime).difference(startTime).inSeconds;
      final currTime = (currData['timestamp'] as DateTime).difference(startTime).inSeconds;

      final prevBpm = prevData['bpm'] as double;
      final currBpm = currData['bpm'] as double;

      final x1 = padding + graphWidth * (prevTime / totalSeconds);
      final y1 = padding + graphHeight * (1 - (prevBpm - minBPM) / (maxBPM - minBPM));

      final x2 = padding + graphWidth * (currTime / totalSeconds);
      final y2 = padding + graphHeight * (1 - (currBpm - minBPM) / (maxBPM - minBPM));

      // Determine color based on current BPM
      Color lineColor;
      if (currBpm >= 100 && currBpm <= 120) {
        lineColor = Colors.green;
      } else if (currBpm >= 90 && currBpm <= 130) {
        lineColor = Colors.orange;
      } else {
        lineColor = Colors.red;
      }

      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);

      // Draw a small circle at each data point
      final pointPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x2, y2), 3, pointPaint);
    }

    // Draw first point
    if (bpmHistory.isNotEmpty) {
      final firstData = bpmHistory[0];
      final firstBpm = firstData['bpm'] as double;
      final firstTime = (firstData['timestamp'] as DateTime).difference(startTime).inSeconds;

      final x = padding + graphWidth * (firstTime / totalSeconds);
      final y = padding + graphHeight * (1 - (firstBpm - minBPM) / (maxBPM - minBPM));

      Color pointColor;
      if (firstBpm >= 100 && firstBpm <= 120) {
        pointColor = Colors.green;
      } else if (firstBpm >= 90 && firstBpm <= 130) {
        pointColor = Colors.orange;
      } else {
        pointColor = Colors.red;
      }

      final pointPaint = Paint()
        ..color = pointColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }

    // Draw ventilation markers
    final ventPaint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..strokeWidth = 2;

    for (var ventilation in ventilationHistory) {
      final ventTime = (ventilation['timestamp'] as DateTime).difference(startTime).inSeconds;
      if (ventTime <= totalSeconds && ventTime >= 0) {
        final x = padding + graphWidth * (ventTime / totalSeconds);

        canvas.drawLine(
          Offset(x, padding),
          Offset(x, size.height - padding),
          ventPaint,
        );
      }
    }

    // Draw axes
    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    // Y-axis
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );

    // X-axis
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );

    // Draw labels
    final textStyle = TextStyle(
      color: Colors.grey.shade700,
      fontSize: 10,
    );

    // Y-axis labels (BPM values)
    for (int i = 0; i <= 5; i++) {
      final bpmValue = (maxBPM - (maxBPM - minBPM) * i / 5).toInt();
      final y = padding + graphHeight * i / 5;

      final textSpan = TextSpan(
        text: '$bpmValue',
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - 6));
    }

    // X-axis labels (time in seconds)
    for (int i = 0; i <= 5; i++) {
      final seconds = (totalSeconds * i / 5).toInt();
      final x = padding + graphWidth * i / 5;

      final textSpan = TextSpan(
        text: '${seconds}s',
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - 10, size.height - padding + 10));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}