import 'package:vector_math/vector_math_64.dart';

/// Arcade-scale gravitational constant. Not physically accurate — tuned so
/// planet masses in the 100s-1000s produce visually satisfying curves at
/// the speeds/distances used by the levels in `levels.dart`.
const double kGravitationalConstant = 4000.0;

/// Minimum distance used when computing gravity, so a planet's pull never
/// spikes toward infinity as the rocket approaches its center.
const double kSofteningDistance = 8.0;

/// A point mass that exerts gravitational pull, e.g. a planet.
class GravitySource {
  const GravitySource({required this.position, required this.mass});

  final Vector2 position;
  final double mass;
}

/// Computes the net gravitational acceleration acting on an object at
/// [objectPosition] from all [sources], using an inverse-square falloff.
///
/// This is pure math with no dependency on Flame or Flutter, so it can be
/// unit-tested directly and reused by both the live game loop and any
/// trajectory-preview code.
Vector2 gravitationalAcceleration({
  required Vector2 objectPosition,
  required List<GravitySource> sources,
  double g = kGravitationalConstant,
  double minDistance = kSofteningDistance,
}) {
  final total = Vector2.zero();
  for (final source in sources) {
    final delta = source.position - objectPosition;
    final distance = delta.length;
    if (distance == 0) {
      continue;
    }
    final clampedDistance = distance < minDistance ? minDistance : distance;
    final direction = delta / distance;
    final magnitude = g * source.mass / (clampedDistance * clampedDistance);
    total.addScaled(direction, magnitude);
  }
  return total;
}
