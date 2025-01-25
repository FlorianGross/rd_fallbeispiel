import 'package:flutter/material.dart';

class MeasuresOverviewScreen extends StatelessWidget {
  final List<Map<String, dynamic>> completedActions;
  MeasuresOverviewScreen({required this.completedActions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Durchgeführte Maßnahmen')),
      body: ListView.builder(
        itemCount: completedActions.length,
        itemBuilder: (context, index) {
          final action = completedActions[index];
          return ListTile(
            title: Text("${action['schema']} - ${action['action']}"),
            subtitle: Text("Zeitpunkt: ${action['timestamp']}"),
          );
        },
      ),
    );
  }
}