import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A static circular hazard: entering it (its flight-path segment
/// crossing the circle) ends the run immediately, same as crashing into
/// a planet — but unlike a [Planet], it exerts no gravity, purely an
/// exclusion zone the player must route around. The pulsing red
/// stripe/ring look is deliberately different from a planet's solid
/// filled circle so it reads as "boundary/hazard" rather than "mass".
class NoFlyZone extends PositionComponent {
  NoFlyZone({required Vector2 position, required double radius})
      : super(
          position: position,
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
        );

  /// Collision radius, derived from [size] (set to `radius * 2` in the
  /// constructor) so callers can check `zone.radius` the same way they'd
  /// check `Planet.radius`, without this component storing the value
  /// twice.
  double get radius => size.x / 2;

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final pulse = 0.5 + 0.5 * math.sin(_time * 2);

    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = const Color(0xFFFF4C4C).withOpacity(0.12 + pulse * 0.08),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = const Color(0xFFFF4C4C).withOpacity(0.55 + pulse * 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}
