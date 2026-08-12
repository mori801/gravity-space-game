import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'game/progress.dart';
import 'game/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  LevelProgress.instance.load(prefs);
  GameSettings.instance.load(prefs);
  runApp(const GravityRocketApp());
}
