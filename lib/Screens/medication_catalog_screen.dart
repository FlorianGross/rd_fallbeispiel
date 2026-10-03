import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../services/medication_catalog_service.dart';
import '../utils/adaptive_colors.dart';
import '../widgets/responsive.dart';

/// Medikamentenkatalog bearbeiten: Einträge hinzufügen, ändern, löschen oder
/// den Standard-Katalog wiederherstellen. So kann jede Wache die eigene
/// Bestückung hinterlegen.
class MedicationCatalogScreen extends StatefulWidget {
  const MedicationCatalogScreen({super.key});

  @override
  State<MedicationCatalogScreen> createState() =>
      _MedicationCatalogScreenState();
}

class _MedicationCatalogScreenState extends State<MedicationCatalogScreen> {
  late List<Medication> _items;
  bool _customized = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(MedicationCatalog.current);
    MedicationCatalogService.isCustomized().then((v) {
      if (mounted) setState(() => _customized = v);
    });
  }

  List<Medication> get _sorted => List.of(_items)
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  Future<void> _save(List<Medication> items) async {
    await MedicationCatalogService.save(items);
    if (!mounted) return;
    setState(() {
      _items = items;
      _customized = true;
    });
  }

  Future<void> _edit([Medication? existing]) async {
    final result = await showDialog<Medication>(
      context: context,
      builder: (_) => _MedicationEditDialog(
        existing: existing,
        takenIds: {
          for (final m in _items)
            if (m.id != existing?.id) m.id,
        },
      ),
    );
    if (result == null) return;
    final items = List.of(_items);
    if (existing == null) {
      items.add(result);
    } else {
      items[items.indexWhere((m) => m.id == existing.id)] = result;
    }
    await _save(items);
  }

  Future<void> _delete(Medication m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: Text('„${m.label}“ wird aus dem Katalog entfernt. Bereits '
            'dokumentierte Gaben im Verlauf bleiben erhalten.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _save(_items.where((e) => e.id != m.id).toList());
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Standard wiederherstellen?'),
        content: const Text('Alle Änderungen am Katalog gehen verloren. Es '
            'gilt wieder die Bestückungsliste „Rucksack Kreislauf Modul 1“.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Wiederherstellen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await MedicationCatalogService.reset();
    if (!mounted) return;
    setState(() {
      _items = List.of(MedicationCatalog.current);
      _customized = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _sorted;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medikamentenkatalog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Standard wiederherstellen',
            onPressed: _customized ? _reset : null,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Medikament'),
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                '${items.length} Einträge · '
                '${_customized ? 'angepasst' : 'Standard (Rucksack Kreislauf Modul 1)'}\n'
                'Nur Wirkstoff, Stärke und Handelsname – keine Dosierungen.',
                style: TextStyle(color: context.mutedText, fontSize: 13),
              ),
            ),
            for (final m in items)
              ListTile(
                title: Text(m.wirkstoff),
                subtitle: Text([
                  m.staerke,
                  if (m.handelsname != null) m.handelsname!,
                ].join(' · ')),
                onTap: () => _edit(m),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Löschen',
                  onPressed: () => _delete(m),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MedicationEditDialog extends StatefulWidget {
  final Medication? existing;

  /// IDs der übrigen Einträge – Wirkstoff + Stärke müssen eindeutig sein
  final Set<String> takenIds;

  const _MedicationEditDialog({required this.existing, required this.takenIds});

  @override
  State<_MedicationEditDialog> createState() => _MedicationEditDialogState();
}

class _MedicationEditDialogState extends State<_MedicationEditDialog> {
  late final _wirkstoff =
      TextEditingController(text: widget.existing?.wirkstoff ?? '');
  late final _staerke =
      TextEditingController(text: widget.existing?.staerke ?? '');
  late final _handelsname =
      TextEditingController(text: widget.existing?.handelsname ?? '');

  @override
  void dispose() {
    _wirkstoff.dispose();
    _staerke.dispose();
    _handelsname.dispose();
    super.dispose();
  }

  Medication get _draft => Medication(
        wirkstoff: _wirkstoff.text.trim(),
        staerke: _staerke.text.trim(),
        handelsname:
            _handelsname.text.trim().isEmpty ? null : _handelsname.text.trim(),
      );

  String? get _error {
    final d = _draft;
    if (d.wirkstoff.isEmpty || d.staerke.isEmpty) return null;
    if (widget.takenIds.contains(d.id)) {
      return 'Diesen Wirkstoff gibt es in dieser Stärke schon';
    }
    return null;
  }

  bool get _valid =>
      _draft.wirkstoff.isNotEmpty && _draft.staerke.isNotEmpty && _error == null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Medikament hinzufügen'
          : 'Medikament bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _wirkstoff,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Wirkstoff *',
                hintText: 'z. B. Adrenalin',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _staerke,
              decoration: InputDecoration(
                labelText: 'Stärke / Packung *',
                hintText: 'z. B. 1 mg / 1 ml',
                errorText: _error,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _handelsname,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Handelsname (optional)',
                hintText: 'z. B. Suprarenin',
              ),
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
          onPressed: _valid ? () => Navigator.of(context).pop(_draft) : null,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
