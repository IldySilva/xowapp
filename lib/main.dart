import 'package:flutter/material.dart';
import 'screens/capture_screen.dart';

void main() {
  runApp(const XowCaseApp());
}

class XowCaseApp extends StatelessWidget {
  const XowCaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'XowCase',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const CaptureScreen(),
    );
  }
}
