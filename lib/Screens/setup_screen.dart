import 'package:flutter/material.dart';
import 'package:rd_fallbeispiel/Screens/resuscitation_screen.dart';

import '../measure_requirements.dart';
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
  final List<String> qualifications = ['SAN', 'RH', 'RS', 'NFS'];
  String selectedQualification = '';
  final List<String> vehicles = ['None', 'KTW', 'RTW', 'NEF', 'RTH'];
  Map<String, VehicleStatus> vehicleStatus = {};
  Map<String, int?> vehicleArrivalMinutes = {};
  late bool isResuscitation = false;
  late bool isChildResuscitation = false;

  final Map<VehicleStatus, Color> statusColors = {
    VehicleStatus.none: Colors.grey,
    VehicleStatus.besetzt: Colors.blue,
    VehicleStatus.kommt: Colors.red,
  };

  final Map<VehicleStatus, String> statusLabels = {
    VehicleStatus.none: '',
    VehicleStatus.besetzt: 'besetzt',
    VehicleStatus.kommt: 'kommt',
  };

  @override
  void initState() {
    super.initState();
    for (var vehicle in vehicles) {
      vehicleStatus[vehicle] = VehicleStatus.none;
      vehicleArrivalMinutes[vehicle] = null;
    }
  }

  Qualification _getQualificationEnum() {
    switch (selectedQualification) {
      case 'SAN':
        return Qualification.SAN;
      case 'RH':
        return Qualification.RH;
      case 'RS':
        return Qualification.RS;
      case 'NFS':
        return Qualification.NFS;
      default:
        return Qualification.SAN;
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
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
                  vehicleStatus[vehicle] = VehicleStatus.none;
                  vehicleArrivalMinutes[vehicle] = null;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  vehicleArrivalMinutes[vehicle] = selectedMinutes;
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
      final current = vehicleStatus[vehicle]!;
      vehicleStatus[vehicle] =
          VehicleStatus.values[(current.index + 1) % VehicleStatus.values.length];

      // Clear arrival time when status changes
      if (vehicleStatus[vehicle] != VehicleStatus.kommt) {
        vehicleArrivalMinutes[vehicle] = null;
      }
    });

    // Show dialog when setting to "kommt"
    if (vehicleStatus[vehicle] == VehicleStatus.kommt) {
      await _showArrivalTimeDialog(vehicle);
    }
  }

  String _getVehicleDisplayText(String vehicle) {
    if (vehicleStatus[vehicle] == VehicleStatus.kommt &&
        vehicleArrivalMinutes[vehicle] != null) {
      return '$vehicle\nin ${vehicleArrivalMinutes[vehicle]} min';
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
              subtitle: 'Wähle deine aktuelle Qualifikationsstufe',
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
                              )
                            : null,
                        color: isSelected ? null : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected
                              ? Colors.blue.shade800
                              : Colors.grey.shade400,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        qualification,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
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
              subtitle:
                  'Tippe um Status zu ändern, lange drücken um Ankunftszeit anzupassen',
              child: Column(
                children: [
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: vehicles
                        .where((vehicle) => vehicle != 'None')
                        .map((vehicle) {
                      final status = vehicleStatus[vehicle]!;
                      final isActive = status != VehicleStatus.none;
                      return GestureDetector(
                        onTap: () => updateVehicleStatus(vehicle),
                        onLongPress: status == VehicleStatus.kommt
                            ? () => _showArrivalTimeDialog(vehicle)
                            : null,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? LinearGradient(
                                    colors: status == VehicleStatus.besetzt
                                        ? [
                                            Colors.blue.shade300,
                                            Colors.blue.shade500
                                          ]
                                        : [
                                            Colors.red.shade300,
                                            Colors.red.shade500
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: !isActive ? Colors.grey.shade300 : null,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isActive
                                  ? (status == VehicleStatus.besetzt
                                      ? Colors.blue.shade700
                                      : Colors.red.shade700)
                                  : Colors.grey.shade500,
                              width: 2,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: (status == VehicleStatus.besetzt
                                              ? Colors.blue
                                              : Colors.red)
                                          .withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _getVehicleIcon(vehicle),
                                size: 32,
                                color: isActive
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getVehicleDisplayText(vehicle),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isActive ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (isActive)
                                Text(
                                  statusLabels[status]!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Container(
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
                gradient: LinearGradient(
                  colors: selectedQualification.isEmpty
                      ? [Colors.grey, Colors.grey.shade400]
                      : [Colors.green, Colors.greenAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: selectedQualification.isEmpty
                        ? Colors.grey.withOpacity(0.3)
                        : Colors.green.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: selectedQualification.isEmpty
                    ? null
                    : () {
                        final Map<String, int?> arrivalsToPass =
                            Map.from(vehicleArrivalMinutes);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => isResuscitation
                                ? ResuscitationScreen(
                                    vehicleStatus: vehicleStatus,
                                    isChildResuscitation: isChildResuscitation,
                                    vehicleArrivalMinutes: arrivalsToPass,
                                    userQualification: _getQualificationEnum(),
                                  )
                                : SchemaSelectionScreen(
                                    vehicleStatus: vehicleStatus,
                                    vehicleArrivalMinutes: arrivalsToPass,
                                    userQualification: _getQualificationEnum(),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow,
                        size: 28,
                        color: selectedQualification.isEmpty
                            ? Colors.grey.shade600
                            : Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      selectedQualification.isEmpty
                          ? 'Qualifikation wählen'
                          : 'Starten',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: selectedQualification.isEmpty
                            ? Colors.grey.shade600
                            : Colors.white,
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
