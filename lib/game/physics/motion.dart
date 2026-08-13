import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../levels/level.dart';

/// Computes a moving planet's position at elapsed flight time [t] seconds,
/// given its declared [basePosition] (`PlanetSpec.position`, used as the
/// oscillation center) and its [motion] descriptor. Returns [basePosition]
/// unchanged for `null` (static) motion. Pure function — no Flame/Flutter
/// dependency — so both the live game loop and any future trajectory
/// preview can reuse it.
Vector2 planetPositionAt({
  required Vector2 basePosition,
  required PlanetMotion? motion,
  required double t,
}) {
  switch (motion) {
    case null:
      return basePosition.clone();
    case OrbitMotion(:final center, :final radius, :final angularSpeedRadPerSec):
      final angle = angularSpeedRadPerSec * t;
      return Vector2(
        center.x + radius * math.cos(angle),
        center.y + radius * math.sin(angle),
      );
    case OscillateMotion(:final axis, :final amplitude, :final periodSeconds):
      final normalizedAxis = axis.length2 > 0 ? axis.normalized() : Vector2(1, 0);
      final phase = periodSeconds > 0 ? math.sin(2 * math.pi * t / periodSeconds) : 0.0;
      return basePosition + normalizedAxis * (amplitude * phase);
  }
}
