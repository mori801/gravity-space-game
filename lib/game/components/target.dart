import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// The destination the rocket must reach (its center within [radius]) to
/// win the level. Drawn as a ring so it reads clearly against planets.
class Target extends CircleComponent {
  Target({
    required Vector2 position,
    required double radius,
  }) : super(
          position: position,
          radius: radius,
          anchor: Anchor.center,
          paint: Paint()
            ..color = _activeColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );

  static const _activeColor = Color(0xFF7CFF6B);
  static const _dimmedColor = Color(0x557CFF6B);

  /// Whether this target is currently reachable in sequence. Always true
  /// for non-ordered levels (the default) — only [GravityRocketGame] sets
  /// this false, and only for ordered levels' not-yet-required targets, to
  /// dim them and signal "not yet". Purely visual; doesn't affect hit
  /// detection (game-loop code checks distance to the target regardless of
  /// this flag — see GravityRocketGame._earlierTargetsHit for the actual
  /// gating logic).
  bool isActive = true;

  @override
  void render(Canvas canvas) {
    paint.color = isActive ? _activeColor : _dimmedColor;
    super.render(canvas);
  }
}
