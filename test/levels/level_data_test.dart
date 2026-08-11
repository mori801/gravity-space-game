import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';

void main() {
  group('kLevels', () {
    test('has unique ids', () {
      final ids = kLevels.map((level) => level.id).toSet();
      expect(ids.length, kLevels.length);
    });

    test('every planet has positive mass and radius', () {
      for (final level in kLevels) {
        for (final planet in level.planets) {
          expect(planet.mass, greaterThan(0), reason: level.id);
          expect(planet.radius, greaterThan(0), reason: level.id);
        }
      }
    });

    test('rocket start and target are within play bounds', () {
      for (final level in kLevels) {
        expect(
          level.playBounds
              .contains(Offset(level.rocketStart.x, level.rocketStart.y)),
          isTrue,
          reason: level.id,
        );
        expect(
          level.playBounds.contains(
            Offset(level.targetPosition.x, level.targetPosition.y),
          ),
          isTrue,
          reason: level.id,
        );
      }
    });

    test('rocket does not start overlapping a planet', () {
      for (final level in kLevels) {
        for (final planet in level.planets) {
          final distance = (level.rocketStart - planet.position).length;
          expect(distance, greaterThan(planet.radius), reason: level.id);
        }
      }
    });

    test('launch speed range is valid', () {
      for (final level in kLevels) {
        expect(level.minLaunchSpeed, greaterThan(0), reason: level.id);
        expect(
          level.maxLaunchSpeed,
          greaterThanOrEqualTo(level.minLaunchSpeed),
          reason: level.id,
        );
      }
    });
  });
}
