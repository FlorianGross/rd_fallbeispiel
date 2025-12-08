import 'package:flutter/material.dart';

class MeasuresOverviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> completedActions;
  final List<Map<String, dynamic>> missingActions;

  const MeasuresOverviewScreen({
    super.key,
    required this.completedActions,
    required this.missingActions,
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
      length: 2,
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
                icon: const Icon(Icons.check_circle_outline),
                child: Text(
                  'Durchgeführt (${widget.completedActions.length})',
                  textAlign: TextAlign.center,
                ),
              ),
              Tab(
                icon: const Icon(Icons.warning_amber),
                child: Text(
                  'Fehlend (${widget.missingActions.length})',
                  textAlign: TextAlign.center,
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
}