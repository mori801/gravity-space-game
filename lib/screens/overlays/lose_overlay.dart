import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/gravity_rocket_game.dart';

/// Shown when a level is lost. Tuned to get the player back into the
/// action as fast as possible:
/// - The failure reason is a compact icon + short label rather than a
///   full sentence, so it reads at a glance instead of being read.
/// - The primary "Retry" action sits in the bottom-right thumb zone — the
///   same corner [HudOverlay] anchors its power button — so the thumb
///   that just watched the rocket fail doesn't have to travel to try
///   again.
/// - A secondary "Same Shot" action repeats the exact power/angle of the
///   failed attempt in one tap (see [GravityRocketGame.retrySameShot]),
///   for a player who wants to see the same trajectory again without
///   re-aiming.
/// - Tapping anywhere on the background, or swiping up, also retries;
///   swiping down goes to the menu.
class LoseOverlay extends StatefulWidget {
  const LoseOverlay({super.key, required this.game});

  final GravityRocketGame game;

  @override
  State<LoseOverlay> createState() => _LoseOverlayState();
}

class _LoseOverlayState extends State<LoseOverlay>
    with TickerProviderStateMixin {
  /// Minimum vertical fling speed (logical pixels/second) for a swipe to
  /// count as a deliberate up/down gesture rather than an incidental drag.
  static const double _swipeVelocityThreshold = 300;

  late final AnimationController _entranceController;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceOpacity;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();

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
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _retry() {
    HapticFeedback.selectionClick();
    widget.game.resetLevel();
  }

  void _retrySameShot() {
    HapticFeedback.selectionClick();
    widget.game.retrySameShot();
  }

  void _goToMenu() {
    HapticFeedback.selectionClick();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final reasonIcon = switch (widget.game.loseReason) {
      LoseReason.crash => Icons.warning_amber_rounded,
      LoseReason.outOfBounds => Icons.open_in_full,
      LoseReason.noFlyZone => Icons.block,
      null => Icons.error_outline,
    };
    final reasonLabel = switch (widget.game.loseReason) {
      LoseReason.crash => 'Crashed',
      LoseReason.outOfBounds => 'Off course',
      LoseReason.noFlyZone => 'No-fly zone',
      null => 'Failed',
    };
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _retry,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity <= -_swipeVelocityThreshold) {
          _retry();
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
                        Text(
                          'Mission Failed',
                          style: TextStyle(fontSize: 13, color: mutedColor),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(reasonIcon, size: 16, color: mutedColor),
                            const SizedBox(width: 4),
                            Text(
                              reasonLabel,
                              style: TextStyle(
                                fontSize: 13,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _AnimatedPressScale(
                          child: OutlinedButton.icon(
                            onPressed: _retrySameShot,
                            icon: const Icon(Icons.replay, size: 18),
                            label: const Text('Same Shot'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _AnimatedPressScale(
                          child: TextButton(
                            onPressed: _goToMenu,
                            style: TextButton.styleFrom(
                              foregroundColor: mutedColor,
                            ),
                            child: const Text(
                              'Menu',
                              style: TextStyle(fontSize: 13),
                            ),
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
                child: _AnimatedPressScale(
                  child: ElevatedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.replay, size: 28),
                    label: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(180, 64),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps [child] with a quick press-down/settle scale "kick" — the same
/// 260ms `Curves.easeOutBack` pop used by the HUD's power button and the
/// pause overlay, so every overlay in the app shares one tactile feel.
/// Uses a [Listener] rather than a [GestureDetector] so it only observes
/// raw pointer events and never competes with the wrapped
/// button/GestureDetector's own tap handling for the gesture.
class _AnimatedPressScale extends StatefulWidget {
  const _AnimatedPressScale({required this.child});

  final Widget child;

  @override
  State<_AnimatedPressScale> createState() => _AnimatedPressScaleState();
}

class _AnimatedPressScaleState extends State<_AnimatedPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
