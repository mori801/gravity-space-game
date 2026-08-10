import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../physics/gravity.dart';
import 'planet.dart';

/// The player-controlled rocket. Before launch it sits still at the level's
/// start position; after [launch] it is driven purely by the combined
/// gravity of every [Planet] in the same component tree, integrated with
/// semi-implicit Euler for stability.
class Rocket extends PositionComponent {
  Rocket({required Vector2 position, required double initialFacingAngleRad})
      : velocity = Vector2.zero(),
        _facingAngleRad = initialFacingAngleRad,
        super(
          position: position,
          size: Vector2.all(22),
          anchor: Anchor.center,
        );

  static const int _maxTrailLength = 40;
  static const double _maxUpdateDt = 1 / 30;

  final Vector2 velocity;
  bool launched = false;

  /// Position at the start of the current frame's update, before gravity
  /// was applied. Used by the main game class to run a segment-vs-circle
  /// crash check that can't be fooled by tunneling through a planet
  /// between two frames.
  final Vector2 previousPosition = Vector2.zero();

  double _facingAngleRad;
  final List<Vector2> _trail = [];

  final Paint _bodyPaint = Paint()..color = const Color(0xFFFFFFFF);
  final Paint _trailPaint = Paint()..color = const Color(0xFFFFFFFF);

  /// Sets the rocket in motion with the given initial velocity. Call
  /// [reset] first if the rocket has already flown this level once.
  void launch(Vector2 initialVelocity) {
    velocity.setFrom(initialVelocity);
    previousPosition.setFrom(position);
    launched = true;
    _trail.clear();
    if (velocity.length2 > 0) {
      _facingAngleRad = math.atan2(velocity.y, velocity.x);
    }
  }

  /// Returns the rocket to [startPosition], stationary and facing
  /// [facingAngleRad], ready to be launched again.
  void reset({required Vector2 startPosition, required double facingAngleRad}) {
    position.setFrom(startPosition);
    previousPosition.setFrom(startPosition);
    velocity.setZero();
    launched = false;
    _facingAngleRad = facingAngleRad;
    _trail.clear();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!launched) {
      return;
    }

    final clampedDt = dt > _maxUpdateDt ? _maxUpdateDt : dt;
    previousPosition.setFrom(position);

    final planets = parent?.children.query<Planet>() ?? const <Planet>[];
    final sources = [
      for (final planet in planets)
        GravitySource(position: planet.position, mass: planet.mass),
    ];

    final acceleration = gravitationalAcceleration(
      objectPosition: position,
      sources: sources,
    );

    velocity.addScaled(acceleration, clampedDt);
    position.addScaled(velocity, clampedDt);

    if (velocity.length2 > 0) {
      _facingAngleRad = math.atan2(velocity.y, velocity.x);
    }

    _trail.add(position.clone());
    if (_trail.length > _maxTrailLength) {
      _trail.removeAt(0);
    }
  }

  @override
  void render(Canvas canvas) {
    _renderTrail(canvas);
    _renderBody(canvas);
  }

  void _renderTrail(Canvas canvas) {
    for (var i = 0; i < _trail.length; i++) {
      final worldPoint = _trail[i];
      final localPoint = worldPoint - position;
      final progress = (i + 1) / _trail.length;
      _trailPaint.color = _trailPaint.color.withOpacity(progress * 0.35);
      canvas.drawCircle(
        Offset(localPoint.x, localPoint.y),
        1.5 + progress * 1.5,
        _trailPaint,
      );
    }
  }

  void _renderBody(Canvas canvas) {
    canvas.save();
    canvas.rotate(_facingAngleRad);

    final halfWidth = size.x / 2;
    final halfHeight = size.y / 2;
    final path = Path()
      ..moveTo(halfWidth, 0)
      ..lineTo(-halfWidth, -halfHeight * 0.6)
      ..lineTo(-halfWidth, halfHeight * 0.6)
      ..close();

    canvas.drawPath(path, _bodyPaint);
    canvas.restore();
  }
}
