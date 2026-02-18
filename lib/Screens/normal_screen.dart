import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../measure_requirements.dart';
import '../services/pdf_service.dart';
import '../utils/schema_colors.dart';
import '../utils/schema_descriptions.dart';
import '../utils/schema_icons.dart';
import 'result_screen.dart';

class SchemaSelectionScreen extends StatefulWidget {
  final Map<String, VehicleStatus> vehicleStatus;
  final Map<String, int?> vehicleArrivalMinutes;
  final Qualification userQualification;

  const SchemaSelectionScreen({
    super.key,
    required this.vehicleStatus,
    required this.vehicleArrivalMinutes,
    required this.userQualification,
  });

  @override
  _SchemaSelectionScreenState createState() => _SchemaSelectionScreenState();
}

class _SchemaSelectionScreenState extends State<SchemaSelectionScreen> {
  // Verwende die Requirements aus dem Model
  Map<String, List<String>> get schemas {
    Map<String, List<String>> result = {};
    MeasureRequirements.requirements.forEach((schema, requirements) {
      result[schema] = requirements.map((req) => req.action).toList();
    });
    return result;
  }

  List<CompletedAction> completedActions = [];
  late Timer _timer;
  late Timer _arrivalCheckTimer;
  int _elapsedSeconds = 0;
  bool _isPaused = false;
  late DateTime _scenarioStart;
  late final Map<String, DateTime?> _vehicleArrivalTimes;
  bool _allExpanded = false;

  // Track which vehicles have shown arrival notification
  Set<String> _arrivedVehicles = {};

  String get _formattedTime {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Anzahl vollständig abgehakter Schemata (nur verpflichtende + erwartete)
  int get _completedSchemaCount {
    return schemas.keys.where((schema) {
      return schemas[schema]!.every((action) {
        final req = MeasureRequirements.getRequirement(schema, action);
        if (req != null &&
            req.getRequirementLevel(widget.userQualification) ==
                RequirementLevel.notApplicable) return true;
        return completedActions
            .any((e) => e.schema == schema && e.action == action);
      });
    }).length;
  }

  /// Formatierter Zeitstempel relativ zu Szenario-Start
  String _relativeTime(DateTime ts) {
    final diff = ts.difference(_scenarioStart);
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return '+${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // Set selectedVehicles to be finished
  void finishVehicles() {
    setState(() {
      widget.vehicleStatus.forEach((key, value) {
        if (value == VehicleStatus.kommt &&
            !completedActions.any(
                (e) => e.schema == 'Nachforderung' && e.action == key)) {
          completedActions.add(CompletedAction(
            schema: 'Nachforderung',
            action: key,
            timestamp: DateTime.now(),
          ));
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();

    // Ankunftszeiten werden ab Szenario-Start berechnet (nicht ab Setup)
    _scenarioStart = DateTime.now();
    _vehicleArrivalTimes = {
      for (final entry in widget.vehicleArrivalMinutes.entries)
        entry.key: entry.value != null
            ? _scenarioStart.add(Duration(minutes: entry.value!))
            : null,
    };

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });

    // Check for vehicle arrivals every second
    _arrivalCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkVehicleArrivals();
    });

    finishVehicles();
  }

  @override
  void dispose() {
    _timer.cancel();
    _arrivalCheckTimer.cancel();
    super.dispose();
  }

  void _checkVehicleArrivals() {
    final now = DateTime.now();
    _vehicleArrivalTimes.forEach((vehicle, arrivalTime) {
      if (arrivalTime != null &&
          !_arrivedVehicles.contains(vehicle) &&
          now.isAfter(arrivalTime)) {
        _arrivedVehicles.add(vehicle);
        _showVehicleArrivalDialog(vehicle);
      }
    });
  }

  void _showVehicleArrivalDialog(String vehicle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.local_shipping, color: Colors.blue.shade700, size: 32),
            const SizedBox(width: 12),
            const Text('Rettungsmittel eingetroffen!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade700, size: 48),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        const Text(
                          'ist eingetroffen!',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  Future<void> generatePDF() async {
    final missingActions = MeasureRequirements.calculateMissingRequiredActions(
      completedActions,
      widget.userQualification,
    );
    await PdfService.generateNormalPdf(
      completedActions: completedActions,
      missingActions: missingActions,
      userQualification: widget.userQualification,
      elapsedSeconds: _elapsedSeconds,
    );
  }

  void _showMedicalSourcesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hinweis & Quellen'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Diese App stellt ausschließlich Fallbeispiele und '
                    'Trainingsschemata für Ausbildung und Fortbildung im Rettungsdienst dar. '
                    'Sie ersetzt keine medizinische Beratung, Diagnostik oder Therapieempfehlung.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Die hier dargestellten Schemata (z. B. (c)ABCDE, SAMPLER, '
                    'OPQRST, BE-FAST, WASB, STU, A–E, Maßnahmen) orientieren sich u. a. an:',
              ),
              const SizedBox(height: 8),
              _buildReferenceEntry(
                'Drache D, Conrad A, Brand A, Frenzel J, Kaiserauer E. '
                    '„retten – Rettungssanitäter". Georg Thieme Verlag; 2024. '
                    'Online: https://shop.thieme.de/retten-Rettungssanitaeter/9783132434684',
              ),
              const SizedBox(height: 4),
              _buildReferenceEntry(
                'Buschmann C (Hrsg.). „Das ABCDE-Schema der Patientensicherheit '
                    'in der Notfallmedizin – Pearls and Pitfalls aus interdisziplinärer Sicht". '
                    'Kohlhammer Verlag.',
              ),
              const SizedBox(height: 4),
              _buildReferenceEntry(
                'European Resuscitation Council (ERC). „ERC Guidelines 2025 / '
                    '2021 – Basic Life Support & Advanced Life Support". '
                    'Online: https://www.erc.edu',
              ),
              const SizedBox(height: 4),
              _buildReferenceEntry(
                'Thieme via medici – notfallmedizinische Basisdiagnostik mit '
                    '(c)ABCDE- und SAMPLER-Schema.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Die Umsetzung im Rahmen dieser App dient ausschließlich dem '
                    'strukturierten Training von Einsatzkräften.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  static Widget _buildReferenceEntry(String text) {
    return Text(
      '• $text',
      style: const TextStyle(fontSize: 13),
    );
  }

  void _showEndScenarioDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.stop_circle, color: Colors.red),
            SizedBox(width: 12),
            Text('Fallbeispiel beenden?'),
          ],
        ),
        content: const Text(
          'Alle Timer werden gestoppt und das Ergebnis angezeigt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _endScenario();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Beenden',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _endScenario() {
    _timer.cancel();
    _arrivalCheckTimer.cancel();
    final missingActions = MeasureRequirements.calculateMissingRequiredActions(
      completedActions,
      widget.userQualification,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MeasuresOverviewScreen(
          completedActions: completedActions,
          missingActions: missingActions,
          userQualification: widget.userQualification,
        ),
      ),
    );
  }

  Widget _buildVehicleArrivalCard() {
    // Filter vehicles that are coming and have arrival times
    final incomingVehicles = widget.vehicleStatus.entries
        .where((e) =>
            e.value == VehicleStatus.kommt &&
            _vehicleArrivalTimes[e.key] != null)
        .toList();

    if (incomingVehicles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.orange.shade50, Colors.red.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Ankommende Rettungsmittel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...incomingVehicles.map((entry) {
              final vehicle = entry.key;
              final arrivalTime = _vehicleArrivalTimes[vehicle]!;
              final now = DateTime.now();
              final diff = arrivalTime.difference(now);
              final hasArrived = _arrivedVehicles.contains(vehicle);

              String timeText;
              Color statusColor;
              IconData statusIcon;

              if (hasArrived) {
                timeText = 'Eingetroffen!';
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
              } else if (diff.isNegative) {
                timeText = 'Ankunft!';
                statusColor = Colors.green;
                statusIcon = Icons.notifications_active;
              } else {
                final minutes = diff.inMinutes;
                final seconds = diff.inSeconds % 60;
                timeText = '${minutes}:${seconds.toString().padLeft(2, '0')} min';
                statusColor = diff.inMinutes <= 2 ? Colors.orange : Colors.blue;
                statusIcon = Icons.access_time;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor,
                    width: hasArrived ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (!hasArrived && !diff.isNegative)
                              Text(
                                'Erwartet um ${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')} Uhr',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate missing required actions for this user
    final missingActions = MeasureRequirements.calculateMissingRequiredActions(
      completedActions,
      widget.userQualification,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Schemata – $_formattedTime (${widget.userQualification.name})'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.redAccent, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Pause/Weiter
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: _isPaused ? 'Timer fortsetzen' : 'Timer pausieren',
            onPressed: () => setState(() => _isPaused = !_isPaused),
          ),
          // Alle Expand / Collapse
          IconButton(
            icon: Icon(_allExpanded ? Icons.unfold_less : Icons.unfold_more),
            tooltip: _allExpanded ? 'Alle einklappen' : 'Alle ausklappen',
            onPressed: () => setState(() => _allExpanded = !_allExpanded),
          ),
          // Dark Mode
          IconButton(
            icon: Icon(
              themeModeNotifier.value == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Dark Mode umschalten',
            onPressed: () {
              themeModeNotifier.value =
                  themeModeNotifier.value == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Übersicht',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  return MeasuresOverviewScreen(
                    completedActions: completedActions,
                    missingActions: missingActions,
                    userQualification: widget.userQualification,
                  );
                }),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'PDF erstellen',
            onPressed: generatePDF,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Hinweise & Quellen',
            onPressed: _showMedicalSourcesDialog,
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle, color: Colors.white),
            tooltip: 'Fallbeispiel beenden',
            onPressed: _showEndScenarioDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Gesamtfortschrittsbalken
          _buildProgressBar(),
          // Pause-Banner
          if (_isPaused)
            Container(
              width: double.infinity,
              color: Colors.amber.shade700,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause_circle, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Timer pausiert',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
        children: [
          // Vehicle arrival status
          _buildVehicleArrivalCard(),

          ...schemas.keys.map((schema) {
            final schemaColor = getSchemaColor(schema);
            final schemaBg = getSchemaBackgroundColor(schema);
            bool allCompleted = schemas[schema]!.every((action) {
              final req = MeasureRequirements.getRequirement(schema, action);
              if (req != null &&
                  req.getRequirementLevel(widget.userQualification) ==
                      RequirementLevel.notApplicable) return true;
              return completedActions
                  .any((e) => e.schema == schema && e.action == action);
            });

            final schemaIcon = getSchemaIcon(schema);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: allCompleted ? 4 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: allCompleted ? Colors.green : schemaColor.withOpacity(0.4),
                  width: allCompleted ? 2 : 1.5,
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  key: ValueKey('$schema-$_allExpanded'),
                  initiallyExpanded: _allExpanded,
                  leading: Tooltip(
                    message: getSchemaDescription(schema),
                    preferBelow: true,
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 6),
                    child: Icon(
                      schemaIcon,
                      color: allCompleted ? Colors.green : schemaColor,
                    ),
                  ),
                  title: Text(
                    schema,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: allCompleted ? Colors.green : schemaColor,
                    ),
                  ),
                  trailing: allCompleted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : Icon(Icons.expand_more, color: schemaColor),
                  backgroundColor:
                      allCompleted ? Colors.green.withOpacity(0.08) : schemaBg,
                  collapsedBackgroundColor: schemaBg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  children: schemas[schema]!.map((action) {
                    bool isCompleted = completedActions
                        .any((e) => e.schema == schema && e.action == action);
                    final completedEntry = isCompleted
                        ? completedActions.lastWhere(
                            (e) => e.schema == schema && e.action == action)
                        : null;

                    // Get requirement info
                    final requirement =
                        MeasureRequirements.getRequirement(schema, action);
                    final isOptional =
                        requirement?.isOptionalFor(widget.userQualification) ??
                            false;
                    final canPerform = requirement
                            ?.canPerformWithQualification(
                                widget.userQualification) ??
                        true;
                    final requirementLevel =
                        requirement?.getRequirementLevel(widget.userQualification);

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isCompleted
                            ? Colors.green.withOpacity(0.12)
                            : (isOptional
                                ? Colors.blue.withOpacity(0.06)
                                : null),
                        border: isCompleted
                            ? Border.all(
                                color: Colors.green.withOpacity(0.4), width: 1)
                            : (isOptional && !isCompleted
                                ? Border.all(
                                    color: Colors.blue.shade300, width: 1.5)
                                : null),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isCompleted
                                  ? Colors.green
                                  : (isOptional
                                      ? Colors.blue
                                      : Colors.grey),
                            ),
                            if (isOptional && !isCompleted) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.help_outline,
                                  color: Colors.blue.shade600, size: 14),
                            ],
                            if (!canPerform) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.lock,
                                  color: Colors.orange.shade700, size: 14),
                            ],
                            if (isCompleted) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.undo,
                                  color: Colors.green.withOpacity(0.5),
                                  size: 12),
                            ],
                          ],
                        ),
                        title: Text(
                          action,
                          style: TextStyle(
                            fontSize: 13,
                            color: isCompleted
                                ? Colors.green.shade800
                                : (!canPerform
                                    ? Colors.grey.shade500
                                    : null),
                            fontWeight: isCompleted
                                ? FontWeight.w500
                                : FontWeight.normal,
                            decoration: !canPerform
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: isCompleted && completedEntry != null
                            ? Text(
                                _relativeTime(completedEntry.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : (!canPerform
                                ? Text(
                                    'Nicht verfügbar für ${widget.userQualification.name}',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 11,
                                    ),
                                  )
                                : (isOptional
                                    ? Text(
                                        requirementLevel ==
                                                RequirementLevel.expected
                                            ? 'Erwartet'
                                            : 'Optional',
                                        style: TextStyle(
                                          color: requirementLevel ==
                                                  RequirementLevel.expected
                                              ? Colors.amber.shade700
                                              : Colors.blue.shade700,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )
                                    : null)),
                        onTap: canPerform && !isCompleted
                            ? () {
                                setState(() {
                                  completedActions.add(CompletedAction(
                                    schema: schema,
                                    action: action,
                                    timestamp: DateTime.now(),
                                  ));
                                });
                              }
                            : null,
                        onLongPress: isCompleted
                            ? () {
                                setState(() {
                                  completedActions.removeWhere((e) =>
                                      e.schema == schema &&
                                      e.action == action);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('"$action" rückgängig gemacht'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          }).toList(),
              const SizedBox(height: 20), // Bottom padding
            ],
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = schemas.keys.length;
    final done = _completedSchemaCount;
    final progress = total > 0 ? done / total : 0.0;
    final color = progress >= 1.0
        ? Colors.green
        : progress >= 0.5
            ? Colors.blue
            : Colors.orange;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fortschritt: $done / $total Schemata',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)} %',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}