import 'package:flutter/material.dart';

import '../../game/gravity_rocket_game.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});

  final GravityRocketGame game;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Paused', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  game.overlays.remove('PauseMenu');
                  game.resumeEngine();
                },
                child: const Text('Resume'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  game.overlays.remove('PauseMenu');
                  game.resetLevel();
                },
                child: const Text('Restart'),
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
