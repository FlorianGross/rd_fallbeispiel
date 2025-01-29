import 'package:flutter/material.dart';

class MeasuresOverviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> completedActions;
  final List<Map<String, dynamic>> missingActions;

  const MeasuresOverviewScreen(
      {required this.completedActions, required this.missingActions});

  @override
  State<MeasuresOverviewScreen> createState() => _MeasuresOverviewScreenState();
}

class _MeasuresOverviewScreenState extends State<MeasuresOverviewScreen> {
  late DateTime firstTimeStamp;

  @override
  initState() {
    super.initState();
    if(widget.completedActions.isNotEmpty) {
      firstTimeStamp = widget.completedActions[0]['timestamp'] as DateTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Durchgeführte Maßnahmen'),
            bottom: const TabBar(tabs: [
              Tab(text: 'Durchgeführte Maßnahmen'),
              Tab(text: 'Fehlende Maßnahmen'),
            ]),
          ),
          body: TabBarView(children: [
            widget.completedActions.isEmpty
                ? const Center(child: Text('Keine Maßnahmen durchgeführt'))
                :
            ListView.builder(
              itemCount: widget.completedActions.length,
              itemBuilder: (context, index) {
                final action = widget.completedActions[index];
                if (index == 0) {
                  firstTimeStamp =
                      widget.completedActions[0]['timestamp'] as DateTime;
                } else {
                  firstTimeStamp = widget.completedActions[index - 1]
                      ['timestamp'] as DateTime;
                }
                return ListTile(
                  title: Row(children: [
                    Card(
                      color: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text('${action['schema']}'),
                    ),
                    Text("- ${action['action']}"),
                  ]),
                  subtitle: Text(
                      "+ ${((action['timestamp'] as DateTime).difference(firstTimeStamp)).inSeconds} Sekunden"),
                );
              },
            ),
            ListView.builder(
              itemCount: widget.missingActions.length,
              itemBuilder: (context, index) {
                final action = widget.missingActions[index];
                return ListTile(
                  title: Row(children: [
                    Card(
                      child: Text('${action['schema']}'),
                    ),
                    Text("- ${action['action']}"),
                  ]),
                );
              },
            ),
          ]),
        ));
  }
}
