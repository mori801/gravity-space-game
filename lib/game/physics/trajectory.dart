import 'package:vector_math/vector_math.dart';

import '../components/black_hole.dart';
import '../components/planet.dart';
import '../components/wind_zone.dart';
import 'gravity.dart';
import 'wind.dart';

/// Forecasts where the rocket would fly *if it launched right now* with
/// [startVelocity] from [startPosition], by Euler-integrating gravity (from
/// [planets] and [blackHoles]) plus wind (from [windZones]) exactly the way
/// `Rocket.update(dt)` integrates the real flight each frame: sum gravity
/// from every planet and black hole via [gravitationalAcceleration], add
/// wind via [totalWindAcceleration], apply the combined acceleration to
/// velocity, then apply velocity to position — same order of operations,
/// same two functions, reused unchanged rather than reimplemented. Note
/// this forecast does NOT simulate black hole capture/teleport (that lives
/// in `GravityRocketGame`), so a preview line that dashes straight through
/// a black hole is showing the *un-captured* path — a deliberate
/// simplification, not a bug: the point is to show the player how strongly
/// the hole bends the approach, not to predict the exit.
///
/// This is a **pure forecast function**, not the real flight loop: it is
/// meant to be called every frame while the player is still aiming, to
/// drive a purely visual trajectory-preview line. It reads only the
/// current, live `position`/`mass`/`radius`/`acceleration` of each
/// [Planet]/[BlackHole]/[WindZone] passed in — a frozen snapshot of "if I
/// launched right now" — and never mutates [planets], [blackHoles],
/// [windZones], any object inside them, or its own
/// [startPosition]/[startVelocity] arguments.
/// Moving planets (`Planet.motion`) are deliberately *not* advanced during
/// the simulated steps; the preview assumes today's planet positions hold
/// steady for the whole forecast, matching a snapshot rather than
/// predicting future planet motion.
///
/// Returns the list of sampled world-space positions, starting with
/// [startPosition] itself, so the result always has length `steps + 1`.
List<Vector2> simulateTrajectory({
  required Vector2 startPosition,
  required Vector2 startVelocity,
  required List<Planet> planets,
  List<BlackHole> blackHoles = const [],
  List<WindZone> windZones = const [],
  double dt = 1 / 60,
  int steps = 180,
}) {
  final gravitySources = [
    for (final planet in planets)
      GravitySource(position: planet.position, mass: planet.mass),
    // Same treatment as planets — a black hole is just an unusually
    // high-mass GravitySource, see Rocket.update for the live-flight
    // equivalent of this.
    for (final hole in blackHoles)
      GravitySource(position: hole.position, mass: hole.mass),
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
  for (var i = 0; i < steps; i++) {
    final acceleration = gravitationalAcceleration(
      objectPosition: position,
      sources: gravitySources,
    );
    acceleration.add(
      totalWindAcceleration(objectPosition: position, sources: windSources),
    );

    velocity.addScaled(acceleration, dt);
    position.addScaled(velocity, dt);

    points.add(position.clone());
  }

  return points;
}
