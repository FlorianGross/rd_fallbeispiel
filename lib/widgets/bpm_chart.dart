import 'package:flutter/material.dart';

import '../measure_requirements.dart';

/// Verlauf der Kompressionsfrequenz während einer Reanimation.
///
/// Eine Linie (Frequenz) über der Zeit seit Reanimationsbeginn, der
/// Zielbereich 100–120/min als dezentes Band und Beatmungen als Markierungen
/// an der Zeitachse. Antippen/Wischen zeigt Zeit und Wert des nächsten Punkts.
class BpmChart extends StatefulWidget {
  final List<Map<String, dynamic>> bpmHistory;
  final List<Map<String, dynamic>> ventilationHistory;
  final DateTime start;

  const BpmChart({
    super.key,
    required this.bpmHistory,
    required this.ventilationHistory,
    required this.start,
  });

  @override
  State<BpmChart> createState() => _BpmChartState();
}

/// Ein Messpunkt: Sekunden seit Reanimationsbeginn und Frequenz
typedef _Point = ({double t, double bpm});

class _BpmChartState extends State<BpmChart> {
  int? _selected;

  // Validierte Serienfarben (hell/dunkel), siehe PR-Beschreibung
  static const _lineLight = Color(0xFF2A78D6);
  static const _lineDark = Color(0xFF3987E5);
  static const _ventLight = Color(0xFFEB6834);
  static const _ventDark = Color(0xFFD95926);

  List<_Point> get _points => widget.bpmHistory
      .map((e) => (
            t: (e['timestamp'] as DateTime)
                    .difference(widget.start)
                    .inMilliseconds /
                1000,
            bpm: (e['bpm'] as num).toDouble(),
          ))
      .toList();

  List<double> get _ventilations => widget.ventilationHistory
      .map((e) =>
          (e['timestamp'] as DateTime).difference(widget.start).inMilliseconds /
          1000)
      .where((t) => t >= 0)
      .toList();

  void _select(Offset local, double width, List<_Point> points) {
    if (points.isEmpty) return;
    // Gleiche Zeitachse wie der Painter (inkl. Beatmungen)
    final geo = _ChartGeometry(
        Size(width, _ChartPainter.height), points, _ventilations);
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = (geo.x(points[i].t) - local.dx).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    setState(() => _selected = best);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final lineColor = dark ? _lineDark : _lineLight;
    final ventColor = dark ? _ventDark : _ventLight;
    final points = _points;
    final muted = scheme.onSurfaceVariant;

    final selected = _selected != null && _selected! < points.length
        ? points[_selected!]
        : null;

    return Semantics(
      label: 'Frequenzverlauf der Kompressionen mit ${points.length} '
          'Messungen und ${_ventilations.length} Beatmungen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legende (zwei Elemente → Legende immer sichtbar)
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _legendItem(
                  Container(width: 16, height: 2, color: lineColor),
                  'Frequenz',
                  muted),
              _legendItem(
                  Container(width: 2, height: 10, color: ventColor),
                  'Beatmung',
                  muted),
              _legendItem(
                  Container(
                    width: 16,
                    height: 10,
                    color: Colors.green.withAlpha(dark ? 45 : 35),
                  ),
                  'Ziel ${BpmThresholds.optimalMin}–'
                      '${BpmThresholds.optimalMax}/min',
                  muted),
            ],
          ),
          const SizedBox(height: 8),
          // Tooltip-Zeile oberhalb des Diagramms – verdeckt keine Daten
          SizedBox(
            height: 20,
            child: selected == null
                ? Text('Tippen oder wischen für Einzelwerte',
                    style: TextStyle(fontSize: 11, color: muted))
                : Text(
                    '${_formatTime(selected.t)} · '
                    '${selected.bpm.toStringAsFixed(0)}/min',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _select(d.localPosition, width, points),
                onHorizontalDragUpdate: (d) =>
                    _select(d.localPosition, width, points),
                child: CustomPaint(
                  size: Size(width, _ChartPainter.height),
                  painter: _ChartPainter(
                    points: points,
                    ventilations: _ventilations,
                    selected: _selected,
                    lineColor: lineColor,
                    ventColor: ventColor,
                    bandColor: Colors.green.withAlpha(dark ? 45 : 35),
                    gridColor: scheme.outlineVariant.withAlpha(120),
                    labelStyle: (Theme.of(context).textTheme.labelSmall ??
                            const TextStyle())
                        .copyWith(fontSize: 10, color: muted),
                    surface: scheme.surface,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Widget swatch, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

String _formatTime(double seconds) {
  final s = seconds.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Achsen- und Koordinatenberechnung, geteilt von Painter und Hit-Test
class _ChartGeometry {
  static const double left = 36;
  static const double right = 8;
  static const double top = 4;
  static const double bottom = 22; // Platz für Zeitachsen-Beschriftung
  static const double minBpm = 40;
  static const double maxBpm = 180;

  final Size size;
  final double maxT;

  _ChartGeometry(this.size, List<_Point> points, [List<double> extra = const []])
      : maxT = [
          30.0,
          ...points.map((p) => p.t),
          ...extra,
        ].reduce((a, b) => a > b ? a : b);

  double get plotBottom => size.height - bottom;

  double x(double t) => left + (t / maxT) * (size.width - left - right);

  double y(double bpm) {
    final v = bpm.clamp(minBpm, maxBpm);
    return top + (1 - (v - minBpm) / (maxBpm - minBpm)) * (plotBottom - top);
  }
}

class _ChartPainter extends CustomPainter {
  static const double height = 200;

  final List<_Point> points;
  final List<double> ventilations;
  final int? selected;
  final Color lineColor;
  final Color ventColor;
  final Color bandColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final Color surface;

  _ChartPainter({
    required this.points,
    required this.ventilations,
    required this.selected,
    required this.lineColor,
    required this.ventColor,
    required this.bandColor,
    required this.gridColor,
    required this.labelStyle,
    required this.surface,
  });

  Color get labelColor => labelStyle.color ?? const Color(0xFF757575);

  /// Lücken über diesem Abstand (Beatmung, Pause) unterbrechen die Linie
  static const double _gapSeconds = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _ChartGeometry(size, points, ventilations);

    // Zielbereich
    canvas.drawRect(
      Rect.fromLTRB(
        _ChartGeometry.left,
        geo.y(BpmThresholds.optimalMax.toDouble()),
        size.width - _ChartGeometry.right,
        geo.y(BpmThresholds.optimalMin.toDouble()),
      ),
      Paint()..color = bandColor,
    );

    // Hairline-Raster + Y-Beschriftung
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final v in [60, 100, 120, 160]) {
      final y = geo.y(v.toDouble());
      canvas.drawLine(Offset(_ChartGeometry.left, y),
          Offset(size.width - _ChartGeometry.right, y), grid);
      _text(canvas, '$v', Offset(_ChartGeometry.left - 6, y),
          align: TextAlign.right);
    }
    // Grundlinie
    canvas.drawLine(Offset(_ChartGeometry.left, geo.plotBottom),
        Offset(size.width - _ChartGeometry.right, geo.plotBottom), grid);

    // Zeitachse: höchstens ~5 Beschriftungen
    final step = [15, 30, 60, 120, 300, 600]
        .firstWhere((s) => geo.maxT / s <= 5, orElse: () => 1200);
    for (var t = 0; t <= geo.maxT; t += step) {
      _text(canvas, _formatTime(t.toDouble()),
          Offset(geo.x(t.toDouble()), geo.plotBottom + 12),
          align: TextAlign.center);
    }

    // Beatmungen als Markierungen an der Grundlinie
    final vent = Paint()
      ..color = ventColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final t in ventilations) {
      final x = geo.x(t);
      canvas.drawLine(
          Offset(x, geo.plotBottom - 10), Offset(x, geo.plotBottom - 1), vent);
    }

    // Frequenzlinie, an Lücken unterbrochen
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = lineColor;
    Path? path;
    for (var i = 0; i < points.length; i++) {
      final p = Offset(geo.x(points[i].t), geo.y(points[i].bpm));
      final startsSegment =
          i == 0 || points[i].t - points[i - 1].t > _gapSeconds;
      final endsSegment = i == points.length - 1 ||
          points[i + 1].t - points[i].t > _gapSeconds;
      if (startsSegment) {
        if (path != null) canvas.drawPath(path, line);
        path = Path()..moveTo(p.dx, p.dy);
        // Einzelpunkt ohne Nachbarn sonst unsichtbar
        if (endsSegment) canvas.drawCircle(p, 2, dot);
      } else {
        path!.lineTo(p.dx, p.dy);
      }
    }
    if (path != null) canvas.drawPath(path, line);

    // Auswahl: Fadenkreuz + Punkt mit Oberflächen-Ring
    if (selected != null && selected! < points.length) {
      final p = points[selected!];
      final pos = Offset(geo.x(p.t), geo.y(p.bpm));
      canvas.drawLine(
        Offset(pos.dx, _ChartGeometry.top),
        Offset(pos.dx, geo.plotBottom),
        Paint()
          ..color = labelColor.withAlpha(140)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(pos, 6, Paint()..color = surface);
      canvas.drawCircle(pos, 4, dot);
    }
  }

  void _text(Canvas canvas, String text, Offset anchor,
      {TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => anchor.dx - tp.width,
      TextAlign.center => anchor.dx - tp.width / 2,
      _ => anchor.dx,
    };
    tp.paint(canvas, Offset(dx, anchor.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.lineColor != lineColor ||
      old.ventilations != ventilations;
}
