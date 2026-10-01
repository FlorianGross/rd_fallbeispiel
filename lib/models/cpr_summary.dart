import '../measure_requirements.dart';

/// Kennzahlen einer Reanimation – klein genug, um sie im Verlauf zu speichern
/// (der vollständige Frequenzverlauf wird nicht gespeichert).
class CprSummary {
  final int compressions;
  final int ventilations;

  /// Mittelwert aller gemessenen Frequenzen (0 = keine Messung)
  final double averageBpm;

  /// Anteil der Messungen im Zielbereich 100–120/min (0–1, null = keine Messung)
  final double? targetShare;

  const CprSummary({
    required this.compressions,
    required this.ventilations,
    required this.averageBpm,
    this.targetShare,
  });

  /// Berechnet die Kennzahlen aus dem Frequenzverlauf der Reanimation
  /// (Einträge mit `'bpm'`, wie sie der Reanimations-Screen aufzeichnet).
  factory CprSummary.fromHistory({
    required int compressions,
    required int ventilations,
    required List<Map<String, dynamic>> bpmHistory,
  }) {
    final values =
        bpmHistory.map((e) => (e['bpm'] as num).toDouble()).toList();
    if (values.isEmpty) {
      return CprSummary(
        compressions: compressions,
        ventilations: ventilations,
        averageBpm: 0,
      );
    }
    final inTarget = values
        .where((v) =>
            v >= BpmThresholds.optimalMin && v <= BpmThresholds.optimalMax)
        .length;
    return CprSummary(
      compressions: compressions,
      ventilations: ventilations,
      averageBpm: values.reduce((a, b) => a + b) / values.length,
      targetShare: inTarget / values.length,
    );
  }

  Map<String, dynamic> toJson() => {
        'compressions': compressions,
        'ventilations': ventilations,
        'averageBpm': averageBpm,
        'targetShare': targetShare,
      };

  factory CprSummary.fromJson(Map<String, dynamic> json) => CprSummary(
        compressions: json['compressions'] as int,
        ventilations: json['ventilations'] as int,
        averageBpm: (json['averageBpm'] as num).toDouble(),
        targetShare: (json['targetShare'] as num?)?.toDouble(),
      );
}
