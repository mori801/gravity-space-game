import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/gravity_rocket_game.dart';
import '../game/levels/level.dart';
import '../game/levels/levels.dart';
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
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _game = GravityRocketGame(level: widget.level);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Handles the keyboard shortcuts that act across every overlay state
  /// (R/Escape/Enter), leaving arrow/A-D steering and Space charging to
  /// [HudOverlay]'s own focus node — those only ever apply while its
  /// aim/charge UI is shown, whereas these three need to work regardless
  /// of which overlay (if any) is currently active.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyR:
        // Mirrors LoseOverlay's plain "Restart" action (not
        // retrySameShot()'s exact-replay) — the least surprising default
        // for a single always-available shortcut, valid in every status
        // (ready/launched/won/lost) since resetLevel() itself is safe to
        // call from any of them.
        _game.resetLevel();
        setState(() {});
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        setState(() {
          if (_game.overlays.isActive('PauseMenu')) {
            _game.overlays.remove('PauseMenu');
            _game.resumeEngine();
          } else if (_game.status != GameStatus.won &&
              _game.status != GameStatus.lost) {
            _game.overlays.add('PauseMenu');
            _game.pauseEngine();
          }
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (_game.overlays.isActive('WinOverlay') ||
            _game.overlays.isActive('GameCompleteOverlay')) {
          final currentIndex =
              kLevels.indexWhere((l) => l.id == _game.level.id);
          final hasNextLevel =
              currentIndex >= 0 && currentIndex < kLevels.length - 1;
          setState(() {
            if (hasNextLevel) {
              _game.loadLevel(kLevels[currentIndex + 1]);
            } else {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: GameWidget<GravityRocketGame>(
          game: _game,
          // GameWidget's own internal Focus node autofocuses by default
          // and — since GravityRocketGame doesn't mix in Flame's
          // KeyboardEvents — swallows every key event as `handled` before
          // it can ever reach this screen's or HudOverlay's own
          // Focus.onKeyEvent handlers (both sit inside it in the widget
          // tree, so its primary focus wins first). Disabling autofocus
          // here lets HudOverlay's own autofocused node take real focus
          // instead.
          autofocus: false,
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
      ),
    );
  }
}
