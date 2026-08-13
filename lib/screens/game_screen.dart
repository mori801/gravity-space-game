import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/gravity_rocket_game.dart';
import '../game/levels/level.dart';
import 'overlays/game_complete_overlay.dart';
import 'overlays/hud_overlay.dart';
import 'overlays/lose_overlay.dart';
import 'overlays/pause_overlay.dart';
import 'overlays/win_overlay.dart';

/// Hosts the Flame [GameWidget] for one level and wires up all in-game UI
/// as Flame overlays, so the frozen game canvas stays visible behind
/// pause/win/lose panels instead of being replaced by a new route.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level});

  final LevelData level;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GravityRocketGame _game;

  @override
  void initState() {
    super.initState();
    _game = GravityRocketGame(level: widget.level);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<GravityRocketGame>(
        game: _game,
        initialActiveOverlays: const ['HUD'],
        overlayBuilderMap: {
          'HUD': (context, game) => HudOverlay(game: game),
          'PauseMenu': (context, game) => PauseOverlay(game: game),
          'WinOverlay': (context, game) => WinOverlay(game: game),
          'GameCompleteOverlay': (context, game) =>
              GameCompleteOverlay(game: game),
          'LoseOverlay': (context, game) => LoseOverlay(game: game),
        },
      ),
    );
  }
}
