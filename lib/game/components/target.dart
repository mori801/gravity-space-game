import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// The destination the rocket must reach (its center within [radius]) to
/// win the level. Drawn as a ring so it reads clearly against planets.
class Target extends CircleComponent {
  Target({
    required Vector2 position,
    required double radius,
  }) : super(
          position: position,
          radius: radius,
          anchor: Anchor.center,
          paint: Paint()
            ..color = const Color(0xFF7CFF6B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
}
