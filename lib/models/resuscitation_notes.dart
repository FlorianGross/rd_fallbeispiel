import 'medication.dart';

/// Beschreibende Hinweise zu Medikamenten und Schocks während einer
/// Reanimation, z. B. „Erstes Adrenalin nach 2:10 min“.
///
/// Bewusst keine Bewertung: Der Herzrhythmus wird nicht erfasst, daher lässt
/// sich nicht entscheiden, wann Adrenalin oder Amiodaron fällig gewesen wäre.
/// Die Hinweise sollen die Nachbesprechung erleichtern.
List<String> resuscitationMedicationNotes({
  required List<MedicationAdministration> medications,
  required List<DateTime> shockTimes,
  required DateTime? resuscitationStart,
}) {
  if (resuscitationStart == null) return const [];
  final notes = <String>[];

  final adrenalin = medications
      .where((m) => m.medication.wirkstoff == 'Adrenalin')
      .map((m) => m.timestamp)
      .toList()
    ..sort();
  final amiodaron = medications
      .where((m) => m.medication.wirkstoff == 'Amiodaron')
      .map((m) => m.timestamp)
      .toList()
    ..sort();
  final shocks = List<DateTime>.of(shockTimes)..sort();

  notes.add('Schocks: ${shocks.length}');

  if (adrenalin.isEmpty) {
    notes.add('Kein Adrenalin dokumentiert');
  } else {
    notes.add('Adrenalin: ${adrenalin.length}× – erste Gabe '
        '${formatOffset(adrenalin.first.difference(resuscitationStart))} '
        'nach Reanimationsbeginn');
    if (adrenalin.length > 1) {
      final intervals = [
        for (var i = 1; i < adrenalin.length; i++)
          adrenalin[i].difference(adrenalin[i - 1])
      ];
      final long = intervals.where((d) => d > const Duration(minutes: 5));
      notes.add('Abstände Adrenalin: '
          '${intervals.map(formatOffset).join(', ')} min'
          '${long.isNotEmpty ? ' (${long.length}× länger als 5 min)' : ''}');
    }
  }

  if (amiodaron.isNotEmpty) {
    final afterShocks =
        shocks.where((s) => s.isBefore(amiodaron.first)).length;
    notes.add('Amiodaron: ${amiodaron.length}× – erste Gabe nach '
        '$afterShocks ${afterShocks == 1 ? 'Schock' : 'Schocks'}');
  } else if (shocks.length >= 3) {
    notes.add('Kein Amiodaron dokumentiert trotz ${shocks.length} Schocks');
  }

  return notes;
}

/// „m:ss“, z. B. 2:05
String formatOffset(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}
