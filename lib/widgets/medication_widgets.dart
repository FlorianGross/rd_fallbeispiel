import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../utils/adaptive_colors.dart';

/// Karte mit den bisher gegebenen Medikamenten und einer Taste zum
/// Dokumentieren einer weiteren Gabe.
class MedicationCard extends StatelessWidget {
  final List<MedicationAdministration> administrations;

  /// Formatiert einen Zeitstempel relativ zum Szenario-Start („+01:23“)
  final String Function(DateTime) formatTimestamp;
  final VoidCallback onAdd;
  final void Function(MedicationAdministration) onRemove;

  const MedicationCard({
    super.key,
    required this.administrations,
    required this.formatTimestamp,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.indigo.withAlpha(90), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.vaccines, color: context.strongFg(Colors.indigo)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    administrations.isEmpty
                        ? 'Medikamente'
                        : 'Medikamente (${administrations.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Gabe'),
                ),
              ],
            ),
            for (final a in administrations)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 32),
                title: Text('${a.medication.wirkstoff} ${a.dose}'),
                subtitle: Text(
                    '${a.route} · ${formatTimestamp(a.timestamp)} · ${a.medication.staerke}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Eintrag entfernen',
                  onPressed: () => onRemove(a),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dokumentiert eine Medikamentengabe: erst Auswahl aus dem Katalog (außer
/// [preset] ist gesetzt), dann Dosis und Applikationsweg. Die Dosis wird nie
/// vorbelegt – die App ist ein Trainingswerkzeug, keine Dosierhilfe.
///
/// [now] liefert den Zeitstempel beim Bestätigen (Szenario-Uhr).
Future<MedicationAdministration?> showMedicationDialog(
  BuildContext context, {
  required DateTime Function() now,
  Medication? preset,
  String? presetRoute,
}) async {
  final medication = preset ?? await _pickMedication(context);
  if (medication == null || !context.mounted) return null;
  return showDialog<MedicationAdministration>(
    context: context,
    builder: (_) => _DoseDialog(
      medication: medication,
      initialRoute: presetRoute,
      now: now,
    ),
  );
}

Future<Medication?> _pickMedication(BuildContext context) {
  return showModalBottomSheet<Medication>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const FractionallySizedBox(
      heightFactor: 0.85,
      child: _MedicationPicker(),
    ),
  );
}

class _MedicationPicker extends StatefulWidget {
  const _MedicationPicker();

  @override
  State<_MedicationPicker> createState() => _MedicationPickerState();
}

class _MedicationPickerState extends State<_MedicationPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = MedicationCatalog.search(_query);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Wirkstoff oder Handelsname suchen...',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text('Kein Medikament gefunden',
                      style: TextStyle(color: context.mutedText)),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final m = results[i];
                    return ListTile(
                      title: Text(m.wirkstoff),
                      subtitle: Text([
                        m.staerke,
                        if (m.handelsname != null) m.handelsname!,
                      ].join(' · ')),
                      onTap: () => Navigator.of(context).pop(m),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DoseDialog extends StatefulWidget {
  final Medication medication;
  final String? initialRoute;
  final DateTime Function() now;

  const _DoseDialog({
    required this.medication,
    required this.initialRoute,
    required this.now,
  });

  @override
  State<_DoseDialog> createState() => _DoseDialogState();
}

class _DoseDialogState extends State<_DoseDialog> {
  final _doseCtrl = TextEditingController();
  String? _route;

  @override
  void initState() {
    super.initState();
    _route = widget.initialRoute;
  }

  @override
  void dispose() {
    _doseCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _doseCtrl.text.trim().isNotEmpty && _route != null;

  @override
  Widget build(BuildContext context) {
    final m = widget.medication;
    return AlertDialog(
      title: Text(m.wirkstoff),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ampulle: ${m.staerke}'
              '${m.handelsname != null ? ' (${m.handelsname})' : ''}',
              style: TextStyle(color: context.mutedText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _doseCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Dosis',
                hintText: 'z. B. 1 mg',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            const Text('Applikationsweg'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in MedicationRoutes.all)
                  ChoiceChip(
                    label: Text(r),
                    selected: _route == r,
                    onSelected: (_) => setState(() => _route = r),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.of(context).pop(MedicationAdministration(
                    medication: m,
                    dose: _doseCtrl.text.trim(),
                    route: _route!,
                    timestamp: widget.now(),
                  ))
              : null,
          child: const Text('Dokumentieren'),
        ),
      ],
    );
  }
}
