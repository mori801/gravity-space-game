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

        expect(
          (game.rocket.position - startPosition).length,
          greaterThan(1.0),
        );
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
        expect(game.shotCount, 1); // loss/mid-run retry: count keeps accumulating

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
        expect(game.loseReason, LoseReason.noFlyZone); // real reason, not overridden
        expect(game.shotCount, 1);

        game.resetLevel();
        expect(game.status, GameStatus.ready);

        game.launch(power: 1, angleOffset: 0); // refused: already used the 1 allowed shot
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
          targetPosition: Vector2(100, 100), // same as rocketStart so reaching it is instant
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

        expect(
          (game.rocket.position - Vector2(-300, 0)).length,
          lessThan(1.0),
        );
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
        expect(LevelProgress.instance.bestStars(kLevels.first.id), starsForShotCount(game.shotCount));
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

    test('starsForShotCount boundaries', () {
      expect(starsForShotCount(1), 3);
      expect(starsForShotCount(2), 2);
      expect(starsForShotCount(3), 2);
      expect(starsForShotCount(4), 1);
      expect(starsForShotCount(10), 1);
    });
  });
}
