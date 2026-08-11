import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/gravity_rocket_game.dart';
import 'package:gravity_rocket_launcher/game/levels/level.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('GravityRocketGame', () {
    testWithGame<GravityRocketGame>(
      'rocket stays put before launch and moves after it',
      () => GravityRocketGame(level: kLevels.first),
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
      () => GravityRocketGame(level: kLevels.first),
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
      () => GravityRocketGame(
        level: LevelData(
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
      () => GravityRocketGame(level: kLevels.first),
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

    test('starsForShotCount boundaries', () {
      expect(starsForShotCount(1), 3);
      expect(starsForShotCount(2), 2);
      expect(starsForShotCount(3), 2);
      expect(starsForShotCount(4), 1);
      expect(starsForShotCount(10), 1);
    });
  });
}
