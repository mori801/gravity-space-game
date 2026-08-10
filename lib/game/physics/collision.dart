import 'package:vector_math/vector_math_64.dart';

/// Returns true if the line segment from [start] to [end] passes through,
/// touches, or starts inside the circle centered at [center] with the
/// given [radius].
///
/// Checking the whole frame-to-frame segment (rather than just the current
/// point) avoids "tunneling": a fast-moving rocket can otherwise skip past
/// a small planet entirely between two update ticks.
bool segmentIntersectsCircle({
  required Vector2 start,
  required Vector2 end,
  required Vector2 center,
  required double radius,
}) {
  final segment = end - start;
  final segmentLengthSquared = segment.length2;

  if (segmentLengthSquared == 0) {
    return (start - center).length <= radius;
  }

  final toCenter = center - start;
  final t = (toCenter.dot(segment) / segmentLengthSquared).clamp(0.0, 1.0);
  final closestPoint = start + segment * t;

  return (closestPoint - center).length <= radius;
}
