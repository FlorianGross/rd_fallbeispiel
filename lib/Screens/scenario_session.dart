import 'package:flutter/material.dart';

import '../measure_requirements.dart';
import '../models/medication.dart';
import '../utils/wakelock.dart';
import '../widgets/medication_widgets.dart';
import '../widgets/scenario_common.dart';

/// Gemeinsamer Ablauf eines laufenden Fallbeispiels (Normal und Reanimation):
/// Szenario-Uhr mit Pause, Fahrzeug-Ankünfte und Bildschirm-Wakelock.
mixin ScenarioSessionMixin<T extends StatefulWidget> on State<T> {
  /// Läuft nur, solange nicht pausiert ist. Anzeige, Zeitstempel und
  /// Fahrzeug-Ankünfte beziehen sich auf diese Uhr, damit sie nach einer
  /// Pause konsistent bleiben.
  final Stopwatch clock = Stopwatch();
  late final DateTime scenarioStart;
  late final Map<String, DateTime?> vehicleArrivalTimes;

  /// Fahrzeuge, deren Ankunft bereits gemeldet wurde
  final Set<String> arrivedVehicles = {};
  bool isPaused = false;

  /// Szenario beendet oder verworfen (verhindert doppeltes Beenden)
  bool ended = false;

  // Gleichzeitig eintreffende Fahrzeuge werden gesammelt, statt mehrere
  // nicht wegklickbare Dialoge übereinander zu öffnen.
  final List<String> _arrivalQueue = [];
  bool _arrivalDialogOpen = false;

  int get elapsedSeconds => clock.elapsed.inSeconds;

  /// Aktuelle Szenariozeit (ohne Pausen)
  DateTime get scenarioNow => scenarioStart.add(clock.elapsed);

  String get formattedTime {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Zeitstempel relativ zum Szenario-Start, z. B. „+01:23“
  String relativeTime(DateTime ts) {
    final diff = ts.difference(scenarioStart);
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return '+${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Startet Uhr und Wakelock; Ankunftszeiten zählen ab jetzt (nicht ab Setup).
  void startScenarioSession(Map<String, int?> vehicleArrivalMinutes) {
    scenarioStart = DateTime.now();
    clock.start();
    setScreenAwake(true);
    vehicleArrivalTimes = {
      for (final entry in vehicleArrivalMinutes.entries)
        entry.key: entry.value != null
            ? scenarioStart.add(Duration(minutes: entry.value!))
            : null,
    };
  }

  void togglePause() {
    setState(() {
      isPaused = !isPaused;
      isPaused ? clock.stop() : clock.start();
    });
  }

  /// Beim Setup angeforderte Rettungsmittel als Nachforderung protokollieren
  void logRequestedVehicles(
    Map<String, VehicleStatus> vehicleStatus,
    List<CompletedAction> completedActions,
  ) {
    setState(() {
      vehicleStatus.forEach((vehicle, status) {
        if (status == VehicleStatus.kommt &&
            !completedActions.any(
                (e) => e.schema == 'Nachforderung' && e.action == vehicle)) {
          completedActions.add(CompletedAction(
            schema: 'Nachforderung',
            action: vehicle,
            timestamp: scenarioNow,
          ));
        }
      });
    });
  }

  /// Dokumentierte Medikamentengaben
  final List<MedicationAdministration> medications = [];

  /// Medikamente dokumentieren darf, wer „Medikamentengabe“ durchführen kann
  /// (RS, NFS). Für SAN/RH wäre die automatisch abgehakte Maßnahme sonst als
  /// „nicht zulässig“ in der Auswertung.
  bool canDocumentMedication(Qualification qualification) =>
      MeasureRequirements.getRequirement(
              'Maßnahmen (erweitert)', 'Medikamentengabe')
          ?.canPerformWithQualification(qualification) ??
      false;

  /// Öffnet den Medikamenten-Dialog und protokolliert die Gabe. Die erste
  /// Gabe hakt „Medikamentengabe“ automatisch ab.
  Future<MedicationAdministration?> addMedication(
    List<CompletedAction> completedActions, {
    Medication? preset,
    String? presetRoute,
  }) async {
    final administration = await showMedicationDialog(
      context,
      now: () => scenarioNow,
      preset: preset,
      presetRoute: presetRoute,
    );
    if (administration == null || !mounted) return null;
    setState(() {
      medications.add(administration);
      if (!completedActions.any((e) =>
          e.schema == 'Maßnahmen (erweitert)' &&
          e.action == 'Medikamentengabe')) {
        completedActions.add(CompletedAction(
          schema: 'Maßnahmen (erweitert)',
          action: 'Medikamentengabe',
          timestamp: administration.timestamp,
        ));
      }
    });
    return administration;
  }

  void removeMedication(MedicationAdministration administration) {
    setState(() => medications.remove(administration));
  }

  /// Regelmäßig aufrufen: meldet Fahrzeuge, deren Ankunftszeit erreicht ist.
  void checkVehicleArrivals() {
    if (isPaused) return;
    final now = scenarioNow;
    vehicleArrivalTimes.forEach((vehicle, arrivalTime) {
      if (arrivalTime != null &&
          !arrivedVehicles.contains(vehicle) &&
          now.isAfter(arrivalTime)) {
        arrivedVehicles.add(vehicle);
        _arrivalQueue.add(vehicle);
      }
    });
    _showNextArrival();
  }

  Future<void> _showNextArrival() async {
    if (_arrivalDialogOpen || _arrivalQueue.isEmpty || !mounted) return;
    final vehicles = List<String>.of(_arrivalQueue);
    _arrivalQueue.clear();
    _arrivalDialogOpen = true;
    await showVehicleArrivalDialog(context, vehicles);
    _arrivalDialogOpen = false;
    _showNextArrival();
  }

  @override
  void dispose() {
    setScreenAwake(false);
    super.dispose();
  }
}
