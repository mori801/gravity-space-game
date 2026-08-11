import 'package:flutter/material.dart';

import 'screens/main_menu_screen.dart';

class GravityRocketApp extends StatelessWidget {
  const GravityRocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gravity Rocket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF4C8DFF),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
  }
}
