import 'package:flutter/material.dart';

import '../../game/gravity_rocket_game.dart';
import '../../game/levels/levels.dart';
import '../../game/settings.dart';
import '../level_select_screen.dart';
import 'animated_press_scale.dart';

/// Shown when a level is won. Tuned to get the player back into the action
/// as fast as possible:
/// - The primary action (Next Level, or "Back to Levels" after the last
///   one) sits in the bottom-right thumb zone — the same corner
///   [HudOverlay] anchors its power button, so the thumb that just
///   released a launch doesn't have to travel to reach it.
/// - When there's a next level, it auto-advances after a short countdown;
///   a single tap anywhere on the countdown cancels it, for a player who
///   wants to linger.
/// - Tapping anywhere on the background, or swiping up, also triggers the
///   primary action; swiping down goes to the menu — low-precision
///   shortcuts for players who don't want to aim for a button at all.
/// - "Next Level" swaps the running game over to the new level in place
///   (see [GravityRocketGame.loadLevel]) instead of pushing a new route,
///   so advancing feels instant rather than paying for a screen transition.
class WinOverlay extends StatefulWidget {
  const WinOverlay({super.key, required this.game});

  final GravityRocketGame game;

  @override
  State<WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<WinOverlay>
    with TickerProviderStateMixin {
  /// How long the auto-advance countdown runs before jumping to the next
  /// level on its own. Short enough to feel snappy, long enough to read.
  static const _autoAdvanceDuration = Duration(seconds: 3);

  /// Minimum vertical fling speed (logical pixels/second) for a swipe to
  /// count as a deliberate up/down gesture rather than an incidental drag.
  static const double _swipeVelocityThreshold = 300;

  late final AnimationController _entranceController;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceOpacity;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  late final AnimationController _countdownController;

  late final int _currentIndex;
  late final bool _hasNextLevel;
  late final bool _isLastLevel;

  late final int _shotsTaken = widget.game.shotCount;
  late final int _stars = starsForShotCount(_shotsTaken);

  /// True while the countdown is running. Flips to false the moment the
  /// player taps it to cancel, or once it fires and navigation begins —
  /// either way, the corner control then behaves as an ordinary static
  /// button.
  bool _autoAdvanceActive = false;

  @override
  void initState() {
    super.initState();

    _currentIndex = kLevels.indexWhere((l) => l.id == widget.game.level.id);
    _hasNextLevel = _currentIndex >= 0 && _currentIndex < kLevels.length - 1;
    _isLastLevel = _currentIndex == kLevels.length - 1;

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 150),
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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });

    _countdownController = AnimationController(
      vsync: this,
      duration: _autoAdvanceDuration,
    );
    if (_hasNextLevel) {
      _autoAdvanceActive = true;
      _countdownController.addStatusListener(_onCountdownStatusChanged);
      _countdownController.forward();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _countdownController.removeStatusListener(_onCountdownStatusChanged);
    _countdownController.dispose();
    super.dispose();
  }

  void _onCountdownStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _goToNextLevel();
    }
  }

  /// Cancels the pending auto-advance, if any, and reverts to a static
  /// button. Safe to call even when no countdown is running.
  void _cancelAutoAdvance() {
    if (!_autoAdvanceActive) {
      return;
    }
    _countdownController.stop();
    setState(() => _autoAdvanceActive = false);
  }

  void _goToNextLevel() {
    if (!_hasNextLevel) {
      return;
    }
    GameSettings.instance.selectionClick();
    widget.game.loadLevel(kLevels[_currentIndex + 1]);
  }

  void _goToLevelSelect() {
    GameSettings.instance.selectionClick();
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LevelSelectScreen()));
  }

  void _retry() {
    _cancelAutoAdvance();
    GameSettings.instance.selectionClick();
    widget.game.resetLevel();
  }

  void _goToMenu() {
    _cancelAutoAdvance();
    GameSettings.instance.selectionClick();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Whatever the big bottom-right control currently does when tapped —
  /// shared by the control itself, the tap-anywhere background gesture,
  /// and the swipe-up gesture, so the low-precision shortcuts always match
  /// what the control visibly promises. A tap during the auto-advance
  /// countdown always advances immediately (skips ahead) rather than just
  /// cancelling the timer — cancelling-then-requiring-a-second-tap made
  /// "go to the next level" a two-tap action, defeating the point of a
  /// one-tap-fast flow.
  void _primaryAction() {
    if (_hasNextLevel) {
      _goToNextLevel();
    } else if (_isLastLevel) {
      _goToLevelSelect();
    } else {
      _retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _primaryAction,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity <= -_swipeVelocityThreshold) {
          _primaryAction();
        } else if (velocity >= _swipeVelocityThreshold) {
          _goToMenu();
        }
      },
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, -0.35),
            child: FadeTransition(
              opacity: _entranceOpacity,
              child: ScaleTransition(
                scale: _entranceScale,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentIndex >= 0) ...[
                          Text(
                            'Level ${_currentIndex + 1} of '
                            '${kLevels.length} complete',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        const Text(
                          'Level Complete!',
                          style: TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (i) {
                            return Icon(
                              i < _stars ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 28,
                            );
                          }),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_shotsTaken shot${_shotsTaken == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // "Retry" only needs its own slot here when the
                        // corner control is doing something else
                        // (advancing or returning to the level list) —
                        // when there's no next level and this isn't the
                        // last level either (defensive fallback for an
                        // unrecognised level id), the corner control
                        // already is Retry.
                        if (_hasNextLevel || _isLastLevel)
                          AnimatedPressScale(
                            child: OutlinedButton(
                              onPressed: _retry,
                              child: const Text('Retry'),
                            ),
                          ),
                        if (_hasNextLevel || _isLastLevel)
                          const SizedBox(height: 8),
                        AnimatedPressScale(
                          child: TextButton(
                            onPressed: _goToMenu,
                            child: const Text('Menu'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: SafeArea(
              child: ScaleTransition(
                scale: _pulseScale,
                child: AnimatedPressScale(
                  child: _hasNextLevel && _autoAdvanceActive
                      ? _buildCountdownControl()
                      : _buildPrimaryButton(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    final String label;
    final IconData icon;
    final VoidCallback onPressed;
    if (_hasNextLevel) {
      label = 'Next Level';
      icon = Icons.arrow_forward;
      onPressed = _goToNextLevel;
    } else if (_isLastLevel) {
      label = 'Back to Levels';
      icon = Icons.grid_view;
      onPressed = _goToLevelSelect;
    } else {
      label = 'Retry';
      icon = Icons.replay;
      onPressed = _retry;
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      label: Text(
        label,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(180, 64),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
      ),
    );
  }

  Widget _buildCountdownControl() {
    return AnimatedBuilder(
      animation: _countdownController,
      builder: (context, _) {
        final remainingFraction = 1 - _countdownController.value;
        final totalSeconds = _autoAdvanceDuration.inSeconds;
        final secondsLeft = (totalSeconds * remainingFraction).ceil().clamp(
          1,
          totalSeconds,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: _goToNextLevel,
              icon: const Icon(Icons.arrow_forward, size: 28),
              label: Text(
                'Next Level in $secondsLeft…',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(180, 64),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 160,
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: remainingFraction),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Tap to skip', style: TextStyle(fontSize: 11)),
          ],
        );
      },
    );
  }
}
