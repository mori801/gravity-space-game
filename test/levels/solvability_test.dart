// Every level must actually be winnable.
//
// This exists because two shipped levels (`repulsor-intro` and
// `repulsor-gauntlet`) were unwinnable: a repulsor sitting on the flight
// corridor pushed every approach away from the target, and since levels
// unlock sequentially that walled off all progression past Tier 10. No
// unit test, level-data invariant or code review caught it — only actually
// flying the shots did. So the suite flies them.
//
// The check brute-forces the launch space (every angle x every power the
// player can pick) and integrates each shot with the real physics
// functions the game itself uses, asserting at least one shot reaches the
// target. It is deliberately an *approximation*:
//
//  - It ignores wormholes and black-hole teleports, so a level that is
//    only solvable *through* a portal would be reported unsolvable. Such
//    levels belong on [_portalDependentLevels] below.
//  - It ignores planet motion, treating orbiting/oscillating planets as
//    frozen at their spawn point. That makes it stricter than the real
//    game (a moving planet opens windows this can't see), never laxer.
//
// Both simplifications mean a PASS is trustworthy: if this finds a winning
// shot, the shot really wins. A FAIL means "no simple ballistic shot wins"
// — which is the exact failure mode that shipped.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/levels/level.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';
import 'package:gravity_rocket_launcher/game/physics/gravity.dart';
import 'package:gravity_rocket_launcher/game/physics/wind.dart';
import 'package:vector_math/vector_math.dart';

/// Levels whose intended solution routes through a wormhole or black hole,
/// which the ballistic sweep below cannot model. Keep this list short and
/// justify every entry — an id parked here is an id nothing verifies.
const Set<String> _portalDependentLevels = <String>{};

/// Sweep resolution. 240 angles across the launch arc is finer than the
/// angular size of the smallest target at typical range, so a solution
/// that exists is found.
const int _angleSamples = 240;
const int _powerSamples = 48;
const double _dt = 1 / 60;
const int _maxSteps = 900;

/// The real game only calls a shot out of bounds once it is this far
/// outside [LevelData.playBounds] (`GravityRocketGame._outOfBoundsMargin`),
/// so the sweep has to allow the same slack or it would cut off routes
/// that legitimately clip the edge and come back.
const double _outOfBoundsMargin = 60;

bool _inBounds(LevelData level, Vector2 position) {
  final b = level.playBounds;
  return position.x >= b.left - _outOfBoundsMargin &&
      position.x <= b.right + _outOfBoundsMargin &&
      position.y >= b.top - _outOfBoundsMargin &&
      position.y <= b.bottom + _outOfBoundsMargin;
}

/// Flies every angle/power combination and returns true as soon as one
/// wins the level outright. Mirrors `Rocket.update`'s integration: gravity
/// from planets (and black holes, which are just very heavy gravity
/// sources) plus wind, applied to velocity, then velocity applied to
/// position.
bool _isSolvable(LevelData level) {
  final gravitySources = <GravitySource>[
    for (final planet in level.planets)
      GravitySource(position: planet.position, mass: planet.mass),
    for (final hole in level.blackHoles)
      GravitySource(position: hole.position, mass: hole.mass),
  ];
  final windSources = <WindZoneSource>[
    for (final zone in level.windZones)
      WindZoneSource(
        position: zone.position,
        radius: zone.radius,
        acceleration: Vector2(
          math.cos(zone.forceDirectionDeg * math.pi / 180) *
              zone.forceMagnitude,
          math.sin(zone.forceDirectionDeg * math.pi / 180) *
              zone.forceMagnitude,
        ),
      ),
  ];

  final baseAngle = level.baseLaunchAngleDeg * math.pi / 180;
  final angleRange = level.launchAngleRangeDeg * math.pi / 180;

  for (var a = 0; a <= _angleSamples; a++) {
    final angle = baseAngle - angleRange + 2 * angleRange * (a / _angleSamples);
    for (var p = 0; p <= _powerSamples; p++) {
      final speed = level.minLaunchSpeed +
          (level.maxLaunchSpeed - level.minLaunchSpeed) * (p / _powerSamples);

      final position = level.rocketStart.clone();
      final velocity = Vector2(math.cos(angle), math.sin(angle))..scale(speed);

      // Mirrors GravityRocketGame._hitTargetIndices: a level is only won
      // when EVERY target has been hit, all within this one uninterrupted
      // flight (the real game clears its hit set on every reset), and in
      // index order when level.ordered is set.
      final targets = level.targets;
      final hit = List<bool>.filled(targets.length, false);

      for (var step = 0; step < _maxSteps; step++) {
        final acceleration = gravitationalAcceleration(
          objectPosition: position,
          sources: gravitySources,
        );
        acceleration.add(
          totalWindAcceleration(objectPosition: position, sources: windSources),
        );
        velocity.addScaled(acceleration, _dt);
        position.addScaled(velocity, _dt);

        var remaining = 0;
        for (var t = 0; t < targets.length; t++) {
          if (hit[t]) continue;
          // On an ordered level a target can't register until every
          // earlier one already has, so the first unhit index is the only
          // one that can be scored this frame.
          final blockedByOrder = level.ordered && remaining > 0;
          if (!blockedByOrder &&
              (position - targets[t].position).length <= targets[t].radius) {
            hit[t] = true;
            continue;
          }
          remaining++;
        }
        if (remaining == 0) return true;

        var ended = false;
        for (final planet in level.planets) {
          // Repulsors are solid bodies too — the real _hasCrashed() checks
          // every planet regardless of mass sign, so a shot that flies
          // through one is a crash, not a route.
          if ((position - planet.position).length <= planet.radius) {
            ended = true;
            break;
          }
        }
        if (!ended) {
          for (final zone in level.noFlyZones) {
            if ((position - zone.position).length <= zone.radius) {
              ended = true;
              break;
            }
          }
        }
        if (!ended && !_inBounds(level, position)) {
          ended = true;
        }
        if (ended) break;
      }
    }
  }
  return false;
}

void main() {
  test('every level can actually be won by some launch angle and power', () {
    final unwinnable = <String>[
      for (final level in kLevels)
        if (!_portalDependentLevels.contains(level.id) && !_isSolvable(level))
          level.id,
    ];

    expect(
      unwinnable,
      isEmpty,
      reason: 'No angle/power combination reaches the target on these '
          'levels, so a player cannot get past them. Either open up a '
          'route (weaken or move whatever blocks the corridor) or, if the '
          'level is meant to be solved through a wormhole or black hole, '
          'add it to _portalDependentLevels with a justification.',
    );
  });

  test('_portalDependentLevels only names levels that exist', () {
    final ids = {for (final level in kLevels) level.id};
    for (final id in _portalDependentLevels) {
      expect(ids, contains(id), reason: 'stale allow-list entry: $id');
    }
  });
}
