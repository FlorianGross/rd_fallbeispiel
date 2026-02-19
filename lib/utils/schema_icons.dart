import 'package:flutter/material.dart';

/// Gibt das passende Icon für ein Assessment-Schema zurück
IconData getSchemaIcon(String schema) {
  if (schema.contains('Atemwege') || schema == 'a' || schema == 'A') {
    return Icons.air;
  } else if (schema.contains('Atmung') || schema == 'b' || schema == 'B') {
    return Icons.wind_power;
  } else if (schema.contains('Kreislauf') || schema == 'c' || schema == 'C') {
    return Icons.favorite;
  } else if (schema == 'SSSS') {
    return Icons.security;
  } else if (schema == 'WASB') {
    return Icons.psychology;
  } else if (schema == 'STU') {
    return Icons.personal_injury;
  } else if (schema == 'D') {
    return Icons.visibility;
  } else if (schema == 'E') {
    return Icons.thermostat;
  } else if (schema == 'BE-FAST') {
    return Icons.emergency;
  } else if (schema == 'ZOPS') {
    return Icons.quiz;
  } else if (schema.contains('Maßnahmen')) {
    return Icons.medical_services;
  } else if (schema == 'SAMPLERS') {
    return Icons.history_edu;
  } else if (schema == 'OPQRST') {
    return Icons.description;
  } else if (schema == 'Übergabe (ISBAR)') {
    return Icons.handshake;
  } else if (schema == 'Nachforderung') {
    return Icons.phone_in_talk;
  } else if (schema == '4H') {
    return Icons.water_drop;
  } else if (schema == 'HITS') {
    return Icons.coronavirus;
  } else if (schema == 'Erster Eindruck') {
    return Icons.remove_red_eye;
  }
  return Icons.checklist;
}
