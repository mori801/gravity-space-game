import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/levels/level.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';

/// Shortest distance from point ([px], [py]) to the line segment running
/// from ([ax], [ay]) to ([bx], [by]). Standard project-onto-segment-and-
/// clamp formula; used below to detect levels where the straight shot
/// from the rocket to the target passes nowhere near any obstacle.
double _distanceToSegment(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    final ddx = px - ax;
    final ddy = py - ay;
    return sqrt(ddx * ddx + ddy * ddy);
  }
  final t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
  final closestX = ax + t * dx;
  final closestY = ay + t * dy;
  final ddx = px - closestX;
  final ddy = py - closestY;
  return sqrt(ddx * ddx + ddy * ddy);
}

/// A straight rocketStart -> targetPosition shot is considered "blocked"
/// by an obstacle when the line comes within the obstacle's radius plus
/// this clearance margin. 45px is comfortably more than a rocket/target
/// hit-radius grazing an obstacle's edge — it means the line either
/// clips the obstacle outright or passes close enough that its gravity
/// (or, for no-fly zones, its exclusion radius) is unmissable, so a
/// player genuinely cannot ignore it and fly straight through.
const double _obstacleClearanceMargin = 45.0;

/// Levels where the straight rocketStart -> targetPosition shot is
/// legitimately unobstructed by geometry, and that's intentional rather
/// than an oversight — kept deliberately short, each entry justified.
const Set<String> _directLineAllowList = {
  // "Full Circuit" (tier 11 · sequence): target 1 (the required first
  // stop) is, by explicit design (see the doc comment on
  // _sequenceGauntletLoop above), "a tight, low-energy loop right in
  // front of the rocket" — a deliberate, easy warm-up hop before the
  // real gauntlet. Targets 2 and 3, which come later in the required
  // order, are both genuinely blocked by the level's two planets.
  // Forcing an obstacle onto a ~280px point-blank opening hop would
  // fight the documented, intentional design rather than fix a real
  // "too easy" oversight.
  'sequence-gauntlet-loop',
};

const _tier10Ids = [
  'repulsor-intro',
  'repulsor-gauntlet',
  'repulsor-slalom',
  'repulsor-orbit-break',
];

const _tier11Ids = [
  'sequence-intro',
  'sequence-slingshot-relay',
  'sequence-orbital-checkpoints',
  'sequence-gauntlet-loop',
];

const _tier12Ids = [
  'black-hole-intro',
  'black-hole-flyby',
  'black-hole-corridor',
  'black-hole-gauntlet',
];

void main() {
  group('kLevels', () {
    test('has unique ids', () {
      final ids = kLevels.map((level) => level.id).toSet();
      expect(ids.length, kLevels.length);
    });

    test('every planet has nonzero mass and positive radius', () {
      // Negative mass is a valid, intentional mechanic (repulsor planets,
      // Tier 10) — only zero mass (no gravitational effect at all, almost
      // certainly a data-entry mistake) is disallowed. Radius must always
      // be positive regardless of mass sign.
      for (final level in kLevels) {
        for (final planet in level.planets) {
          expect(planet.mass, isNot(0), reason: level.id);
          expect(planet.radius, greaterThan(0), reason: level.id);
        }
      }
    });

    test('rocket start and target are within play bounds', () {
      for (final level in kLevels) {
        expect(
          level.playBounds.contains(
            Offset(level.rocketStart.x, level.rocketStart.y),
          ),
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

    test(
      'targets getter combines the primary target with additionalTargets',
      () {
        for (final level in kLevels) {
          expect(
            level.targets.length,
            1 + level.additionalTargets.length,
            reason: level.id,
          );
          expect(
            level.targets.first.position,
            level.targetPosition,
            reason: level.id,
          );
        }
      },
    );

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
      expect(
        kLevels.any((l) => l.blackHoles.isNotEmpty),
        isTrue,
        reason: 'expected at least one level with a black hole',
      );
    });

    test('no-fly zones have positive radius and never contain the rocket '
        'start or target', () {
      for (final level in kLevels) {
        for (final zone in level.noFlyZones) {
          expect(zone.radius, greaterThan(0), reason: level.id);

          final startDistance = (level.rocketStart - zone.position).length;
          expect(startDistance, greaterThan(zone.radius), reason: level.id);

          final targetDistance = (level.targetPosition - zone.position).length;
          expect(targetDistance, greaterThan(zone.radius), reason: level.id);
        }
      }
    });

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

    test('kLevels has 64 levels total', () {
      expect(kLevels.length, 64);
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
        'level-22',
        'level-23',
        'level-26',
        'level-27',
        'level-28',
        'level-33',
        'level-34',
        'level-35',
        'level-36',
        for (var i = 0; i < 8; i++) 'level-${37 + i}',
      };
      final actualIds = kLevels
          .where((l) => l.maxShots != null)
          .map((l) => l.id)
          .toSet();
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

    test('wind zones have positive radius/magnitude and stay clear of the '
        'rocket start and target', () {
      for (final level in kLevels) {
        for (final zone in level.windZones) {
          expect(zone.radius, greaterThan(0), reason: level.id);
          expect(zone.forceMagnitude, greaterThan(0), reason: level.id);

          final startDistance = (level.rocketStart - zone.position).length;
          expect(startDistance, greaterThan(zone.radius), reason: level.id);

          final targetDistance = (level.targetPosition - zone.position).length;
          expect(targetDistance, greaterThan(zone.radius), reason: level.id);
        }
      }
    });

    test('tier 10 has exactly the 4 repulsor levels', () {
      for (final id in _tier10Ids) {
        final level = kLevels.firstWhere(
          (l) => l.id == id,
          orElse: () => throw StateError('missing $id'),
        );
        expect(level.id, id);
      }
      final actualTier10Count = kLevels
          .where((l) => _tier10Ids.contains(l.id))
          .length;
      expect(actualTier10Count, 4);
    });

    test(
      'kLevelSections attributes tier 10 levels to "Tier 10 · Repulsors"',
      () {
        for (final id in _tier10Ids) {
          expect(tierTitleForLevel(id), 'Tier 10 · Repulsors', reason: id);
        }
      },
    );

    test(
      'at least one tier 10 level has a negative-mass (repulsor) planet',
      () {
        final tier10Levels = kLevels.where((l) => _tier10Ids.contains(l.id));
        expect(
          tier10Levels.any((l) => l.planets.any((p) => p.mass < 0)),
          isTrue,
          reason:
              'expected at least one Tier 10 level with a repulsor planet '
              '(negative mass) — otherwise the tier is not actually '
              'exercising the repulsor mechanic',
        );
      },
    );

    test('tier 11 has exactly the 4 sequence levels', () {
      for (final id in _tier11Ids) {
        final level = kLevels.firstWhere(
          (l) => l.id == id,
          orElse: () => throw StateError('missing $id'),
        );
        expect(level.id, id);
      }
      final actualTier11Count = kLevels
          .where((l) => _tier11Ids.contains(l.id))
          .length;
      expect(actualTier11Count, 4);
    });

    test(
      'kLevelSections attributes tier 11 levels to "Tier 11 · Sequence"',
      () {
        for (final id in _tier11Ids) {
          expect(tierTitleForLevel(id), 'Tier 11 · Sequence', reason: id);
        }
      },
    );

    test('ordered flag is set only on the tier 11 sequence levels', () {
      for (final level in kLevels) {
        if (_tier11Ids.contains(level.id)) {
          expect(level.ordered, isTrue, reason: level.id);
        } else {
          expect(level.ordered, isFalse, reason: level.id);
        }
      }
    });

    test('tier 12 has exactly the 4 black hole levels', () {
      for (final id in _tier12Ids) {
        final level = kLevels.firstWhere(
          (l) => l.id == id,
          orElse: () => throw StateError('missing $id'),
        );
        expect(level.id, id);
      }
      final actualTier12Count = kLevels
          .where((l) => _tier12Ids.contains(l.id))
          .length;
      expect(actualTier12Count, 4);
    });

    test(
      'kLevelSections attributes tier 12 levels to "Tier 12 · Black Holes"',
      () {
        for (final id in _tier12Ids) {
          expect(tierTitleForLevel(id), 'Tier 12 · Black Holes', reason: id);
        }
      },
    );

    test('black holes have positive radius/mass and stay within bounds, '
        'with an in-bounds exit position', () {
      for (final level in kLevels) {
        for (final hole in level.blackHoles) {
          expect(hole.radius, greaterThan(0), reason: level.id);
          expect(hole.mass, greaterThan(0), reason: level.id);
          expect(
            level.playBounds.contains(Offset(hole.position.x, hole.position.y)),
            isTrue,
            reason: level.id,
          );
          expect(
            level.playBounds.contains(
              Offset(hole.exitPosition.x, hole.exitPosition.y),
            ),
            isTrue,
            reason: level.id,
          );
          expect(hole.exitVelocityScale, greaterThan(0), reason: level.id);
        }
      }
    });

    test('at least one tier 12 level has a black hole with a non-default '
        'exitVelocityScale', () {
      final tier12Levels = kLevels.where((l) => _tier12Ids.contains(l.id));
      expect(
        tier12Levels.any(
          (l) => l.blackHoles.any((h) => h.exitVelocityScale != 1.0),
        ),
        isTrue,
        reason:
            'expected at least one Tier 12 level to exercise a '
            'non-default exitVelocityScale',
      );
    });

    test('every non-black-hole-tier level has an empty blackHoles list '
        '(additive default holds)', () {
      for (final level in kLevels) {
        if (_tier12Ids.contains(level.id)) continue;
        expect(level.blackHoles, isEmpty, reason: level.id);
      }
    });

    test('the naive straight shot from rocketStart to the primary target is '
        'blocked by a real obstacle (planet, no-fly zone, or black hole), '
        'unless explicitly allow-listed', () {
      for (final level in kLevels) {
        if (_directLineAllowList.contains(level.id)) continue;

        final ax = level.rocketStart.x;
        final ay = level.rocketStart.y;
        final bx = level.targetPosition.x;
        final by = level.targetPosition.y;

        bool isBlockedBy(double ox, double oy, double radius) {
          final distance = _distanceToSegment(ox, oy, ax, ay, bx, by);
          return distance <= radius + _obstacleClearanceMargin;
        }

        final blocked =
            level.planets.any(
              (p) => isBlockedBy(p.position.x, p.position.y, p.radius),
            ) ||
            level.noFlyZones.any(
              (z) => isBlockedBy(z.position.x, z.position.y, z.radius),
            ) ||
            level.blackHoles.any(
              (h) => isBlockedBy(h.position.x, h.position.y, h.radius),
            );

        expect(
          blocked,
          isTrue,
          reason:
              '${level.id}: the straight rocketStart -> targetPosition '
              'line has no obstacle within ${_obstacleClearanceMargin}px '
              'of it — this level is a free direct shot',
        );
      }
    });

    // Sanity check on the allow-list itself: every allow-listed id must
    // actually exist in kLevels, so a future rename/removal can't leave a
    // stale, silently-ignored entry behind.
    test('direct-line allow-list only references real level ids', () {
      final ids = kLevels.map((l) => l.id).toSet();
      for (final id in _directLineAllowList) {
        expect(ids.contains(id), isTrue, reason: id);
      }
    });
  });
}
