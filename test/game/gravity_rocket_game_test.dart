import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/components/planet.dart';
import 'package:gravity_rocket_launcher/game/gravity_rocket_game.dart';
import 'package:gravity_rocket_launcher/game/levels/level.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';
import 'package:gravity_rocket_launcher/game/progress.dart';
import 'package:vector_math/vector_math.dart';

/// Builds a [GravityRocketGame] for a bare `testWithGame` harness (no
/// [GameWidget]/`overlayBuilderMap`, unlike the real app in
/// `lib/screens/game_screen.dart`). `_win()`/`_lose()` call
/// `overlays.add('WinOverlay'/'GameCompleteOverlay'/'LoseOverlay')`
/// unconditionally, and Flame's `OverlayManager.add` asserts that the name
/// was registered via `addEntry` first — so any test that can reach a
/// win/loss needs these registered with a trivial stub builder (their
/// actual widgets are irrelevant here; nothing renders them in a plain
/// `testWithGame`).
GravityRocketGame _testGame(LevelData level) {
  final game = GravityRocketGame(level: level);
  game.overlays.addEntry('WinOverlay', (context, game) => const SizedBox());
  game.overlays.addEntry(
    'GameCompleteOverlay',
    (context, game) => const SizedBox(),
  );
  game.overlays.addEntry('LoseOverlay', (context, game) => const SizedBox());
  return game;
}

void main() {
  group('GravityRocketGame', () {
    testWithGame<GravityRocketGame>(
      'rocket stays put before launch and moves after it',
      () => _testGame(kLevels.first),
      (game) async {
        await game.ready();

        final startPosition = game.rocket.position.clone();

        game.update(1 / 60);
        expect((game.rocket.position - startPosition).length, lessThan(1e-6));
        expect(game.status, GameStatus.ready);

        game.launch(power: 0.5, angleOffset: 0);
        expect(game.status, GameStatus.launched);

        for (var i = 0; i < 30; i++) {
          game.update(1 / 60);
        }

        expect((game.rocket.position - startPosition).length, greaterThan(1.0));
      },
    );

    testWithGame<GravityRocketGame>(
      'rocket.launched flips from false to true on launch, gating the '
      'pre-launch steer guide and trajectory preview',
      () => _testGame(kLevels.first),
      (game) async {
        await game.ready();

        // `Rocket.launched` is the exact flag `render()` gates both the
        // steer-guide arc and the trajectory-preview line on (both only
        // draw while `!launched`) — this asserts the flag itself flips at
        // the right time, without inspecting any pixels.
        expect(game.rocket.launched, isFalse);

        game.launch(power: 0.5, angleOffset: 0);

        expect(game.rocket.launched, isTrue);
      },
    );

    testWithGame<GravityRocketGame>(
      'reaching the target wins the level',
      () => _testGame(kLevels.first),
      (game) async {
        await game.ready();

        game.rocket.position.setFrom(game.target.position);
        game.launch(power: 0, angleOffset: 0);
        game.update(1 / 60);

        expect(game.status, GameStatus.won);
      },
    );

    testWithGame<GravityRocketGame>(
      'must hit all targets (any order) to win a multi-target level',
      () => _testGame(
        LevelData(
          id: 'test-multi',
          name: 'Test Multi',
          rocketStart: Vector2(0, 0),
          baseLaunchAngleDeg: 0,
          launchAngleRangeDeg: 10,
          minLaunchSpeed: 100,
          maxLaunchSpeed: 100,
          planets: const [],
          targetPosition: Vector2(200, 0),
          targetRadius: 10,
          additionalTargets: [
            TargetSpec(position: Vector2(-200, 0), radius: 10),
          ],
          playBounds: const Rect.fromLTWH(-500, -500, 1000, 1000),
        ),
      ),
      (game) async {
        await game.ready();

        game.rocket.position.setFrom(Vector2(200, 0));
        game.launch(power: 0, angleOffset: 0);
        game.update(1 / 60);
        expect(game.status, GameStatus.launched);

        game.rocket.position.setFrom(Vector2(-200, 0));
        game.update(1 / 60);
        expect(game.status, GameStatus.won);
      },
    );

    testWithGame<GravityRocketGame>(
      'entering a no-fly zone loses the level',
      () => _testGame(
        LevelData(
          id: 'test-no-fly-zone',
          name: 'Test',
          rocketStart: Vector2(100, 100),
          baseLaunchAngleDeg: -90,
          launchAngleRangeDeg: 90,
          minLaunchSpeed: 100,
          maxLaunchSpeed: 100,
          planets: const [],
          targetPosition: Vector2(500, 500),
          targetRadius: 20,
          playBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          noFlyZones: [NoFlyZoneSpec(position: Vector2(100, 90), radius: 30)],
        ),
      ),
      (game) async {
        await game.ready();
        game.launch(power: 1, angleOffset: 0);
        game.update(1 / 60);
        expect(game.status, GameStatus.lost);
        expect(game.loseReason, LoseReason.noFlyZone);
      },
    );

    testWithGame<GravityRocketGame>(
      'shotCount increments per launch and resets appropriately',
      () => _testGame(kLevels.first),
      (game) async {
        await game.ready();
        expect(game.shotCount, 0);

        game.launch(power: 0.5, angleOffset: 0);
        expect(game.shotCount, 1);

        game.resetLevel();
        expect(
          game.shotCount,
          1,
        ); // loss/mid-run retry: count keeps accumulating

        game.launch(power: 0.5, angleOffset: 0);
        expect(game.shotCount, 2);

        game.rocket.position.setFrom(game.target.position);
        game.update(1 / 60);
        expect(game.status, GameStatus.won);

        game.resetLevel(); // retry after a win: fresh count
        expect(game.shotCount, 0);
      },
    );

    testWithGame<GravityRocketGame>(
      'running out of fuel refuses further launches',
      () => _testGame(
        LevelData(
          id: 'test-max-shots',
          name: 'Test',
          rocketStart: Vector2(100, 100),
          baseLaunchAngleDeg: -90,
          launchAngleRangeDeg: 90,
          minLaunchSpeed: 100,
          maxLaunchSpeed: 100,
          planets: const [],
          targetPosition: Vector2(500, 500),
          targetRadius: 20,
          playBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          noFlyZones: [NoFlyZoneSpec(position: Vector2(100, 90), radius: 30)],
          maxShots: 1,
        ),
      ),
      (game) async {
        await game.ready();
        game.launch(power: 1, angleOffset: 0);
        game.update(1 / 60);
        expect(game.status, GameStatus.lost);
        expect(
          game.loseReason,
          LoseReason.noFlyZone,
        ); // real reason, not overridden
        expect(game.shotCount, 1);

        game.resetLevel();
        expect(game.status, GameStatus.ready);

        game.launch(
          power: 1,
          angleOffset: 0,
        ); // refused: already used the 1 allowed shot
        expect(game.status, GameStatus.lost);
        expect(game.loseReason, LoseReason.outOfFuel);
        expect(game.shotCount, 1); // must not tick past maxShots
      },
    );

    testWithGame<GravityRocketGame>(
      'winning on the last allowed shot still wins',
      () => _testGame(
        LevelData(
          id: 'test-max-shots-win',
          name: 'Test',
          rocketStart: Vector2(100, 100),
          baseLaunchAngleDeg: -90,
          launchAngleRangeDeg: 90,
          minLaunchSpeed: 100,
          maxLaunchSpeed: 100,
          planets: const [],
          targetPosition: Vector2(
            100,
            100,
          ), // same as rocketStart so reaching it is instant
          targetRadius: 20,
          playBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          maxShots: 1,
        ),
      ),
      (game) async {
        await game.ready();
        game.launch(power: 0, angleOffset: 0);
        game.update(1 / 60);
        expect(game.status, GameStatus.won); // not preempted by the fuel gate
      },
    );

    testWithGame<GravityRocketGame>(
      'maxShots + no-fly zone + planet combo: budget exhausts correctly',
      () => _testGame(
        LevelData(
          id: 'test-tier7-combo',
          name: 'Test',
          rocketStart: Vector2(100, 100),
          baseLaunchAngleDeg: -90,
          launchAngleRangeDeg: 90,
          minLaunchSpeed: 100,
          maxLaunchSpeed: 100,
          planets: [
            PlanetSpec(
              position: Vector2(400, 400),
              mass: 1,
              radius: 10,
              color: const Color(0xFF000000),
            ),
          ],
          targetPosition: Vector2(900, 900),
          targetRadius: 20,
          playBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          noFlyZones: [NoFlyZoneSpec(position: Vector2(100, 90), radius: 30)],
          maxShots: 2,
        ),
      ),
      (game) async {
        await game.ready();

        game.launch(power: 1, angleOffset: 0);
        game.update(1 / 60);
        expect(game.loseReason, LoseReason.noFlyZone);
        expect(game.shotCount, 1);

        game.resetLevel();
        game.launch(power: 1, angleOffset: 0);
        game.update(1 / 60);
        expect(game.loseReason, LoseReason.noFlyZone);
        expect(game.shotCount, 2);

        game.resetLevel();
        game.launch(power: 1, angleOffset: 0); // budget exhausted -> refused
        expect(game.loseReason, LoseReason.outOfFuel);
        expect(game.shotCount, 2); // must not tick past maxShots
      },
    );

    testWithGame<GravityRocketGame>(
      'winning on the last shot wins even with planets and no-fly zones present',
      () => _testGame(
        LevelData(
          id: 'test-tier7-combo-win',
          name: 'Test',
          rocketStart: Vector2(100, 100),
          baseLaunchAngleDeg: -90,
          launchAngleRangeDeg: 90,
          minLaunchSpeed: 100,
          maxLaunchSpeed: 100,
          planets: [
            PlanetSpec(
              position: Vector2(500, 500),
              mass: 1,
              radius: 10,
              color: const Color(0xFF000000),
            ),
          ],
          targetPosition: Vector2(100, 100), // same as rocketStart: instant win
          targetRadius: 20,
          playBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          noFlyZones: [NoFlyZoneSpec(position: Vector2(900, 900), radius: 30)],
          maxShots: 1,
        ),
      ),
      (game) async {
        await game.ready();
        game.launch(power: 0, angleOffset: 0);
        game.update(1 / 60);
        expect(game.status, GameStatus.won);
      },
    );

    testWithGame<GravityRocketGame>(
      'entering a wormhole teleports the rocket to the paired exit',
      () => _testGame(
        LevelData(
          id: 'test-wormhole',
          name: 'Test Wormhole',
          rocketStart: Vector2(0, 0),
          baseLaunchAngleDeg: 0,
          launchAngleRangeDeg: 10,
          minLaunchSpeed: 300,
          maxLaunchSpeed: 300,
          planets: const [],
          targetPosition: Vector2(1000, 1000),
          targetRadius: 10,
          wormholes: [
            WormholeSpec(a: Vector2(100, 0), b: Vector2(-300, 0), radius: 15),
          ],
          playBounds: const Rect.fromLTWH(-1000, -1000, 3000, 3000),
        ),
      ),
      (game) async {
        await game.ready();

        game.rocket.position.setFrom(Vector2(100, 0));
        game.launch(power: 0, angleOffset: 0);
        game.update(1 / 60);

        expect((game.rocket.position - Vector2(-300, 0)).length, lessThan(1.0));
      },
    );

    testWithGame<GravityRocketGame>(
      'a moving planet advances position every frame instead of staying put',
      () => _testGame(
        LevelData(
          id: 'test-moving-planet',
          name: 'Test Moving Planet',
          rocketStart: Vector2(0, 0),
          baseLaunchAngleDeg: 0,
          launchAngleRangeDeg: 10,
          minLaunchSpeed: 0,
          maxLaunchSpeed: 0,
          planets: [
            PlanetSpec(
              position: Vector2(500, 0),
              mass: 5000,
              radius: 20,
              color: const Color(0xFFFFFFFF),
              motion: OrbitMotion(
                center: Vector2(0, 500),
                radius: 500,
                angularSpeedRadPerSec: math.pi,
              ),
            ),
          ],
          targetPosition: Vector2(1000, 1000),
          targetRadius: 10,
          playBounds: const Rect.fromLTWH(-2000, -2000, 4000, 4000),
        ),
      ),
      (game) async {
        await game.ready();
        game.launch(power: 0, angleOffset: 0);

        game.update(1 / 60);

        final planet = game.world.children.query<Planet>().first;
        expect(planet.position.x, isNot(closeTo(500, 1e-6)));
      },
    );

    testWithGame<GravityRocketGame>(
      'winning marks the level as won in LevelProgress',
      () => _testGame(kLevels.first),
      (game) async {
        LevelProgress.instance.resetForTest();
        addTearDown(LevelProgress.instance.resetForTest);
        await game.ready();
        expect(LevelProgress.instance.isWon(kLevels.first.id), isFalse);

        game.rocket.position.setFrom(game.target.position);
        game.launch(power: 0, angleOffset: 0);
        game.update(1 / 60);

        expect(game.status, GameStatus.won);
        expect(LevelProgress.instance.isWon(kLevels.first.id), isTrue);
        expect(LevelProgress.instance.isWon(kLevels[1].id), isFalse);
        expect(
          LevelProgress.instance.bestStars(kLevels.first.id),
          starsForShotCount(game.shotCount),
        );
      },
    );

    testWithGame<GravityRocketGame>(
      'winning the last level shows GameCompleteOverlay, not WinOverlay',
      () => _testGame(kLevels.last),
      (game) async {
        addTearDown(LevelProgress.instance.resetForTest);
        await game.ready();
        // kLevels.last (the multi-target showcase level) requires hitting
        // every target, not just the primary one — launch once, then
        // sweep the rocket through each target position in turn.
        game.launch(power: 0, angleOffset: 0);
        for (final t in game.targets) {
          game.rocket.position.setFrom(t.position);
          game.update(1 / 60);
        }
        expect(game.status, GameStatus.won);
        expect(game.overlays.isActive('GameCompleteOverlay'), isTrue);
        expect(game.overlays.isActive('WinOverlay'), isFalse);
      },
    );

    testWithGame<GravityRocketGame>(
      'a wind zone measurably deflects the rocket compared to a straight shot',
      () => _testGame(
        LevelData(
          id: 'test-wind-zone',
          name: 'Test',
          rocketStart: Vector2(500, 900),
          baseLaunchAngleDeg: -90,
          launchAngleRangeDeg: 90,
          minLaunchSpeed: 300,
          maxLaunchSpeed: 300,
          planets: const [],
          targetPosition: Vector2(500, 100),
          targetRadius: 20,
          playBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          windZones: [
            // radius 500 (not 300) so the zone covers the rocket's entire
            // simulated path here (start is 400 away from the zone
            // center) — hand-verified via simulation that a 300-radius
            // zone only catches the last ~10 of these 30 steps and
            // produces a final x of ~506, which would NOT clear the
            // greaterThan(510) bar below; 500 keeps wind active for all
            // 30 steps, giving a comfortable, robust margin (~x=551.7).
            WindZoneSpec(
              position: Vector2(500, 500),
              radius: 500,
              forceDirectionDeg: 0,
              forceMagnitude: 400,
            ),
          ],
        ),
      ),
      (game) async {
        await game.ready();
        game.launch(power: 1, angleOffset: 0);
        for (var i = 0; i < 30; i++) {
          game.update(1 / 60);
        }
        // A straight-up shot with no gravity/wind would stay at x == 500;
        // the wind zone (pushing in +x) should have measurably deflected it.
        expect(game.rocket.position.x, greaterThan(510));
      },
    );

    testWithGame<GravityRocketGame>(
      'a repulsor planet deflects the rocket away from it, not toward it',
      () => _testGame(
        LevelData(
          id: 'test-repulsor',
          name: 'Test Repulsor',
          // Straight-up launch path is x == 500. The repulsor sits off to
          // the +x side of that path and well clear of it (150px), so if
          // it behaves as a repulsor the rocket gets pushed further into
          // -x (away from the planet); if gravity math were accidentally
          // still attractive for negative mass, the rocket would instead
          // bend toward +x (toward the planet). Asymmetric placement
          // makes "away" vs "toward" unambiguous from x-position alone.
          // Mass/distance are tuned (checked by simulation) so the
          // rocket's vertical progress is only slowed, never reversed,
          // over the fixed step budget below.
          rocketStart: Vector2(500, 900),
          baseLaunchAngleDeg: -90,
          launchAngleRangeDeg: 90,
          minLaunchSpeed: 300,
          maxLaunchSpeed: 300,
          planets: [
            PlanetSpec(
              position: Vector2(650, 500),
              mass: -1500,
              radius: 20,
              color: const Color(0xFFFF6584),
            ),
          ],
          targetPosition: Vector2(500, 100),
          targetRadius: 20,
          playBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        ),
      ),
      (game) async {
        await game.ready();
        game.launch(power: 1, angleOffset: 0);

        // Fixed step budget (matches the wind-zone test's approach above)
        // covering the rocket flying from y=900 well past the repulsor's
        // y=500 level (hand-verified via simulation: y drops below 500
        // around frame ~95 and keeps falling well below it afterward).
        for (var i = 0; i < 120; i++) {
          game.update(1 / 60);
        }

        expect(
          game.rocket.position.y,
          lessThan(500),
          reason: 'rocket should have flown past the repulsor by now',
        );

        // A straight-up shot with no gravity would stay at x == 500. The
        // repulsor (at x == 650) should have pushed the rocket toward -x
        // (away from itself), not toward +x (toward itself).
        expect(game.rocket.position.x, lessThan(500));
      },
    );

    testWithGame<GravityRocketGame>(
      'ordered level: hitting target 2 before target 1 does not register it or win',
      () => _testGame(
        LevelData(
          id: 'test-ordered-out-of-sequence',
          name: 'Test Ordered Out Of Sequence',
          rocketStart: Vector2(0, 0),
          baseLaunchAngleDeg: 0,
          launchAngleRangeDeg: 10,
          minLaunchSpeed: 100,
          maxLaunchSpeed: 100,
          planets: const [],
          // Target 1 (primary) is further away; target 2 (additional) sits
          // closer to the rocket's start so it's the one a short flight
          // would plausibly reach first.
          targetPosition: Vector2(400, 0),
          targetRadius: 10,
          additionalTargets: [
            TargetSpec(position: Vector2(100, 0), radius: 10),
          ],
          playBounds: const Rect.fromLTWH(-500, -500, 1000, 1000),
          ordered: true,
        ),
      ),
      (game) async {
        await game.ready();

        // Move the rocket onto target index 1's position (the
        // "additionalTargets[0]" one) without ever having reached index 0.
        game.rocket.position.setFrom(Vector2(100, 0));
        game.launch(power: 0, angleOffset: 0);
        for (var i = 0; i < 5; i++) {
          game.update(1 / 60);
        }

        expect(game.status, isNot(GameStatus.won));
        expect(game.nextRequiredTargetIndex, 0);
      },
    );

    testWithGame<GravityRocketGame>(
      'ordered level: hitting targets in sequence wins',
      () => _testGame(
        LevelData(
          id: 'test-ordered-sequence-win',
          name: 'Test Ordered Sequence Win',
          rocketStart: Vector2(0, 0),
          baseLaunchAngleDeg: 0,
          launchAngleRangeDeg: 10,
          minLaunchSpeed: 100,
          maxLaunchSpeed: 100,
          planets: const [],
          targetPosition: Vector2(100, 0),
          targetRadius: 10,
          additionalTargets: [
            TargetSpec(position: Vector2(-100, 0), radius: 10),
          ],
          playBounds: const Rect.fromLTWH(-500, -500, 1000, 1000),
          ordered: true,
        ),
      ),
      (game) async {
        await game.ready();
        game.launch(power: 0, angleOffset: 0);

        // Reach target 0 first...
        game.rocket.position.setFrom(Vector2(100, 0));
        game.update(1 / 60);
        expect(game.status, GameStatus.launched);
        expect(game.nextRequiredTargetIndex, 1);

        // ...then target 1, now in the correct order.
        game.rocket.position.setFrom(Vector2(-100, 0));
        game.update(1 / 60);

        expect(game.status, GameStatus.won);
      },
    );

    testWithGame<GravityRocketGame>(
      'unordered multi-target level still wins when targets are hit in any order (regression)',
      () => _testGame(
        LevelData(
          id: 'test-unordered-regression',
          name: 'Test Unordered Regression',
          rocketStart: Vector2(0, 0),
          baseLaunchAngleDeg: 0,
          launchAngleRangeDeg: 10,
          minLaunchSpeed: 100,
          maxLaunchSpeed: 100,
          planets: const [],
          targetPosition: Vector2(200, 0),
          targetRadius: 10,
          additionalTargets: [
            TargetSpec(position: Vector2(-200, 0), radius: 10),
          ],
          playBounds: const Rect.fromLTWH(-500, -500, 1000, 1000),
          // ordered defaults to false.
        ),
      ),
      (game) async {
        await game.ready();

        // Hit the *second* (additional) target first, then the primary
        // target — reverse of declaration order.
        game.rocket.position.setFrom(Vector2(-200, 0));
        game.launch(power: 0, angleOffset: 0);
        game.update(1 / 60);
        expect(game.status, GameStatus.launched);

        game.rocket.position.setFrom(Vector2(200, 0));
        game.update(1 / 60);
        expect(game.status, GameStatus.won);
      },
    );

    testWithGame<GravityRocketGame>(
      'nextRequiredTargetIndex reflects progress on an ordered level',
      () => _testGame(
        LevelData(
          id: 'test-next-required-target-index',
          name: 'Test Next Required Target Index',
          rocketStart: Vector2(0, 0),
          baseLaunchAngleDeg: 0,
          launchAngleRangeDeg: 10,
          minLaunchSpeed: 100,
          maxLaunchSpeed: 100,
          planets: const [],
          targetPosition: Vector2(100, 0),
          targetRadius: 10,
          additionalTargets: [
            TargetSpec(position: Vector2(-100, 0), radius: 10),
          ],
          playBounds: const Rect.fromLTWH(-500, -500, 1000, 1000),
          ordered: true,
        ),
      ),
      (game) async {
        await game.ready();
        expect(game.nextRequiredTargetIndex, 0);

        game.launch(power: 0, angleOffset: 0);
        game.rocket.position.setFrom(Vector2(100, 0));
        game.update(1 / 60);

        expect(game.nextRequiredTargetIndex, 1);
      },
    );

    testWithGame<GravityRocketGame>(
      'renders without throwing with both active and dimmed targets present',
      () => _testGame(
        LevelData(
          id: 'test-render-targets',
          name: 'Test Render Targets',
          rocketStart: Vector2(0, 0),
          baseLaunchAngleDeg: 0,
          launchAngleRangeDeg: 10,
          minLaunchSpeed: 100,
          maxLaunchSpeed: 100,
          planets: const [],
          targetPosition: Vector2(100, 0),
          targetRadius: 10,
          additionalTargets: [
            TargetSpec(position: Vector2(-100, 0), radius: 10),
          ],
          playBounds: const Rect.fromLTWH(-500, -500, 1000, 1000),
          ordered: true,
        ),
      ),
      (game) async {
        await game.ready();

        // Ordered level: target 0 starts active, target 1 starts dimmed —
        // gives one active and one dimmed Target in the same render pass,
        // so this exercises Target.render's fill+stroke two-pass drawing
        // (see lib/game/components/target.dart) for both isActive states.
        expect(game.targets[0].isActive, isTrue);
        expect(game.targets[1].isActive, isFalse);

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        expect(() => game.render(canvas), returnsNormally);
        recorder.endRecording().dispose();
      },
    );

    test('starsForShotCount boundaries', () {
      expect(starsForShotCount(1), 3);
      expect(starsForShotCount(2), 2);
      expect(starsForShotCount(3), 2);
      expect(starsForShotCount(4), 1);
      expect(starsForShotCount(10), 1);
    });
  });
}
