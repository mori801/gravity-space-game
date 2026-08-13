import 'dart:ui';

import 'package:vector_math/vector_math.dart';

/// How a planet's position changes over time. Pure data — the actual
/// position computation lives in `physics/motion.dart` so it can be
/// unit-tested without depending on Flame or a running game loop.
sealed class PlanetMotion {
  const PlanetMotion();
}

/// Circular orbit around [center] at fixed [radius], moving at
/// [angularSpeedRadPerSec] radians/second (positive = counterclockwise in
/// screen space, where +y is down).
class OrbitMotion extends PlanetMotion {
  const OrbitMotion({
    required this.center,
    required this.radius,
    required this.angularSpeedRadPerSec,
  });

  final Vector2 center;
  final double radius;
  final double angularSpeedRadPerSec;
}

/// Linear back-and-forth motion along [axis] (normalized internally),
/// centered on the planet's declared [PlanetSpec.position], swinging
/// [amplitude] to either side with period [periodSeconds].
class OscillateMotion extends PlanetMotion {
  const OscillateMotion({
    required this.axis,
    required this.amplitude,
    required this.periodSeconds,
  });

  final Vector2 axis;
  final double amplitude;
  final double periodSeconds;
}

/// A single planet placed in a level: its position, its gravitational
/// [mass], and its visual/collision [radius].
class PlanetSpec {
  const PlanetSpec({
    required this.position,
    required this.mass,
    required this.radius,
    required this.color,
    this.motion,
  });

  final Vector2 position;
  final double mass;
  final double radius;
  final Color color;

  /// If set, the planet moves every frame per `physics/motion.dart`
  /// instead of staying at [position]. Null means static (today's
  /// behavior for every existing level).
  final PlanetMotion? motion;
}

/// One point the rocket must reach to win. See [LevelData.targets].
class TargetSpec {
  const TargetSpec({required this.position, required this.radius});

  final Vector2 position;
  final double radius;
}

/// A linked teleport pair: entering the radius of either [a] or [b]
/// teleports the rocket to the other end.
class WormholeSpec {
  const WormholeSpec({required this.a, required this.b, required this.radius});

  final Vector2 a;
  final Vector2 b;
  final double radius;
}

/// A static circular no-fly zone placed in a level: purely an exclusion
/// zone (no gravity, no level-configurable visual — see [NoFlyZone]) that
/// ends the run if the rocket's flight path crosses it.
class NoFlyZoneSpec {
  const NoFlyZoneSpec({required this.position, required this.radius});

  final Vector2 position;
  final double radius;
}

/// A circular zone that applies a constant directional push to the
/// rocket while its position is inside it (e.g. solar wind, a thruster
/// corridor) — purely additive to gravity, unlike [NoFlyZoneSpec] which
/// ends the run. Exerts no force outside [radius] of [position].
class WindZoneSpec {
  const WindZoneSpec({
    required this.position,
    required this.radius,
    required this.forceDirectionDeg,
    required this.forceMagnitude,
  });

  final Vector2 position;
  final double radius;

  /// Direction the wind pushes, in the same screen-angle convention as
  /// [LevelData.baseLaunchAngleDeg] (0 = right, -90 = up, degrees).
  final double forceDirectionDeg;

  /// Constant acceleration magnitude applied while inside [radius], same
  /// arcade-scale units as [gravitationalAcceleration]'s return value
  /// (see physics/gravity.dart) — there's no separate rocket "mass" to
  /// divide a force by in this engine.
  final double forceMagnitude;
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
    this.additionalTargets = const [],
    this.wormholes = const [],
    this.noFlyZones = const <NoFlyZoneSpec>[],
    this.maxShots,
    this.windZones = const <WindZoneSpec>[],
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

  /// Targets beyond the primary [targetPosition]/[targetRadius]. See
  /// [targets] for the combined list; empty for every level that only
  /// has one target.
  final List<TargetSpec> additionalTargets;

  /// Linked teleport pairs in this level. Empty for every level that
  /// doesn't use the mechanic.
  final List<WormholeSpec> wormholes;

  /// Every target the rocket must reach to win, in no particular order:
  /// the primary target followed by [additionalTargets].
  List<TargetSpec> get targets => [
        TargetSpec(position: targetPosition, radius: targetRadius),
        ...additionalTargets,
      ];

  /// Static circular exclusion zones; the rocket's flight path crossing
  /// one ends the run in a loss. Optional — defaults to none, so existing
  /// levels don't need to declare it.
  final List<NoFlyZoneSpec> noFlyZones;

  /// Maximum number of real launches allowed on this level before the run
  /// ends in [LoseReason.outOfFuel] instead of permitting another attempt.
  /// `null` (the default) means unlimited, so every existing level is
  /// unaffected.
  final int? maxShots;

  /// Wind zones applying a constant push to the rocket while inside them.
  /// Optional — defaults to none, so existing levels don't need to
  /// declare it.
  final List<WindZoneSpec> windZones;
}
