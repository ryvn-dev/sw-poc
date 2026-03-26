import 'package:flutter/material.dart';
import 'screens/profile_screen.dart';

void main() {
  runApp(const SwPocApp());
}

class SwPocApp extends StatelessWidget {
  const SwPocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SW BLE',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ProfileScreen(),
    );
  }
}
