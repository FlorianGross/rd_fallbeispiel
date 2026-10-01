import 'package:flutter/material.dart';

/// Farben, die im Hell- und Dunkelmodus lesbar bleiben.
///
/// Die Screens nutzen viele feste Material-Töne (z. B. `shade50` als Fläche,
/// `shade900` als Text). Im Dunkelmodus ergeben die helle Flächen mit heller
/// Schrift. Diese Helfer liefern im Hellmodus die bisherigen Töne und im
/// Dunkelmodus passende dunkle bzw. aufgehellte Varianten.
extension AdaptiveColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Zarte, eingefärbte Fläche (hell: `shade50`).
  Color softBg(MaterialColor color) => isDark
      ? Color.alphaBlend(
          color.withAlpha(46), Theme.of(this).colorScheme.surface)
      : color.shade50;

  /// Kräftiger Text-/Icon-Ton auf einer [softBg]-Fläche (hell: `shade800`).
  Color strongFg(MaterialColor color) =>
      isDark ? color.shade200 : color.shade800;

  /// Gedämpfter Sekundärtext (hell: grau 600–700).
  Color get mutedText => Theme.of(this).colorScheme.onSurfaceVariant;

  /// Neutrale Fläche, z. B. Fortschrittsbalken-Hintergrund (hell: grau 200–300).
  Color get trackBg => isDark ? Colors.grey.shade800 : Colors.grey.shade300;

  /// Normale Kartenfläche (hell: weiß).
  Color get surface => Theme.of(this).colorScheme.surface;

  /// Normale Schriftfarbe (hell: schwarz).
  Color get onSurface => Theme.of(this).colorScheme.onSurface;
}
