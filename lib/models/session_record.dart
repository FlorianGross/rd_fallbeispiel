import '../measure_requirements.dart';
import 'cpr_summary.dart';
import 'medication.dart';

class SessionRecord {
  final String id;
  final DateTime startTime;
  final int durationSeconds;
  final String qualification;
  final bool isResuscitation;
  final bool isChildResuscitation;
  final int completedCount;
  final int missingCount;

  /// Durchgeführte verpflichtende Maßnahmen (Basis der Vollständigkeitsquote).
  /// Bei älteren Einträgen nicht gespeichert → Fallback auf [completedCount].
  final int? requiredCompletedCount;
  final String? scenarioName;
  final String? notes;

  /// Vollständige Maßnahmenlisten der Sitzung, damit sie im Verlauf wieder
  /// geöffnet und ausgewertet werden kann. Bei älteren Einträgen null.
  final List<CompletedAction>? completedActions;
  final List<MissingAction>? missingActions;

  /// Bewertete Schemata (null = alle)
  final List<String>? scoredSchemas;

  /// Kennzahlen der Reanimation (nur bei Reanimations-Sitzungen)
  final CprSummary? cpr;

  /// Dokumentierte Medikamentengaben. Bei älteren Einträgen null.
  final List<MedicationAdministration>? medications;

  const SessionRecord({
    required this.id,
    required this.startTime,
    required this.durationSeconds,
    required this.qualification,
    required this.isResuscitation,
    this.isChildResuscitation = false,
    required this.completedCount,
    required this.missingCount,
    this.requiredCompletedCount,
    this.scenarioName,
    this.notes,
    this.completedActions,
    this.missingActions,
    this.scoredSchemas,
    this.cpr,
    this.medications,
  });

  /// Sind die Maßnahmenlisten gespeichert (Einträge ab dieser Version)?
  bool get hasDetails => completedActions != null && missingActions != null;

  double get completionRate {
    final done = requiredCompletedCount ?? completedCount;
    final total = done + missingCount;
    return total > 0 ? done / total * 100 : 0;
  }

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  SessionRecord copyWith({String? notes, String? scenarioName}) {
    return SessionRecord(
      id: id,
      startTime: startTime,
      durationSeconds: durationSeconds,
      qualification: qualification,
      isResuscitation: isResuscitation,
      isChildResuscitation: isChildResuscitation,
      completedCount: completedCount,
      missingCount: missingCount,
      requiredCompletedCount: requiredCompletedCount,
      scenarioName: scenarioName ?? this.scenarioName,
      notes: notes ?? this.notes,
      completedActions: completedActions,
      missingActions: missingActions,
      scoredSchemas: scoredSchemas,
      cpr: cpr,
      medications: medications,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'durationSeconds': durationSeconds,
        'qualification': qualification,
        'isResuscitation': isResuscitation,
        'isChildResuscitation': isChildResuscitation,
        'completedCount': completedCount,
        'missingCount': missingCount,
        'requiredCompletedCount': requiredCompletedCount,
        'scenarioName': scenarioName,
        'notes': notes,
        if (completedActions != null)
          'completedActions': completedActions!
              .map((a) => {
                    'schema': a.schema,
                    'action': a.action,
                    'timestamp': a.timestamp.toIso8601String(),
                  })
              .toList(),
        if (missingActions != null)
          'missingActions': missingActions!
              .map((m) => {
                    'schema': m.schema,
                    'action': m.action,
                    'level': m.requirementLevel.name,
                    'note': m.note,
                  })
              .toList(),
        if (scoredSchemas != null) 'scoredSchemas': scoredSchemas,
        if (cpr != null) 'cpr': cpr!.toJson(),
        if (medications != null)
          'medications': medications!.map((m) => m.toJson()).toList(),
      };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        durationSeconds: json['durationSeconds'] as int,
        qualification: json['qualification'] as String,
        isResuscitation: json['isResuscitation'] as bool,
        isChildResuscitation: json['isChildResuscitation'] as bool? ?? false,
        completedCount: json['completedCount'] as int,
        missingCount: json['missingCount'] as int,
        requiredCompletedCount: json['requiredCompletedCount'] as int?,
        scenarioName: json['scenarioName'] as String?,
        notes: json['notes'] as String?,
        completedActions: (json['completedActions'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .map((e) => CompletedAction(
                  schema: e['schema'] as String,
                  action: e['action'] as String,
                  timestamp: DateTime.parse(e['timestamp'] as String),
                ))
            .toList(),
        missingActions: (json['missingActions'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .map((e) => MissingAction(
                  schema: e['schema'] as String,
                  action: e['action'] as String,
                  requirementLevel: RequirementLevel.values.firstWhere(
                    (l) => l.name == e['level'],
                    orElse: () => RequirementLevel.required,
                  ),
                  note: e['note'] as String?,
                ))
            .toList(),
        scoredSchemas: (json['scoredSchemas'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        cpr: json['cpr'] == null
            ? null
            : CprSummary.fromJson(json['cpr'] as Map<String, dynamic>),
        medications: (json['medications'] as List<dynamic>?)
            ?.map((e) =>
                MedicationAdministration.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
