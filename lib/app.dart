import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class MockMateApp extends StatelessWidget {
  const MockMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MockMate MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}
