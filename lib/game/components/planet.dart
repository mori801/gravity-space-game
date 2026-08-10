import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A gravity well the rocket's trajectory is bent by. [mass] drives how
/// strongly it pulls (see `game/physics/gravity.dart`); it is kept
/// separate from the visual/collision [radius] so the two can be tuned
/// independently.
class Planet extends CircleComponent {
  Planet({
    required Vector2 position,
    required double radius,
    required this.mass,
    required Color color,
  }) : super(
          position: position,
          radius: radius,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

  final double mass;
}
