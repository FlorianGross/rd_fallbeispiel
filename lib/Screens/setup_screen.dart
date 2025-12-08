import 'package:flutter/material.dart';
import 'package:rd_fallbeispiel/Screens/resuscitation_screen.dart';

import 'normal_screen.dart';

class VehicleArrival {
  final String vehicleName;
  final DateTime arrivalTime;

  VehicleArrival({required this.vehicleName, required this.arrivalTime});
}

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
  Map<String, DateTime?> vehicleArrivalTimes = {};
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
      vehicleArrivalTimes[vehicle] = null;
    }
  }

  Future<void> _showArrivalTimeDialog(String vehicle) async {
    int selectedMinutes = 5;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Ankunftszeit für $vehicle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ankunft in (Minuten):'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: selectedMinutes > 1
                        ? () {
                      setDialogState(() {
                        selectedMinutes--;
                      });
                    }
                        : null,
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$selectedMinutes',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: selectedMinutes < 60
                        ? () {
                      setDialogState(() {
                        selectedMinutes++;
                      });
                    }
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Slider(
                value: selectedMinutes.toDouble(),
                min: 1,
                max: 60,
                divisions: 59,
                label: '$selectedMinutes min',
                onChanged: (value) {
                  setDialogState(() {
                    selectedMinutes = value.round();
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  vehicleStatus[vehicle] = 0;
                  vehicleArrivalTimes[vehicle] = null;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  vehicleArrivalTimes[vehicle] =
                      DateTime.now().add(Duration(minutes: selectedMinutes));
                });
                Navigator.of(context).pop();
              },
              child: const Text('Bestätigen'),
            ),
          ],
        ),
      ),
    );
  }

  void updateVehicleStatus(String vehicle) async {
    setState(() {
      vehicleStatus[vehicle] = (vehicleStatus[vehicle]! + 1) % 3;

      // Clear arrival time when status changes
      if (vehicleStatus[vehicle] != 2) {
        vehicleArrivalTimes[vehicle] = null;
      }
    });

    // Show dialog when setting to "kommt" (status 2)
    if (vehicleStatus[vehicle] == 2) {
      await _showArrivalTimeDialog(vehicle);
    }
  }

  String _getVehicleDisplayText(String vehicle) {
    if (vehicleStatus[vehicle] == 2 && vehicleArrivalTimes[vehicle] != null) {
      final now = DateTime.now();
      final arrival = vehicleArrivalTimes[vehicle]!;
      final diff = arrival.difference(now);

      if (diff.isNegative) {
        return '$vehicle\nAngekommen!';
      } else {
        final minutes = diff.inMinutes;
        final seconds = diff.inSeconds % 60;
        return '$vehicle\n${minutes}:${seconds.toString().padLeft(2, '0')} min';
      }
    }
    return vehicle;
  }

  IconData _getVehicleIcon(String vehicle) {
    switch (vehicle) {
      case 'RTW':
        return Icons.local_hospital;
      case 'NEF':
        return Icons.emergency;
      case 'RTH':
        return Icons.airplanemode_active;
      case 'KTW':
        return Icons.airport_shuttle;
      default:
        return Icons.help_outline;
    }
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
            // Qualifications Section
            _buildSectionCard(
              icon: Icons.school,
              title: 'Qualifikationen',
              child: Wrap(
                spacing: 10.0,
                runSpacing: 10.0,
                children: qualifications.map((qualification) {
                  final isSelected = selectedQualification == qualification;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedQualification = qualification;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                          colors: [
                            Colors.blue.shade400,
                            Colors.blue.shade600
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : null,
                        color: isSelected ? null : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                            : null,
                      ),
                      child: Text(
                        qualification,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
                          fontSize: 18,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Vehicles Section
            _buildSectionCard(
              icon: Icons.local_shipping,
              title: 'Rettungsmittel',
              subtitle: 'Grau: Frei • Blau: Besetzt • Rot: Auf Anfahrt',
              child: Column(
                children: [
                  Wrap(
                    spacing: 10.0,
                    runSpacing: 10.0,
                    children: vehicles.map((vehicle) {
                      final status = vehicleStatus[vehicle]!;
                      final hasArrivalTime =
                          vehicleArrivalTimes[vehicle] != null;

                      return GestureDetector(
                        onTap: () => updateVehicleStatus(vehicle),
                        onLongPress: status == 2
                            ? () => _showArrivalTimeDialog(vehicle)
                            : null,
                        child: Container(
                          width: 100,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            color: statusColors[status],
                            borderRadius: BorderRadius.circular(12),
                            border: status == 2
                                ? Border.all(color: Colors.orange, width: 3)
                                : null,
                            boxShadow: status != 0
                                ? [
                              BoxShadow(
                                color: (statusColors[status] ??
                                    Colors.grey)
                                    .withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ]
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getVehicleIcon(vehicle),
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getVehicleDisplayText(vehicle),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (status == 2 && hasArrivalTime)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Icon(
                                    Icons.access_time,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (vehicleStatus.entries.any((e) => e.value == 2))
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tipp: Langes Drücken zum Ändern der Ankunftszeit',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Special Options Section
            _buildSectionCard(
              icon: Icons.settings,
              title: 'Sonderoptionen',
              child: Column(
                children: [
                  _buildOptionTile(
                    icon: Icons.favorite,
                    title: 'Reanimation',
                    value: isResuscitation,
                    onChanged: (value) {
                      setState(() {
                        isResuscitation = value;
                      });
                    },
                  ),
                  if (isResuscitation) ...[
                    const SizedBox(height: 8),
                    _buildOptionTile(
                      icon: Icons.child_care,
                      title: 'Säuglings- / Kinderreanimation',
                      value: isChildResuscitation,
                      onChanged: (value) {
                        setState(() {
                          isChildResuscitation = value;
                        });
                      },
                      indent: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Start Button
            Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.green, Colors.greenAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Map<String, DateTime?> arrivalsToPass =
                  Map.from(vehicleArrivalTimes);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => isResuscitation
                          ? ResuscitationScreen(
                        vehicleStatus: vehicleStatus,
                        isChildResuscitation: isChildResuscitation,
                        vehicleArrivalTimes: arrivalsToPass,
                      )
                          : SchemaSelectionScreen(
                        vehicleStatus: vehicleStatus,
                        vehicleArrivalTimes: arrivalsToPass,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, size: 28, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Starten',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool indent = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? Colors.green.shade200 : Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          if (indent) const SizedBox(width: 24),
          Icon(
            icon,
            color: value ? Colors.green.shade700 : Colors.grey.shade600,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                color: value ? Colors.green.shade900 : Colors.black87,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }
}