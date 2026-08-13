import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../levels/level.dart';
import '../physics/motion.dart';

/// A gravity well the rocket's trajectory is bent by. [mass] drives how
/// strongly it pulls (see `game/physics/gravity.dart`); it is kept
/// separate from the visual/collision [radius] so the two can be tuned
/// independently. If [motion] is set, the planet's position advances every
/// frame per `physics/motion.dart` — [Rocket] already reads planets' live
/// [position] each frame when building gravity sources, so no other
/// component needs to know a planet is moving.
///
/// [isRepulsor] controls only the visual treatment (see [render]) — it
/// should always be derived from `mass < 0` at the call site, since a
/// negative [mass] is what actually makes `gravitationalAcceleration()`
/// push the rocket away instead of pulling it in. A repulsor is still a
/// solid body: collision/hitbox behavior is unchanged and driven by the
/// same [radius] as any other planet.
class Planet extends CircleComponent {
  Planet({
    required Vector2 position,
    required double radius,
    required this.mass,
    required Color color,
    required this.isRepulsor,
    this.motion,
  })  : _basePosition = position.clone(),
        super(
          position: position,
          radius: radius,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

  final double mass;

  /// Whether this planet should be drawn as a repulsor (hollow ring)
  /// rather than a normal planet (filled disc). Purely visual — see
  /// [render]. Does not affect gravity math (driven by the sign of
  /// [mass]) or collision (driven by [radius]).
  final bool isRepulsor;

  /// If set, this planet moves every frame per `physics/motion.dart`
  /// instead of staying at its spawn position. Null means static.
  final PlanetMotion? motion;

  final Vector2 _basePosition;
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (motion == null) return;
    _elapsed += dt;
    position.setFrom(
      planetPositionAt(
          basePosition: _basePosition, motion: motion, t: _elapsed),
    );
  }

  /// Normal planets render exactly as [CircleComponent] would by default
  /// (a filled disc in [paint]'s color), so all pre-existing levels stay
  /// pixel-identical. Repulsors render as a hollow ring instead of a
  /// filled disc — a faint translucent fill plus a thick stroked ring at
  /// ~80% of [radius] — so they read as "field, not solid mass" and are
  /// visually distinct both from a normal planet (filled disc) and from a
  /// [NoFlyZone] (thin red pulsing ring): this uses the planet's own
  /// color (from [paint]), not red, and a much thicker stroke.
  @override
  void render(Canvas canvas) {
    final center = Offset(radius, radius);
    if (!isRepulsor) {
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final color = paint.color;
    canvas.drawCircle(center, radius, Paint()..color = color.withOpacity(0.12));
    canvas.drawCircle(
      center,
      radius * 0.8,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.22,
    );
  }
}
