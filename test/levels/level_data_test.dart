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

    test(
      'no-fly zones have positive radius and never contain the rocket '
      'start or target',
      () {
        for (final level in kLevels) {
          for (final zone in level.noFlyZones) {
            expect(zone.radius, greaterThan(0), reason: level.id);

            final startDistance = (level.rocketStart - zone.position).length;
            expect(startDistance, greaterThan(zone.radius), reason: level.id);

            final targetDistance =
                (level.targetPosition - zone.position).length;
            expect(
              targetDistance,
              greaterThan(zone.radius),
              reason: level.id,
            );
          }
        }
      },
    );

    test('maxShots, if set, is at least 1', () {
      for (final level in kLevels) {
        if (level.maxShots != null) {
          expect(level.maxShots, greaterThanOrEqualTo(1), reason: level.id);
        }
      }
    });

    test('tier 6 levels all have no-fly zones', () {
      final tier6Ids = List.generate(8, (i) => 'level-${29 + i}');
      for (final id in tier6Ids) {
        final level = kLevels.firstWhere(
          (l) => l.id == id,
          orElse: () => throw StateError('missing $id'),
        );
        expect(level.noFlyZones, isNotEmpty, reason: id);
      }
    });

    test('kLevels has 52 levels total', () {
      expect(kLevels.length, 52);
    });

    test('tier 7 levels combine no-fly zones with a maxShots budget', () {
      final tier7Ids = List.generate(8, (i) => 'level-${37 + i}');
      for (final id in tier7Ids) {
        final level = kLevels.firstWhere(
          (l) => l.id == id,
          orElse: () => throw StateError('missing $id'),
        );
        expect(level.noFlyZones, isNotEmpty, reason: id);
        expect(level.maxShots, isNotNull, reason: id);
      }
    });

    test('exactly the expected levels have a maxShots budget', () {
      final expectedIds = {
        'level-22', 'level-23', 'level-26', 'level-27', 'level-28',
        'level-33', 'level-34', 'level-35', 'level-36',
        for (var i = 0; i < 8; i++) 'level-${37 + i}',
      };
      final actualIds =
          kLevels.where((l) => l.maxShots != null).map((l) => l.id).toSet();
      expect(actualIds, expectedIds);
    });

    test('tier 8 levels all have wind zones', () {
      final tier8Ids = List.generate(5, (i) => 'level-${45 + i}');
      for (final id in tier8Ids) {
        final level = kLevels.firstWhere(
          (l) => l.id == id,
          orElse: () => throw StateError('missing $id'),
        );
        expect(level.windZones, isNotEmpty, reason: id);
      }
    });

    test(
      'wind zones have positive radius/magnitude and stay clear of the '
      'rocket start and target',
      () {
        for (final level in kLevels) {
          for (final zone in level.windZones) {
            expect(zone.radius, greaterThan(0), reason: level.id);
            expect(zone.forceMagnitude, greaterThan(0), reason: level.id);

            final startDistance =
                (level.rocketStart - zone.position).length;
            expect(startDistance, greaterThan(zone.radius), reason: level.id);

            final targetDistance =
                (level.targetPosition - zone.position).length;
            expect(
              targetDistance,
              greaterThan(zone.radius),
              reason: level.id,
            );
          }
        }
      },
    );
  });
}
