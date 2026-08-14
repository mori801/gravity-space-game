import 'package:vector_math/vector_math.dart';

import '../components/planet.dart';
import '../components/wind_zone.dart';
import 'gravity.dart';
import 'wind.dart';

/// Forecasts where the rocket would fly *if it launched right now* with
/// [startVelocity] from [startPosition], by Euler-integrating gravity (from
/// [planets]) plus wind (from [windZones]) exactly the way
/// `Rocket.update(dt)` integrates the real flight each frame: sum gravity
/// from every planet via [gravitationalAcceleration], add wind via
/// [totalWindAcceleration], apply the combined acceleration to velocity,
/// then apply velocity to position — same order of operations, same two
/// functions, reused unchanged rather than reimplemented.
///
/// This is a **pure forecast function**, not the real flight loop: it is
/// meant to be called every frame while the player is still aiming, to
/// drive a purely visual trajectory-preview line. It reads only the
/// current, live `position`/`mass`/`radius`/`acceleration` of each
/// [Planet]/[WindZone] passed in — a frozen snapshot of "if I launched
/// right now" — and never mutates [planets], [windZones], any object
/// inside them, or its own [startPosition]/[startVelocity] arguments.
/// Moving planets (`Planet.motion`) are deliberately *not* advanced during
/// the simulated steps; the preview assumes today's planet positions hold
/// steady for the whole forecast, matching a snapshot rather than
/// predicting future planet motion.
///
/// Returns the list of sampled world-space positions, starting with
/// [startPosition] itself, so the result always has length `steps + 1`
/// **when [maxPathLength] is left at its default of `null`** — the original,
/// unbounded behavior, preserved exactly for every existing caller/test.
///
/// [maxPathLength], when non-null, caps how far along the curve the forecast
/// is allowed to travel: the function still Euler-integrates step by step
/// with the same small [dt] (so the *shape* of the curve — how sharply
/// gravity bends it — is just as accurate as the uncapped path), but after
/// each step it adds the straight-line distance from the previous sampled
/// point to the new one to a running total, and stops **before** appending
/// a point that would push that running total past [maxPathLength]. This
/// caps the *arc length* of the returned polyline rather than the number of
/// steps, which matters because a fast (fully-charged) shot covers far more
/// ground per step than a slow one — capping by step count would reveal a
/// long, telling stretch of a fast shot's path while barely showing a slow
/// one's, whereas capping by path length shows a consistent, short amount
/// of curve for every launch speed. With a cap active, the returned list is
/// **no longer guaranteed to be `steps + 1` long**: it may be shorter, if
/// the path length budget is exhausted before `steps` iterations complete.
/// It is still always at least length 1 (just [startPosition]), and never
/// longer than `steps + 1`.
List<Vector2> simulateTrajectory({
  required Vector2 startPosition,
  required Vector2 startVelocity,
  required List<Planet> planets,
  List<WindZone> windZones = const [],
  double dt = 1 / 60,
  int steps = 180,
  double? maxPathLength,
}) {
  final gravitySources = [
    for (final planet in planets)
      GravitySource(position: planet.position, mass: planet.mass),
  ];
  final windSources = [
    for (final zone in windZones)
      WindZoneSource(
        position: zone.position,
        radius: zone.radius,
        acceleration: zone.acceleration,
      ),
  ];

  // Work on local clones so the caller's start position/velocity vectors
  // (which may be the live Vector2 instances the rocket itself uses) are
  // never mutated by this forecast.
  final position = startPosition.clone();
  final velocity = startVelocity.clone();

  final points = <Vector2>[position.clone()];
  var accumulatedLength = 0.0;
  for (var i = 0; i < steps; i++) {
    final acceleration = gravitationalAcceleration(
      objectPosition: position,
      sources: gravitySources,
    );
    acceleration.add(
      totalWindAcceleration(objectPosition: position, sources: windSources),
    );

    velocity.addScaled(acceleration, dt);
    final previousPosition = position.clone();
    position.addScaled(velocity, dt);

    if (maxPathLength != null) {
      accumulatedLength += position.distanceTo(previousPosition);
      if (accumulatedLength > maxPathLength) {
        break;
      }
    }

    points.add(position.clone());
  }

  return points;
}
