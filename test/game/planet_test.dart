import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/components/planet.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

double _expectedGravityRangeRadius({
  required double radius,
  required double mass,
}) {
  return (radius + math.sqrt(mass.abs()) * 2.0).clamp(0.0, 180.0);
}

void main() {
  group('Planet.gravityRangeRadius', () {
    test('matches the derived formula for a typical planet', () {
      const radius = 40.0;
      const mass = 1800.0;
      final planet = Planet(
        position: Vector2(0, 0),
        radius: radius,
        mass: mass,
        color: Colors.blue,
        isRepulsor: false,
      );

      expect(
        planet.gravityRangeRadius,
        _expectedGravityRangeRadius(radius: radius, mass: mass),
      );
    });

    test('matches the derived formula for a larger, heavier planet', () {
      const radius = 60.0;
      const mass = 3400.0;
      final planet = Planet(
        position: Vector2(0, 0),
        radius: radius,
        mass: mass,
        color: Colors.orange,
        isRepulsor: false,
      );

      // With this mass/radius pair the formula does not naturally exceed
      // the 180 cap, so this test only verifies the unclamped formula;
      // the clamp path itself is exercised separately below.
      final expected = _expectedGravityRangeRadius(radius: radius, mass: mass);
      expect(expected, lessThan(180.0));
      expect(planet.gravityRangeRadius, expected);
    });

    test('matches the derived formula for a mid-range planet', () {
      const radius = 50.0;
      const mass = 2600.0;
      final planet = Planet(
        position: Vector2(0, 0),
        radius: radius,
        mass: mass,
        color: Colors.green,
        isRepulsor: false,
      );

      expect(
        planet.gravityRangeRadius,
        _expectedGravityRangeRadius(radius: radius, mass: mass),
      );
    });

    test('clamps to 180 for a very large synthetic mass', () {
      const radius = 60.0;
      const mass = 20000.0;
      final planet = Planet(
        position: Vector2(0, 0),
        radius: radius,
        mass: mass,
        color: Colors.red,
        isRepulsor: false,
      );

      // Sanity check the unclamped value really would exceed 180, so this
      // test is actually exercising the clamp and not just coincidentally
      // landing at 180.
      final unclamped = radius + math.sqrt(mass.abs()) * 2.0;
      expect(unclamped, greaterThan(180.0));

      expect(planet.gravityRangeRadius, 180.0);
      expect(
        planet.gravityRangeRadius,
        _expectedGravityRangeRadius(radius: radius, mass: mass),
      );
    });

    test(
        'uses mass magnitude, so a repulsor matches its positive '
        'counterpart', () {
      const radius = 50.0;
      const positiveMass = 2600.0;
      const negativeMass = -2600.0;

      final normalPlanet = Planet(
        position: Vector2(0, 0),
        radius: radius,
        mass: positiveMass,
        color: Colors.purple,
        isRepulsor: false,
      );
      final repulsorPlanet = Planet(
        position: Vector2(0, 0),
        radius: radius,
        mass: negativeMass,
        color: Colors.purple,
        isRepulsor: true,
      );

      expect(
        repulsorPlanet.gravityRangeRadius,
        normalPlanet.gravityRangeRadius,
      );
      expect(
        repulsorPlanet.gravityRangeRadius,
        _expectedGravityRangeRadius(radius: radius, mass: positiveMass),
      );
    });
  });
}
