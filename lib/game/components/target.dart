import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// The destination the rocket must reach (its center within [radius]) to
/// win the level. Rendered in two passes, mirroring [Planet]'s repulsor
/// treatment: a faint translucent fill so the circle reads as a solid
/// target area, plus the original stroked ring drawn on top so it still
/// reads clearly against planets. Purely visual — [radius] and hit
/// detection (in `GravityRocketGame`) are unaffected by this render logic.
class Target extends CircleComponent {
  Target({required Vector2 position, required double radius})
    : super(
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
  static const _activeFill = Color(0x337CFF6B);
  static const _dimmedFill = Color(0x1A7CFF6B);

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
    final fillColor = isActive ? _activeFill : _dimmedFill;
    canvas.drawCircle(
      Offset(radius, radius),
      radius,
      Paint()..color = fillColor,
    );
    paint.color = isActive ? _activeColor : _dimmedColor;
    super.render(canvas); // existing stroke ring, unchanged
  }
}
