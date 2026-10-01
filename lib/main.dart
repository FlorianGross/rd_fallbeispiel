import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Screens/setup_screen.dart';

/// Globaler ThemeMode-Notifier – kein Paket benötigt
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier(ThemeMode.light);

const String _themeModeKey = 'theme_mode';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _restoreThemeMode();
  runApp(const PatientCareApp());
}

/// Lädt den zuletzt gewählten Hell/Dunkel-Modus und speichert jede Änderung.
Future<void> _restoreThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_themeModeKey) == ThemeMode.dark.name) {
      themeModeNotifier.value = ThemeMode.dark;
    }
    themeModeNotifier.addListener(() {
      prefs.setString(_themeModeKey, themeModeNotifier.value.name);
    });
  } catch (e) {
    debugPrint('Theme-Einstellung nicht verfügbar: $e');
  }
}

class PatientCareApp extends StatelessWidget {
  const PatientCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Patientenversorgung',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const QualificationSelectionScreen(),
      ),
    );
  }
}
