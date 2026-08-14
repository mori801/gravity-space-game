import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/components/planet.dart';
import 'package:gravity_rocket_launcher/game/components/wind_zone.dart';
import 'package:gravity_rocket_launcher/game/physics/trajectory.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('simulateTrajectory', () {
    test('with no planets and no wind, matches straight-line kinematics', () {
      final start = Vector2(10, -5);
      final velocity = Vector2(120, -40);
      const dt = 1 / 60;
      const steps = 30;

      final points = simulateTrajectory(
        startPosition: start,
        startVelocity: velocity,
        planets: const [],
        dt: dt,
        steps: steps,
      );

      // steps + 1 samples: the start position plus one per integrated step.
      expect(points.length, steps + 1);

      for (var i = 0; i <= steps; i++) {
        final expected = start + velocity * (dt * i);
        // vector_math's Vector2 is float32-backed, so a handful of
        // accumulated additions carries a little rounding noise above a
        // float64-scale tolerance (matches the tolerance convention used
        // in gravity_test.dart).
        expect((points[i] - expected).length, lessThan(1e-3));
      }
    });

    test('a single attracting planet bends the trajectory toward it', () {
      // Rocket starts at the origin and launches straight along +x, with
      // an attracting planet placed directly "below" (in +y, screen-space
      // down) the starting point. Gravity always points from the object
      // toward the planet for a positive mass (see gravity.dart), so the
      // acceleration here has a positive y-component throughout the
      // flight, and y should end up further from 0 than the perfectly
      // straight (no-gravity) path would put it — i.e. the path curves
      // toward the planet instead of staying flat.
      final planet = Planet(
        position: Vector2(400, 200),
        radius: 20,
        mass: 800,
        color: const Color(0xFF0000FF),
        isRepulsor: false,
      );

      final points = simulateTrajectory(
        startPosition: Vector2(0, 0),
        startVelocity: Vector2(150, 0),
        planets: [planet],
        dt: 1 / 60,
        steps: 90,
      );

      // Straight-line (no gravity) y would stay exactly 0 the whole way;
      // any positive deflection here is purely the planet's pull.
      expect(points.last.y, greaterThan(1.0));

      // The deflection should grow over the course of the flight (a
      // monotonic bend toward the planet), not just appear as noise at
      // one sample.
      final midY = points[points.length ~/ 2].y;
      expect(midY, greaterThan(0.0));
      expect(points.last.y, greaterThan(midY));
    });

    test('does not mutate the planets or wind zones passed in', () {
      final planet = Planet(
        position: Vector2(300, 150),
        radius: 15,
        mass: 600,
        color: const Color(0xFFFF0000),
        isRepulsor: false,
      );
      final windZone = WindZone(
        position: Vector2(-100, 50),
        radius: 80,
        forceDirectionRad: 0.5,
        forceMagnitude: 40,
      );

      final planetPositionBefore = planet.position.clone();
      final planetMassBefore = planet.mass;
      final windPositionBefore = windZone.position.clone();
      final windAccelerationBefore = windZone.acceleration.clone();

      final startPosition = Vector2(0, 0);
      final startVelocity = Vector2(80, -60);
      final startPositionBefore = startPosition.clone();
      final startVelocityBefore = startVelocity.clone();

      simulateTrajectory(
        startPosition: startPosition,
        startVelocity: startVelocity,
        planets: [planet],
        windZones: [windZone],
        dt: 1 / 60,
        steps: 45,
      );

      expect(planet.position, planetPositionBefore);
      expect(planet.mass, planetMassBefore);
      expect(windZone.position, windPositionBefore);
      expect(windZone.acceleration, windAccelerationBefore);
      expect(startPosition, startPositionBefore);
      expect(startVelocity, startVelocityBefore);
    });

    test('result always has steps + 1 samples, starting at startPosition', () {
      final start = Vector2(5, 5);
      final points = simulateTrajectory(
        startPosition: start,
        startVelocity: Vector2(10, 10),
        planets: const [],
        steps: 12,
      );

      expect(points.length, 13);
      expect(points.first, start);
    });

    test('maxPathLength caps the straight-line polyline length near, but not '
        'over, the budget', () {
      // No planets/wind, so each step covers exactly speed * dt of path
      // length, making the total easy to reason about exactly.
      const dt = 1 / 60;
      const speed = 150.0;
      const maxPathLength = 200.0;

      final points = simulateTrajectory(
        startPosition: Vector2(0, 0),
        startVelocity: Vector2(speed, 0),
        planets: const [],
        dt: dt,
        steps: 1000,
        maxPathLength: maxPathLength,
      );

      var totalLength = 0.0;
      for (var i = 1; i < points.length; i++) {
        totalLength += points[i].distanceTo(points[i - 1]);
      }

      // Never exceeds the budget...
      expect(totalLength, lessThanOrEqualTo(maxPathLength));
      // ...but also didn't stop way too early: undershoot is bounded by
      // a single step's worth of distance (speed * dt), since the loop
      // only ever stops the first time a step would push it over budget.
      final perStepLength = speed * dt;
      expect(totalLength, greaterThan(maxPathLength - perStepLength));
    });

    test(
      'maxPathLength: null (default) preserves the old unbounded behavior',
      () {
        final start = Vector2(1, 2);
        final points = simulateTrajectory(
          startPosition: start,
          startVelocity: Vector2(300, -300),
          planets: const [],
          steps: 20,
        );

        // Same invariant as the uncapped test above: steps + 1 samples,
        // regardless of how far/fast the shot travels.
        expect(points.length, 21);
        expect(points.first, start);
      },
    );

    test('a capped run returns strictly fewer points than the same uncapped '
        'run with a high step count and a fast start velocity', () {
      const dt = 1 / 60;
      const steps = 500;
      final startPosition = Vector2(0, 0);
      final startVelocity = Vector2(1000, 0);

      final uncapped = simulateTrajectory(
        startPosition: startPosition,
        startVelocity: startVelocity,
        planets: const [],
        dt: dt,
        steps: steps,
      );

      final capped = simulateTrajectory(
        startPosition: startPosition,
        startVelocity: startVelocity,
        planets: const [],
        dt: dt,
        steps: steps,
        maxPathLength: 200,
      );

      expect(capped.length, lessThan(uncapped.length));
      expect(uncapped.length, steps + 1);
    });
  });
}
