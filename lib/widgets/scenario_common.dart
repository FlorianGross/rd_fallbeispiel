import 'package:flutter/material.dart';

import '../measure_requirements.dart';
import '../utils/adaptive_colors.dart';
import '../utils/schema_colors.dart';
import '../utils/schema_descriptions.dart';
import '../utils/schema_icons.dart';

/// Bausteine, die Normal- und Reanimations-Screen gemeinsam nutzen.

/// Ein Schema als aufklappbare Karte mit seinen Maßnahmen.
class SchemaCard extends StatelessWidget {
  final String schema;
  final List<String> actions;
  final List<CompletedAction> completedActions;
  final Qualification qualification;

  /// Alle Karten auf-/zuklappen (ändert sich → Karte wird neu aufgebaut)
  final bool expanded;

  /// Hinweis für Schemata, die im aktuellen Modus nicht bewertet werden
  /// (null = wird bewertet)
  final String? unscoredHint;

  /// Formatiert den Zeitstempel einer erledigten Maßnahme (z. B. „+01:23“)
  final String Function(DateTime timestamp) formatTimestamp;

  final void Function(String action) onComplete;
  final void Function(String action) onUndo;

  const SchemaCard({
    super.key,
    required this.schema,
    required this.actions,
    required this.completedActions,
    required this.qualification,
    required this.expanded,
    required this.formatTimestamp,
    required this.onComplete,
    required this.onUndo,
    this.unscoredHint,
  });

  @override
  Widget build(BuildContext context) {
    final schemaColor = getSchemaColor(schema);
    final schemaBg = getSchemaBackgroundColor(schema);
    final allCompleted = MeasureRequirements.isSchemaComplete(
        schema, completedActions, qualification);

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
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('$schema-$expanded'),
          initiallyExpanded: expanded,
          leading: Tooltip(
            message: getSchemaDescription(schema),
            preferBelow: true,
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 6),
            child: Icon(
              getSchemaIcon(schema),
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
          subtitle: unscoredHint == null
              ? null
              : Text(
                  unscoredHint!,
                  style: TextStyle(fontSize: 11, color: context.mutedText),
                ),
          trailing: allCompleted
              ? const Icon(Icons.check_circle, color: Colors.green)
              : Icon(Icons.expand_more, color: schemaColor),
          backgroundColor:
              allCompleted ? Colors.green.withOpacity(0.08) : schemaBg,
          collapsedBackgroundColor: schemaBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          children: actions.map((a) => _buildAction(context, a)).toList(),
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context, String action) {
    final matches =
        completedActions.where((e) => e.schema == schema && e.action == action);
    final completedEntry = matches.isEmpty ? null : matches.last;
    final isCompleted = completedEntry != null;

    final requirement = MeasureRequirements.getRequirement(schema, action);
    final isOptional = requirement?.isOptionalFor(qualification) ?? false;
    final canPerform =
        requirement?.canPerformWithQualification(qualification) ?? true;
    final requirementLevel = requirement?.getRequirementLevel(qualification);

    final Color? background = isCompleted
        ? Colors.green.withOpacity(0.12)
        : (isOptional ? Colors.blue.withOpacity(0.06) : null);
    final BorderSide border = isCompleted
        ? BorderSide(color: Colors.green.withOpacity(0.4), width: 1)
        : (isOptional
            ? BorderSide(color: Colors.blue.shade300, width: 1.5)
            : BorderSide.none);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      // Eigenes Material statt farbigem Container: sonst liegt die Farbe
      // über der Tipp-Animation der ListTile (Flutter meldet dafür einen
      // Fehler und zeigt in Debug-Builds ggf. eine Fehlerbox).
      child: Material(
        color: background ?? Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: border,
        ),
        clipBehavior: Clip.antiAlias,
        // Rahmenbreite als Innenabstand – wie zuvor beim Container-Rahmen
        child: Padding(
          padding: EdgeInsets.all(border.width),
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
                    : (isOptional ? Colors.blue : Colors.grey),
              ),
              if (isOptional && !isCompleted) ...[
                const SizedBox(width: 4),
                Icon(Icons.help_outline, color: Colors.blue.shade600, size: 14),
              ],
              if (!canPerform) ...[
                const SizedBox(width: 4),
                Icon(Icons.lock, color: Colors.orange.shade700, size: 14),
              ],
              if (isCompleted) ...[
                const SizedBox(width: 4),
                Icon(Icons.undo,
                    color: Colors.green.withOpacity(0.5), size: 12),
              ],
            ],
          ),
          title: Text(
            action,
            style: TextStyle(
              fontSize: 13,
              color: isCompleted
                  ? context.strongFg(Colors.green)
                  : (!canPerform ? Colors.grey.shade500 : null),
              fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
              decoration: !canPerform ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: isCompleted
              ? Text(
                  formatTimestamp(completedEntry.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : (!canPerform
                  ? Text(
                      'Nicht verfügbar für ${qualification.name}',
                      style: TextStyle(
                          color: Colors.orange.shade700, fontSize: 11),
                    )
                  : (isOptional
                      ? Text(
                          requirementLevel == RequirementLevel.expected
                              ? 'Erwartet'
                              : 'Optional',
                          style: TextStyle(
                            color: requirementLevel == RequirementLevel.expected
                                ? Colors.amber.shade700
                                : Colors.blue.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null)),
          onTap: canPerform && !isCompleted ? () => onComplete(action) : null,
          onLongPress: isCompleted
              ? () {
                  onUndo(action);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"$action" rückgängig gemacht'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              : null,
          ),
        ),
      ),
    );
  }
}

/// Countdown der angeforderten Rettungsmittel
class VehicleArrivalCard extends StatelessWidget {
  final Map<String, VehicleStatus> vehicleStatus;
  final Map<String, DateTime?> arrivalTimes;
  final Set<String> arrivedVehicles;

  /// Aktuelle Szenariozeit (ohne Pausen)
  final DateTime now;

  const VehicleArrivalCard({
    super.key,
    required this.vehicleStatus,
    required this.arrivalTimes,
    required this.arrivedVehicles,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final incomingVehicles = vehicleStatus.entries
        .where((e) =>
            e.value == VehicleStatus.kommt && arrivalTimes[e.key] != null)
        .toList();

    if (incomingVehicles.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [context.softBg(Colors.orange), context.softBg(Colors.red)],
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...incomingVehicles.map((entry) {
              final vehicle = entry.key;
              final arrivalTime = arrivalTimes[vehicle]!;
              final diff = arrivalTime.difference(now);
              final hasArrived = arrivedVehicles.contains(vehicle);

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
                timeText = '$minutes:${seconds.toString().padLeft(2, '0')} min';
                statusColor = diff.inMinutes <= 2 ? Colors.orange : Colors.blue;
                statusIcon = Icons.access_time;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.surface,
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
                                  color: context.mutedText,
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
            }),
          ],
        ),
      ),
    );
  }
}

/// Meldet eingetroffene Rettungsmittel (mehrere gleichzeitig in einem Dialog)
Future<void> showVehicleArrivalDialog(
    BuildContext context, List<String> vehicles) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.local_shipping, color: Colors.blue.shade700, size: 32),
          const SizedBox(width: 12),
          // Umbrechen statt Überlauf bei großer Systemschrift
          const Flexible(child: Text('Rettungsmittel eingetroffen!')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.softBg(Colors.green),
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
                        vehicles.join(', '),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: context.strongFg(Colors.green),
                        ),
                      ),
                      Text(
                        vehicles.length > 1
                            ? 'sind eingetroffen!'
                            : 'ist eingetroffen!',
                        style: const TextStyle(fontSize: 16),
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

/// Rückfrage vor dem Beenden. [fromBack]: über Zurück-Taste/-Geste
/// aufgerufen → zusätzlich „Verwerfen“.
void showEndScenarioDialog(
  BuildContext context, {
  bool fromBack = false,
  required VoidCallback onEnd,
  required VoidCallback onDiscard,
}) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.stop_circle, color: Colors.red),
          SizedBox(width: 12),
          Flexible(child: Text('Fallbeispiel beenden?')),
        ],
      ),
      content: Text(
        fromBack
            ? 'Das Fallbeispiel läuft noch. Beenden und auswerten (wird im '
                'Verlauf gespeichert) oder verwerfen?'
            : 'Alle Timer werden gestoppt und das Ergebnis angezeigt.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Abbrechen'),
        ),
        if (fromBack)
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onDiscard();
            },
            child: const Text('Verwerfen'),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onEnd();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Beenden', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

/// Haftungshinweis und Quellen. [schemaSummary] nennt die im jeweiligen
/// Modus gezeigten Schemata, [lastReference] die modusspezifische Quelle.
void showMedicalSourcesDialog(
  BuildContext context, {
  required String schemaSummary,
  required String lastReference,
}) {
  Widget reference(String text) =>
      Text('• $text', style: const TextStyle(fontSize: 13));

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
            Text(
              'Die hier dargestellten Schemata (z. B. $schemaSummary) '
              'orientieren sich u. a. an:',
            ),
            const SizedBox(height: 8),
            reference(
              'Drache D, Conrad A, Brand A, Frenzel J, Kaiserauer E. '
              '„retten – Rettungssanitäter". Georg Thieme Verlag; 2024. '
              'Online: https://shop.thieme.de/retten-Rettungssanitaeter/9783132434684',
            ),
            const SizedBox(height: 4),
            reference(
              'Buschmann C (Hrsg.). „Das ABCDE-Schema der Patientensicherheit '
              'in der Notfallmedizin – Pearls and Pitfalls aus interdisziplinärer Sicht". '
              'Kohlhammer Verlag.',
            ),
            const SizedBox(height: 4),
            reference(
              'European Resuscitation Council (ERC). „ERC Guidelines 2025 / '
              '2021 – Basic Life Support & Advanced Life Support". '
              'Online: https://www.erc.edu',
            ),
            const SizedBox(height: 4),
            reference(lastReference),
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
