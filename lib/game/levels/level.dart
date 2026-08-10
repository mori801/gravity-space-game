import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

/// A single planet placed in a level: its position, its gravitational
/// [mass], and its visual/collision [radius].
class PlanetSpec {
  const PlanetSpec({
    required this.position,
    required this.mass,
    required this.radius,
    required this.color,
  });

  final Vector2 position;
  final double mass;
  final double radius;
  final Color color;
}

/// Declarative description of one level: where the rocket starts, the
/// range of launch power/angle the player can choose from, the planets
/// that will pull on it, the target it must reach, and the play area
/// bounds that end the run if left.
class LevelData {
  const LevelData({
    required this.id,
    required this.name,
    required this.rocketStart,
    required this.baseLaunchAngleDeg,
    required this.launchAngleRangeDeg,
    required this.minLaunchSpeed,
    required this.maxLaunchSpeed,
    required this.planets,
    required this.targetPosition,
    required this.targetRadius,
    required this.playBounds,
  });

  final String id;
  final String name;

  final Vector2 rocketStart;

  /// Launch direction in degrees, measured the way Flutter measures
  /// angles on screen (0 = pointing right, -90 = straight up).
  final double baseLaunchAngleDeg;

  /// How far the player can steer away from [baseLaunchAngleDeg] in
  /// either direction, in degrees.
  final double launchAngleRangeDeg;

  final double minLaunchSpeed;
  final double maxLaunchSpeed;

  final List<PlanetSpec> planets;

  final Vector2 targetPosition;
  final double targetRadius;

  /// Play area; the rocket leaving these bounds ends the run in a loss.
  final Rect playBounds;
}
