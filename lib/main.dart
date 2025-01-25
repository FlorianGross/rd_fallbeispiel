import 'package:flutter/material.dart';

import 'QualificationSelectionScreen.dart';

void main() {
  runApp(PatientCareApp());
}

class PatientCareApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patientenversorgung',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: QualificationSelectionScreen(),
    );
  }
}
