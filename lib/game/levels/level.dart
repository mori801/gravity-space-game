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

/// An extreme gravity well the rocket can be funneled into and re-emerge
/// from elsewhere — portal-like, but distinct from [WormholeSpec] in two
/// ways: it actively pulls the rocket in with a very high [mass] (several
/// times a normal planet's, so the approach itself is the puzzle, not a
/// pixel-perfect thread), and capture only requires reaching [radius] (the
/// event horizon) rather than precisely overlapping a specific spot.
///
/// [exitVelocityScale] (default 1.0, i.e. speed unchanged) is a multiplier
/// applied to the rocket's speed on exit, direction preserved — see the
/// design note on `GravityRocketGame._checkBlackHoleCapture` for why the
/// exit deliberately carries the incoming velocity forward instead of
/// resetting it or firing along a fixed direction.
class BlackHoleSpec {
  const BlackHoleSpec({
    required this.position,
    required this.radius,
    required this.mass,
    required this.exitPosition,
    this.exitVelocityScale = 1.0,
  });

  final Vector2 position;

  /// Event-horizon / capture radius. Kept small (tens of pixels) relative
  /// to [mass]'s reach so "getting pulled in" reads as a gradual funnel
  /// the player must aim into, not an instant snap the moment the hole is
  /// merely nearby.
  final double radius;

  /// Gravitational mass — see `physics/gravity.dart`. Always well above a
  /// normal planet's (2000-3400) so the pull is dramatic and readable from
  /// a distance; always positive (a black hole always attracts, never
  /// repels).
  final double mass;

  /// Where the rocket re-emerges after capture.
  final Vector2 exitPosition;

  /// Multiplier applied to the rocket's speed on exit (direction
  /// unchanged). 1.0 (the default) hands the exact incoming speed back;
  /// level authors can raise or lower it for a slingshot-boost or a
  /// slow-crawl exit.
  final double exitVelocityScale;
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
    this.ordered = false,
    this.blackHoles = const <BlackHoleSpec>[],
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

  /// Every target the rocket must reach to win: the primary target
  /// followed by [additionalTargets]. When [ordered] is false (the
  /// default), these may be hit in any order. When [ordered] is true,
  /// this list's order IS the required visiting order — index 0 first,
  /// then index 1, and so on.
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

  /// When true, [targets] must be hit in list order: the primary target
  /// (targetPosition/targetRadius) first, then additionalTargets in the
  /// order they're declared. Hitting a later target before all earlier
  /// ones are hit simply doesn't register yet — no penalty, no loss, it
  /// just isn't counted until its turn comes. Defaults to false, so every
  /// existing level (where targets may be hit in any order) is completely
  /// unaffected.
  ///
  /// IMPORTANT for level authors: the required sequence is exactly the
  /// [targets] list order — index 0 is the primary target, index 1 is
  /// additionalTargets[0], index 2 is additionalTargets[1], etc.
  final bool ordered;

  /// Black holes in this level — see [BlackHoleSpec]. Optional — defaults
  /// to none, so every existing level is completely unaffected.
  final List<BlackHoleSpec> blackHoles;
}
