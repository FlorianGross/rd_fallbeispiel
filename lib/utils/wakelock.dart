import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Hält den Bildschirm während eines laufenden Fallbeispiels an, damit er sich
/// nicht mitten in der Reanimation sperrt. Fehler (z. B. Plattform ohne
/// Unterstützung) werden nur geloggt.
void setScreenAwake(bool awake) {
  WakelockPlus.toggle(enable: awake).catchError((Object e) {
    debugPrint('Wakelock nicht verfügbar: $e');
  });
}
