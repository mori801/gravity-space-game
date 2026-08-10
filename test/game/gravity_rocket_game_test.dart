import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/gravity_rocket_game.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';

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
  });
}
