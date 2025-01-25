import 'package:flutter/material.dart';

class MeasuresOverviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> completedActions;
  final List<Map<String, dynamic>> missingActions;

  MeasuresOverviewScreen(
      {required this.completedActions, required this.missingActions});

  @override
  State<MeasuresOverviewScreen> createState() => _MeasuresOverviewScreenState();
}

class _MeasuresOverviewScreenState extends State<MeasuresOverviewScreen> {
  late DateTime firstTimeStamp;

  @override
  initState() {
    super.initState();
    firstTimeStamp = widget.completedActions[0]['timestamp'] as DateTime;
    print(firstTimeStamp);
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
            ListView.builder(
              itemCount: widget.completedActions.length,
              itemBuilder: (context, index) {
                final action = widget.completedActions[index];
                return ListTile(
                  title: Text("${action['schema']} - ${action['action']}"),
                  subtitle: Text("Seit Beginn: ${((action['timestamp'] as DateTime).difference(firstTimeStamp)).inSeconds} Sekunden"
                      ""),
                  //subtitle: Text("Zeitpunkt: ${action['timestamp']}"),
                );
              },
            ),
            ListView.builder(
              itemCount: widget.missingActions.length,
              itemBuilder: (context, index) {
                final action = widget.missingActions[index];
                return ListTile(
                  title: Text("${action['schema']} - ${action['action']}"),
                );
              },
            ),
          ]),
        ));
  }
}
