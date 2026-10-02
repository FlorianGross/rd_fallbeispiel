import 'package:flutter/material.dart';

/// Ab dieser verfügbaren Breite gilt das Layout als „breit“ (Tablet,
/// Desktop): mehrspaltige Schema-Listen und festes CPR-Bedienfeld.
const double kWideLayoutBreakpoint = 900;

/// Ab dieser Breite bekommen die Schema-Karten drei statt zwei Spalten.
const double kThreeColumnBreakpoint = 1300;

/// Maximale Inhaltsbreite für formularartige Screens (Einstieg, Auswertung,
/// Verlauf), damit sie auf Tablets nicht über die volle Breite gezogen werden.
const double kMaxContentWidth = 760;

bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;

/// Anzahl der Spalten für Schema-Karten bei der gegebenen Breite.
int schemaColumnCount(double width) {
  if (width >= kThreeColumnBreakpoint) return 3;
  if (width >= kWideLayoutBreakpoint) return 2;
  return 1;
}

/// Zentriert [child] und begrenzt es auf [maxWidth]. Auf schmalen Geräten
/// ändert sich nichts.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Verteilt [children] spaltenweise auf [columns] Spalten: Die erste Spalte
/// enthält die ersten Einträge, die zweite die folgenden usw. So bleibt die
/// Lesereihenfolge (z. B. SSSS → ABCDE → Anamnese) von oben nach unten
/// erhalten. Jede Spalte wächst unabhängig, wenn eine Karte aufklappt.
class ColumnFlow extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final double spacing;

  const ColumnFlow({
    super.key,
    required this.children,
    required this.columns,
    this.spacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    final perColumn = (children.length / columns).ceil();
    final cols = <Widget>[];
    for (var c = 0; c < columns; c++) {
      final start = c * perColumn;
      final end = (start + perColumn).clamp(0, children.length);
      if (c > 0) cols.add(SizedBox(width: spacing));
      cols.add(Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: start < end ? children.sublist(start, end) : const [],
        ),
      ));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: cols);
  }
}
