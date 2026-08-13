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
class Planet extends CircleComponent {
  Planet({
    required Vector2 position,
    required double radius,
    required this.mass,
    required Color color,
    this.motion,
  })  : _basePosition = position.clone(),
        super(
          position: position,
          radius: radius,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

  final double mass;
  final PlanetMotion? motion;

  final Vector2 _basePosition;
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (motion == null) return;
    _elapsed += dt;
    position.setFrom(
      planetPositionAt(basePosition: _basePosition, motion: motion, t: _elapsed),
    );
  }
}
