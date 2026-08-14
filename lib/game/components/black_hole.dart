import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// An extreme gravity well the rocket is funneled into and re-emerges
/// from elsewhere — portal-like, but distinct from a [WormholeEnd] (a
/// small passive ring with zero attraction of its own, threaded with
/// pixel-perfect aim). A black hole actively pulls the rocket in with a
/// very high [mass] (see [gravityRangeRadius]), so the puzzle is about
/// managing the approach and the resulting exit vector, not precise aim.
///
/// Capture/teleport itself is handled by [GravityRocketGame] (mirroring
/// how [WormholeEnd] is purely visual/positional and the teleport logic
/// lives there) — this component only renders and exposes [radius]/[mass]
/// for [Rocket] to build a `GravitySource` from each frame, the same way
/// it already does for sibling `Planet` components.
class BlackHole extends PositionComponent {
  BlackHole({
    required Vector2 position,
    required this.radius,
    required this.mass,
  }) : super(
         position: position,
         size: Vector2.all(radius * 2),
         anchor: Anchor.center,
       );

  /// Event-horizon / capture radius: the rocket's flight-path segment
  /// crossing this triggers the teleport (see
  /// `GravityRocketGame._checkBlackHoleCapture`). Deliberately small
  /// relative to [gravityRangeRadius] so "getting pulled in" reads as a
  /// gradual funnel the player aims into, not an instant snap the moment
  /// the hole is merely nearby.
  final double radius;

  /// Gravitational mass — see `GravitySource.mass` / `gravitationalAcceleration`
  /// in `physics/gravity.dart`. Always far above a normal planet's
  /// (roughly 2000-4800) so the pull is dramatic and readable from a distance.
  final double mass;

  static const Color _coreColor = Color(0xFF0D0620);
  static const Color _ringColor = Color(0xFFFF7A29);
  static const Color _glowColor = Color(0xFFFFE9C7);

  /// Same display-only heuristic as `Planet.gravityRangeRadius`, scaled up
  /// to reflect how much farther a black hole's pull is noticeable at —
  /// NOT a physics cutoff: `gravitationalAcceleration()` is an unbounded
  /// inverse-square law, so the rocket is always affected regardless of
  /// distance. Clamped so the ring never grows large enough to swallow the
  /// whole level view even at the highest masses used in `levels.dart`.
  double get gravityRangeRadius =>
      (radius + math.sqrt(mass) * 2.4).clamp(0.0, 420.0);

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(radius, radius);
    _renderGravityRangeGuide(canvas, center);
    _renderAccretionRing(canvas, center);
    canvas.drawCircle(center, radius, Paint()..color = _coreColor);
  }

  /// Faint dashed circle at [gravityRangeRadius], drawn before the core
  /// disc/ring so the solid body always paints on top with no z-fighting
  /// — the same technique `Planet._renderGravityRangeGuide` uses, reused
  /// here at a larger scale since a black hole's reach dwarfs a planet's.
  void _renderGravityRangeGuide(Canvas canvas, Offset center) {
    final rangeRadius = gravityRangeRadius;
    final rect = Rect.fromCircle(center: center, radius: rangeRadius);

    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = _ringColor.withOpacity(0.16);

    const dashCount = 36;
    const sweep = 2 * math.pi;
    final dashSweep = sweep / dashCount * 0.6;
    final gapSweep = sweep / dashCount - dashSweep;
    var angle = 0.0;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, angle, dashSweep, false, guidePaint);
      angle += dashSweep + gapSweep;
    }
  }

  /// A soft outer glow, a bright stroked ring, and a hot inner highlight —
  /// three layered passes standing in for an accretion disc, pulsing
  /// gently over time so the hole reads as "active" rather than a static
  /// hazard marker. Drawn before the core disc in [render] so the disc
  /// always sits on top with a clean edge.
  void _renderAccretionRing(Canvas canvas, Offset center) {
    final pulse = 0.5 + 0.5 * math.sin(_time * 1.6);

    canvas.drawCircle(
      center,
      radius * 1.35,
      Paint()
        ..color = _ringColor.withOpacity(0.14 + pulse * 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      center,
      radius * 1.05,
      Paint()
        ..color = _ringColor.withOpacity(0.75 + pulse * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.22,
    );
    canvas.drawCircle(
      center,
      radius * 0.95,
      Paint()
        ..color = _glowColor.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.08,
    );
  }
}
