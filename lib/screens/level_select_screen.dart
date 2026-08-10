import 'package:flutter/material.dart';

import '../game/levels/levels.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Level')),
      body: ListView.builder(
        itemCount: kLevels.length,
        itemBuilder: (context, index) {
          final level = kLevels[index];
          return ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(level.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GameScreen(level: level)),
            ),
          );
        },
      ),
    );
  }
}
