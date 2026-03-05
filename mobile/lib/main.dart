import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const ASessionApp());
}

class ASessionApp extends StatelessWidget {
  const ASessionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A:SESSION',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1C7C54)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
