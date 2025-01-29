import 'package:flutter/material.dart';

import 'Screens/setup_screen.dart';
import 'dart:async';


void main() {
  runApp(const PatientCareApp());
}

class PatientCareApp extends StatelessWidget {
  const PatientCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patientenversorgung',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: const QualificationSelectionScreen(),
    );
  }
}