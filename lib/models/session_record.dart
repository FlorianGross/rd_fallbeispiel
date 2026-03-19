class SessionRecord {
  final String id;
  final DateTime startTime;
  final int durationSeconds;
  final String qualification;
  final bool isResuscitation;
  final bool isChildResuscitation;
  final int completedCount;
  final int missingCount;
  final String? scenarioName;
  final String? notes;

  const SessionRecord({
    required this.id,
    required this.startTime,
    required this.durationSeconds,
    required this.qualification,
    required this.isResuscitation,
    this.isChildResuscitation = false,
    required this.completedCount,
    required this.missingCount,
    this.scenarioName,
    this.notes,
  });

  double get completionRate {
    final total = completedCount + missingCount;
    return total > 0 ? completedCount / total * 100 : 0;
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
      scenarioName: scenarioName ?? this.scenarioName,
      notes: notes ?? this.notes,
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
        'scenarioName': scenarioName,
        'notes': notes,
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
        scenarioName: json['scenarioName'] as String?,
        notes: json['notes'] as String?,
      );
}
