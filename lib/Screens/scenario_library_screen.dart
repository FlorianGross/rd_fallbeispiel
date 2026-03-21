import 'package:flutter/material.dart';

import '../models/scenario.dart';

class ScenarioLibraryScreen extends StatefulWidget {
  const ScenarioLibraryScreen({super.key});

  @override
  State<ScenarioLibraryScreen> createState() => _ScenarioLibraryScreenState();
}

class _ScenarioLibraryScreenState extends State<ScenarioLibraryScreen> {
  String? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PredefinedScenario> get _filtered {
    return PredefinedScenarios.scenarios.where((s) {
      final matchCat =
          _selectedCategory == null || s.category == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      final matchQ = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q) ||
          s.category.toLowerCase().contains(q);
      return matchCat && matchQ;
    }).toList();
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Einfach':
        return Colors.green;
      case 'Mittel':
        return Colors.orange;
      case 'Schwer':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = PredefinedScenarios.categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Szenario-Bibliothek'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.redAccent, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Szenario suchen...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Category filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _buildCategoryChip('Alle', null),
                ...categories.map((c) => _buildCategoryChip(c, c)),
              ],
            ),
          ),
          // Scenario list
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'Keine Szenarien gefunden.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) =>
                        _ScenarioCard(
                          scenario: _filtered[i],
                          difficultyColor:
                              _difficultyColor(_filtered[i].difficulty),
                          onSelect: (s) => Navigator.of(context).pop(s),
                        ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? category) {
    final selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) =>
            setState(() => _selectedCategory = category),
        selectedColor: Colors.blue.shade100,
        checkmarkColor: Colors.blue.shade700,
      ),
    );
  }
}

class _ScenarioCard extends StatefulWidget {
  final PredefinedScenario scenario;
  final Color difficultyColor;
  final void Function(PredefinedScenario) onSelect;

  const _ScenarioCard({
    required this.scenario,
    required this.difficultyColor,
    required this.onSelect,
  });

  @override
  State<_ScenarioCard> createState() => _ScenarioCardState();
}

class _ScenarioCardState extends State<_ScenarioCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.scenario;
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
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: s.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(s.icon, color: s.color, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(s.description,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildBadge(s.category, Colors.blue),
                            const SizedBox(width: 6),
                            _buildBadge(
                                s.difficulty, widget.difficultyColor),
                            if (s.suggestResuscitation) ...[
                              const SizedBox(width: 6),
                              _buildBadge('Reanimation', Colors.red),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) _buildExpanded(),
        ],
      ),
    );
  }

  Widget _buildExpanded() {
    final s = widget.scenario;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: s.color.withOpacity(0.04),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.description, size: 18, color: s.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.clinicalPicture,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(
                'Szenario wählen${s.suggestResuscitation ? ' (Reanimation)' : ''}',
              ),
              onPressed: () => widget.onSelect(s),
              style: ElevatedButton.styleFrom(
                backgroundColor: s.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}
