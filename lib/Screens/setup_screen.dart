import 'package:flutter/material.dart';
import 'package:rd_fallbeispiel/Screens/resuscitation_screen.dart';

import 'normal_screen.dart';

class QualificationSelectionScreen extends StatefulWidget {
  const QualificationSelectionScreen({super.key});

  @override
  _QualificationSelectionScreenState createState() =>
      _QualificationSelectionScreenState();
}

class _QualificationSelectionScreenState
    extends State<QualificationSelectionScreen> {
  final List<String> qualifications = ['SAN', 'RH', 'RS'];
  String selectedQualification = '';
  final List<String> vehicles = ['None', 'KTW', 'RTW', 'NEF', 'RTH'];
  Map<String, int> vehicleStatus = {};
  late bool isResuscitation = false;
  late bool isChildResuscitation = false;

  final Map<int, Color> statusColors = {
    0: Colors.grey,
    1: Colors.blue,
    2: Colors.red,
  };

  final Map<int, String> statusLabels = {
    0: '',
    1: 'besetzt',
    2: 'kommt',
  };

  @override
  void initState() {
    super.initState();
    for (var vehicle in vehicles) {
      vehicleStatus[vehicle] = 0;
    }
  }

  void updateVehicleStatus(String vehicle) {
    setState(() {
      vehicleStatus[vehicle] = (vehicleStatus[vehicle]! + 1) % 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fallbeispiel wählen'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.redAccent, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text('Qualifikationen',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10.0,
              children: qualifications.map((qualification) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedQualification = qualification;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: selectedQualification == qualification
                          ? Colors.blue
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(qualification,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Rettungsmittel',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('Blau: besetzt, Rot: Auf Anfahrt',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10.0,
              children: vehicles.map((vehicle) {
                return GestureDetector(
                  onTap: () => updateVehicleStatus(vehicle),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: statusColors[vehicleStatus[vehicle]],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(vehicle,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            const Text('Sonderoptionen',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Reanimation', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Switch(
                  value: isResuscitation,
                  onChanged: (value) {
                    setState(() {
                      isResuscitation = value;
                    });
                  },
                ),
              ],
            ),
            isResuscitation
                ? Row(
                    children: [
                      const Text('Säuglings- / Kinderreanimation', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Switch(
                        value: isChildResuscitation,
                        onChanged: (value) {
                          setState(() {
                            isChildResuscitation = value;
                          });
                        },
                      ),
                    ],
                  )
                : const SizedBox(),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => isResuscitation ? ResuscitationScreen(vehicleStatus: vehicleStatus, isChildResuscitation: isChildResuscitation,) : SchemaSelectionScreen(vehicleStatus: vehicleStatus),
                  ),
                );
              },
              child: const Text('Starten', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
