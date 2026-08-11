import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/gravity_rocket_game.dart';
import 'package:gravity_rocket_launcher/game/levels/level.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';
import 'package:vector_math/vector_math.dart';

/// Builds a [GravityRocketGame] for a bare `testWithGame` harness (no
/// [GameWidget]/`overlayBuilderMap`, unlike the real app in
/// `lib/screens/game_screen.dart`). `_win()`/`_lose()` call
/// `overlays.add('WinOverlay'/'LoseOverlay')` unconditionally, and
/// Flame's `OverlayManager.add` asserts that the name was registered via
/// `addEntry` first — so any test that can reach a win/loss needs these
/// registered with a trivial stub builder (their actual widgets are
/// irrelevant here; nothing renders them in a plain `testWithGame`).
GravityRocketGame _testGame(LevelData level) {
  final game = GravityRocketGame(level: level);
  game.overlays.addEntry('WinOverlay', (context, game) => const SizedBox());
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

    test('starsForShotCount boundaries', () {
      expect(starsForShotCount(1), 3);
      expect(starsForShotCount(2), 2);
      expect(starsForShotCount(3), 2);
      expect(starsForShotCount(4), 1);
      expect(starsForShotCount(10), 1);
    });
  });
}
