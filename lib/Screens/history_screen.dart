import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/session_record.dart';
import '../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SessionRecord> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await HistoryService.loadHistory();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    }
  }

  Future<void> _deleteSession(String id) async {
    await HistoryService.deleteSession(id);
    await _load();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Verlauf löschen?'),
          ],
        ),
        content: const Text(
          'Alle gespeicherten Trainingseinheiten werden unwiderruflich gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await HistoryService.clearHistory();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainings-Verlauf'),
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
          if (_sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Verlauf löschen',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Noch keine Trainings gespeichert',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Starte ein Fallbeispiel, um es hier zu sehen.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Aggregate statistics
    final totalSessions = _sessions.length;
    final avgRate = _sessions.isEmpty
        ? 0.0
        : _sessions.map((s) => s.completionRate).reduce((a, b) => a + b) /
            totalSessions;
    final resuscCount = _sessions.where((s) => s.isResuscitation).length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Stats summary card
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.indigo.shade50, Colors.blue.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat(
                    Icons.fitness_center, '$totalSessions', 'Einheiten', Colors.indigo),
                _buildStat(
                    Icons.percent,
                    '${avgRate.toStringAsFixed(0)} %',
                    'Ø Erfolgsrate',
                    avgRate >= 80
                        ? Colors.green
                        : avgRate >= 60
                            ? Colors.orange
                            : Colors.red),
                _buildStat(Icons.monitor_heart, '$resuscCount', 'Reanimationen',
                    Colors.red),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Session list
        ...List.generate(_sessions.length, (i) {
          final s = _sessions[i];
          return _SessionCard(
            session: s,
            onDelete: () => _deleteSession(s.id),
            onNotesChanged: (notes) async {
              await HistoryService.updateSessionNotes(s.id, notes);
              await _load();
            },
          );
        }),
      ],
    );
  }

  Widget _buildStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _SessionCard extends StatefulWidget {
  final SessionRecord session;
  final VoidCallback onDelete;
  final Future<void> Function(String notes) onNotesChanged;

  const _SessionCard({
    required this.session,
    required this.onDelete,
    required this.onNotesChanged,
  });

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = false;
  late TextEditingController _notesCtrl;
  bool _savingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.session.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Color get _rateColor {
    final r = widget.session.completionRate;
    if (r >= 80) return Colors.green;
    if (r >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final dateStr =
        DateFormat('dd.MM.yyyy  HH:mm').format(s.startTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 3,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Type icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: s.isResuscitation
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      s.isResuscitation
                          ? Icons.monitor_heart
                          : Icons.medical_services,
                      color: s.isResuscitation ? Colors.red : Colors.blue,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.scenarioName ??
                              (s.isResuscitation
                                  ? 'Reanimation'
                                  : 'Standardversorgung'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$dateStr  •  ${s.qualification}  •  ${s.formattedDuration}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                        if (s.notes != null && s.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            s.notes!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Rate
                  Column(
                    children: [
                      Text(
                        '${s.completionRate.toStringAsFixed(0)} %',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _rateColor),
                      ),
                      Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) _buildDetail(),
        ],
      ),
    );
  }

  Widget _buildDetail() {
    final s = widget.session;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(14)),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _detailStat(
                  Icons.check_circle, '${s.completedCount}', 'Erledigt', Colors.green),
              _detailStat(
                  Icons.cancel, '${s.missingCount}', 'Fehlend', Colors.red),
              _detailStat(Icons.timer, s.formattedDuration, 'Dauer', Colors.blue),
            ],
          ),
          const SizedBox(height: 12),
          // Notes field
          const Text('Notizen:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Anmerkungen zur Übungseinheit...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(10),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                label: const Text('Löschen',
                    style: TextStyle(color: Colors.red, fontSize: 13)),
                onPressed: widget.onDelete,
              ),
              ElevatedButton.icon(
                icon: _savingNotes
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save, size: 16),
                label: const Text('Notiz speichern',
                    style: TextStyle(fontSize: 13)),
                onPressed: _savingNotes
                    ? null
                    : () async {
                        setState(() => _savingNotes = true);
                        await widget.onNotesChanged(_notesCtrl.text);
                        if (mounted) setState(() => _savingNotes = false);
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailStat(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
