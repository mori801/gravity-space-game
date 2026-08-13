import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A visual, physics-relevant zone that pushes the rocket while it's
/// inside — the opposite of a [NoFlyZone]'s "avoid this" framing, so it's
/// deliberately rendered in a distinct color (teal, not red) with a
/// directional "flow" cue instead of a non-directional pulse, so a
/// player can't mistake one hazard type for the other at a glance.
class WindZone extends PositionComponent {
  WindZone({
    required Vector2 position,
    required double radius,
    required double forceDirectionRad,
    required double forceMagnitude,
  })  : acceleration = Vector2(
          math.cos(forceDirectionRad),
          math.sin(forceDirectionRad),
        )..scale(forceMagnitude),
        super(
          position: position,
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
        );

  /// Collision/effect radius, derived from [size] the same way
  /// [NoFlyZone.radius] is, so callers check it identically.
  double get radius => size.x / 2;

  /// Pre-combined direction * magnitude, computed once in the
  /// constructor — read by [GravityRocketGame]/[Rocket] to build a
  /// [WindZoneSource] each frame without recomputing trig.
  final Vector2 acceleration;

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    const color = Color(0xFF4FE0FF);

    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = color.withOpacity(0.10),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = color.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Three short streak lines flowing along the push direction, looping
    // over time, so the zone visually reads as "flow this way" rather
    // than NoFlyZone's non-directional pulse.
    final dir = acceleration.length2 > 0
        ? acceleration.normalized()
        : Vector2(1, 0);
    final dirOffset = Offset(dir.x, dir.y);
    final perp = Offset(-dirOffset.dy, dirOffset.dx);
    const streakLength = 22.0;
    const spacing = 34.0;
    for (var i = 0; i < 3; i++) {
      final phase = (_time * 60 + i * spacing) % (radius * 2) - radius;
      final center = dirOffset * phase + perp * (i - 1) * 18;
      final start = center - dirOffset * (streakLength / 2);
      final end = center + dirOffset * (streakLength / 2);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = color.withOpacity(0.5)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }
}
