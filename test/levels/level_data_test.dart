import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/levels/level.dart';
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

    test('every wormhole pair has positive radius and both ends in bounds', () {
      for (final level in kLevels) {
        for (final wormhole in level.wormholes) {
          expect(wormhole.radius, greaterThan(0), reason: level.id);
          expect(
            level.playBounds.contains(Offset(wormhole.a.x, wormhole.a.y)),
            isTrue,
            reason: level.id,
          );
          expect(
            level.playBounds.contains(Offset(wormhole.b.x, wormhole.b.y)),
            isTrue,
            reason: level.id,
          );
        }
      }
    });

    test('targets getter combines the primary target with additionalTargets', () {
      for (final level in kLevels) {
        expect(
          level.targets.length,
          1 + level.additionalTargets.length,
          reason: level.id,
        );
        expect(level.targets.first.position, level.targetPosition, reason: level.id);
      }
    });

    test('every planet motion has sane (positive) parameters', () {
      for (final level in kLevels) {
        for (final planet in level.planets) {
          final motion = planet.motion;
          if (motion is OrbitMotion) {
            expect(motion.radius, greaterThan(0), reason: level.id);
          } else if (motion is OscillateMotion) {
            expect(motion.amplitude, greaterThan(0), reason: level.id);
            expect(motion.periodSeconds, greaterThan(0), reason: level.id);
          }
        }
      }
    });

    test('at least one level uses each new mechanic', () {
      expect(
        kLevels.any((l) => l.planets.any((p) => p.motion is OrbitMotion)),
        isTrue,
        reason: 'expected at least one level with a moving planet',
      );
      expect(
        kLevels.any((l) => l.wormholes.isNotEmpty),
        isTrue,
        reason: 'expected at least one level with a wormhole',
      );
      expect(
        kLevels.any((l) => l.additionalTargets.isNotEmpty),
        isTrue,
        reason: 'expected at least one multi-target level',
      );
    });
  });
}
