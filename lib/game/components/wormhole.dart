import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../levels/level.dart';

/// One end of a linked wormhole pair. Purely visual/positional — the
/// teleport logic lives in [GravityRocketGame], which already owns the
/// per-tick collision checks for planets and bounds.
class WormholeEnd extends CircleComponent {
  WormholeEnd({required Vector2 position, required double radius})
      : super(
          position: position,
          radius: radius,
          anchor: Anchor.center,
          paint: Paint()
            ..color = const Color(0xFFB06CFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5,
        );
}

/// The two [WormholeEnd] components built from one [WormholeSpec]. Kept as
/// a plain holder (not a single component) so each end can be added to the
/// world and queried independently by position.
class WormholePair {
  WormholePair(WormholeSpec spec)
      : endA = WormholeEnd(position: spec.a, radius: spec.radius),
        endB = WormholeEnd(position: spec.b, radius: spec.radius);

  final WormholeEnd endA;
  final WormholeEnd endB;
}
