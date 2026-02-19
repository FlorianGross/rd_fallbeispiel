import 'package:flutter/material.dart';

import 'Screens/setup_screen.dart';

/// Globaler ThemeMode-Notifier – kein Paket benötigt
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier(ThemeMode.light);

void main() {
  runApp(const PatientCareApp());
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
