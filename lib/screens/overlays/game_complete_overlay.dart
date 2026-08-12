import 'package:flutter/material.dart';

import '../../game/gravity_rocket_game.dart';
import '../../game/levels/levels.dart';
import '../../game/progress.dart';
import '../../game/settings.dart';
import '../level_select_screen.dart';
import 'animated_press_scale.dart';

/// Shown instead of the routine per-level `WinOverlay` specifically when
/// the just-won level is the last one in [kLevels] — a distinct, bigger
/// celebration moment rather than a reskinned per-level win card. Unlike
/// `WinOverlay`, there is no "next level" to advance to and no
/// auto-advance countdown; the only path forward is back to the level
/// list.
///
/// Reading [LevelProgress.instance.totalStars] here (as a `late final`
/// field in [initState]) is safe and accurate: [GravityRocketGame._win]
/// calls [LevelProgress.recordStars] for the just-won last level before it
/// decides which overlay to show, so by the time this widget mounts the
/// total already includes that level's stars.
class GameCompleteOverlay extends StatefulWidget {
  const GameCompleteOverlay({super.key, required this.game});

  final GravityRocketGame game;

  @override
  State<GameCompleteOverlay> createState() => _GameCompleteOverlayState();
}

class _GameCompleteOverlayState extends State<GameCompleteOverlay>
    with SingleTickerProviderStateMixin {
  late final int _totalStars = LevelProgress.instance.totalStars;
  late final int _maxStars = kLevels.length * 3;

  late final AnimationController _entranceController;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceOpacity;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    )..forward();
    final entranceCurve = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      entranceCurve,
    );
    _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      entranceCurve,
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _goToLevelSelect() {
    GameSettings.instance.selectionClick();
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LevelSelectScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _goToLevelSelect,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.2,
            colors: [Color(0xFF2A1B4D), Color(0xFF04061A)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _entranceOpacity,
            child: ScaleTransition(
              scale: _entranceScale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'All Levels Complete!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You cleared all ${kLevels.length} levels.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 24),
                      const SizedBox(width: 6),
                      Text(
                        '$_totalStars / $_maxStars total stars',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  AnimatedPressScale(
                    child: ElevatedButton.icon(
                      onPressed: _goToLevelSelect,
                      icon: const Icon(Icons.grid_view, size: 28),
                      label: const Text(
                        'Back to Levels',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(240, 64),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
