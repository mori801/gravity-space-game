import 'package:flutter/material.dart';

import '../../game/gravity_rocket_game.dart';

class LoseOverlay extends StatelessWidget {
  const LoseOverlay({super.key, required this.game});

  final GravityRocketGame game;

  @override
  Widget build(BuildContext context) {
    final message = switch (game.loseReason) {
      LoseReason.crash => 'The rocket crashed into a planet.',
      LoseReason.outOfBounds => 'The rocket flew off into space.',
      null => 'The rocket did not make it.',
    };

    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Mission Failed', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
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
