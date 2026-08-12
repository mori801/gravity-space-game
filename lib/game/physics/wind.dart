import 'package:vector_math/vector_math.dart';

/// A read-only view of one wind zone's physics-relevant fields, kept
/// separate from [WindZoneSpec]/`WindZone` so this file stays pure Dart
/// with no dependency on `level.dart` or Flame — mirrors [GravitySource]
/// in gravity.dart.
class WindZoneSource {
  const WindZoneSource({
    required this.position,
    required this.radius,
    required this.acceleration,
  });

  final Vector2 position;
  final double radius;

  /// Pre-combined direction * magnitude, computed once when the zone's
  /// visual component is built (see `WindZone`), not recomputed on every
  /// physics tick.
  final Vector2 acceleration;
}

/// Sums the acceleration contributed by every zone [objectPosition] is
/// currently inside (boundary inclusive: `distance <= radius`) — zero
/// contribution from any zone it's outside of. Overlapping zones push
/// additively, mirroring how [gravitationalAcceleration] sums over
/// multiple planets.
///
/// Pure math with no dependency on Flame or Flutter, so it can be
/// unit-tested directly, same rationale as gravitationalAcceleration.
Vector2 totalWindAcceleration({
  required Vector2 objectPosition,
  required List<WindZoneSource> sources,
}) {
  final total = Vector2.zero();
  for (final source in sources) {
    final distance = (objectPosition - source.position).length;
    if (distance <= source.radius) {
      total.add(source.acceleration);
    }
  }
  return total;
}
