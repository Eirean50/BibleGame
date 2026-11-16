import 'package:flutter/material.dart';

import 'main_menu_screen.dart';

void main() => runApp(const OldTestamentApp());

class OldTestamentApp extends StatelessWidget {
  const OldTestamentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Old Testament',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD8B675),
          brightness: Brightness.dark,
          surface: const Color(0xFF101B32),
        ),
        scaffoldBackgroundColor: const Color(0xFF101B32),
      ),
      home: const MainMenuScreen(),
    );
  }
}
