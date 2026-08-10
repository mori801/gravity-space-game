import 'package:flutter/material.dart';

import '../../game/gravity_rocket_game.dart';
import '../../game/levels/levels.dart';
import '../game_screen.dart';

class WinOverlay extends StatelessWidget {
  const WinOverlay({super.key, required this.game});

  final GravityRocketGame game;

  @override
  Widget build(BuildContext context) {
    final currentIndex = kLevels.indexWhere((l) => l.id == game.level.id);
    final hasNextLevel =
        currentIndex >= 0 && currentIndex < kLevels.length - 1;

    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Level Complete!', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 16),
              if (hasNextLevel)
                ElevatedButton(
                  onPressed: () {
                    final nextLevel = kLevels[currentIndex + 1];
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => GameScreen(level: nextLevel),
                      ),
                    );
                  },
                  child: const Text('Next Level'),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: game.resetLevel,
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Menu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
