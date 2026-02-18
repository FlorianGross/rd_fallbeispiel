import 'package:flutter/material.dart';

/// Gibt die Kategorie-Farbe für ein Schema zurück (für Header/Leading-Akzent)
Color getSchemaColor(String schema) {
  switch (schema) {
    // Lagebeurteilung / Eigensicherung
    case 'SSSS':
    case 'Erster Eindruck':
      return Colors.brown.shade600;

    // Bewusstsein / Neurologie
    case 'WASB':
    case 'ZOPS':
    case 'D':
    case 'BE-FAST':
      return Colors.purple.shade600;

    // Primäres ABCDE
    case 'c/x':
    case 'a':
    case 'b':
    case 'c':
    case 'STU':
      return Colors.red.shade700;

    // Sekundäres ABCDE
    case 'A':
    case 'B':
    case 'C':
    case 'E':
      return Colors.orange.shade700;

    // Anamnese
    case 'SAMPLERS':
    case 'OPQRST':
      return Colors.blue.shade700;

    // Therapeutische Maßnahmen
    case 'Maßnahmen':
    case 'Maßnahmen (erweitert)':
      return Colors.teal.shade700;

    // Reanimation – reversible Ursachen
    case '4H':
    case 'HITS':
      return Colors.red.shade900;

    // Übergabe
    case 'Übergabe (ISBAR)':
      return Colors.indigo.shade700;

    // Nachforderung
    case 'Nachforderung':
      return Colors.cyan.shade700;

    default:
      return Colors.grey.shade600;
  }
}

/// Gibt eine leichte Hintergrundfarbe für Schema-Karten zurück
Color getSchemaBackgroundColor(String schema) {
  return getSchemaColor(schema).withOpacity(0.06);
}
