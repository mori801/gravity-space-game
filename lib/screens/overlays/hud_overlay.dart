import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/gravity_rocket_game.dart';

/// Pre-launch: drag anywhere on screen to aim (a fading arrow on the
/// rocket briefly shows the resulting direction), then press and hold the
/// power button in the corner to charge the shot and release to launch.
/// Post-launch: shows a single pause button.
class HudOverlay extends StatefulWidget {
  const HudOverlay({super.key, required this.game});

  final GravityRocketGame game;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay>
    with SingleTickerProviderStateMixin {
  static const _chargeDuration = Duration(milliseconds: 1200);
  static const _minLaunchPower = 0.15;

  double _angleOffset = 0;
  late final AnimationController _powerController;

  @override
  void initState() {
    super.initState();
    _powerController = AnimationController(
      vsync: this,
      duration: _chargeDuration,
    );
  }

  @override
  void dispose() {
    _powerController.dispose();
    super.dispose();
  }

  /// Pixels of horizontal swipe needed to sweep the full -1..1 angle
  /// range. Deliberately not tied to screen width: the angle only moves
  /// relative to how far you swipe, never jumps to an absolute touch
  /// position, so it can never snap away from wherever it was left.
  static const double _dragPixelsForFullSweep = 320;
  static const double _dragSensitivity = 2.0 / _dragPixelsForFullSweep;

  void _adjustAim(double dxDelta) {
    setState(() {
      _angleOffset =
          (_angleOffset + dxDelta * _dragSensitivity).clamp(-1.0, 1.0);
    });

    final level = widget.game.level;
    final angleDeg =
        level.baseLaunchAngleDeg + _angleOffset * level.launchAngleRangeDeg;
    widget.game.rocket.setAim(angleDeg * math.pi / 180);
  }

  void _startCharging() {
    _powerController.forward(from: 0);
  }

  void _release() {
    final power = _powerController.value.clamp(_minLaunchPower, 1.0);
    _powerController.stop();
    widget.game.launch(power: power, angleOffset: _angleOffset);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    if (game.status != GameStatus.ready) {
      return SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IconButton.filled(
              icon: const Icon(Icons.pause),
              onPressed: () {
                game.pauseEngine();
                game.overlays.add('PauseMenu');
              },
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: (details) => _adjustAim(details.delta.dx),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Text(
                'Ziehen zum Zielen · Knopf halten zum Abschießen',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: SafeArea(
            child: GestureDetector(
              onTapDown: (_) => _startCharging(),
              onTapUp: (_) => _release(),
              onTapCancel: _release,
              child: AnimatedBuilder(
                animation: _powerController,
                builder: (context, child) {
                  final power = _powerController.value;
                  return Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.4),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            value: power,
                            strokeWidth: 4,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFFFFD24C),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.rocket_launch,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
