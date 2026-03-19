import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_record.dart';

class HistoryService {
  static const String _key = 'session_history_v1';
  static const int _maxSessions = 50;

  static Future<List<SessionRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
    final records = jsonList
        .map((j) => SessionRecord.fromJson(j as Map<String, dynamic>))
        .toList();
    records.sort((a, b) => b.startTime.compareTo(a.startTime));
    return records;
  }

  static Future<void> saveSession(SessionRecord session) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadHistory();
    existing.insert(0, session);
    if (existing.length > _maxSessions) {
      existing.removeRange(_maxSessions, existing.length);
    }
    final jsonStr = json.encode(existing.map((s) => s.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }

  static Future<void> updateSessionNotes(String id, String notes) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadHistory();
    final idx = existing.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    existing[idx] = existing[idx].copyWith(notes: notes);
    final jsonStr = json.encode(existing.map((s) => s.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }

  static Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadHistory();
    existing.removeWhere((s) => s.id == id);
    final jsonStr = json.encode(existing.map((s) => s.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
