import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medication.dart';

/// Speichert einen in der App angepassten Medikamentenkatalog. Ohne
/// Anpassung gilt der Standard-Katalog [MedicationCatalog.all].
class MedicationCatalogService {
  static const String _key = 'medication_catalog_v1';

  /// Lädt den gespeicherten Katalog nach [MedicationCatalog.current].
  /// Beschädigte Daten führen zum Standard-Katalog statt zu einem Absturz.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_key);
      if (jsonStr == null) {
        MedicationCatalog.current = MedicationCatalog.all;
        return;
      }
      final decoded = json.decode(jsonStr) as List<dynamic>;
      MedicationCatalog.current = decoded
          .map((e) => Medication.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Medikamentenkatalog konnte nicht gelesen werden: $e');
      MedicationCatalog.current = MedicationCatalog.all;
    }
  }

  /// Speichert [medications] als angepassten Katalog.
  static Future<void> save(List<Medication> medications) async {
    MedicationCatalog.current = List.unmodifiable(medications);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, json.encode(medications.map((m) => m.toJson()).toList()));
  }

  /// Verwirft die Anpassung und stellt den Standard-Katalog wieder her.
  static Future<void> reset() async {
    MedicationCatalog.current = MedicationCatalog.all;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Ist der Katalog gegenüber dem Standard angepasst?
  static Future<bool> isCustomized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }
}
