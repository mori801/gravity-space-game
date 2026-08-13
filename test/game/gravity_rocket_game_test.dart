import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/gravity_rocket_game.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';

/// flame's [OverlayManager] (as of flame 1.38) asserts an overlay name is a
/// registered builder before `overlays.add(name)` is allowed to succeed.
/// Outside a real [GameWidget] (which registers `overlayBuilderMap` for
/// us), headless [testWithGame] games need to register a stub builder for
/// any overlay a test's code path might trigger (e.g. `_win()` calling
/// `overlays.add('WinOverlay')`).
void _registerStubOverlays(GravityRocketGame game) {
  for (final name in ['WinOverlay', 'LoseOverlay']) {
    game.overlays.addEntry(name, (context, game) => const SizedBox.shrink());
  }
}

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
        _registerStubOverlays(game);

        game.rocket.position.setFrom(game.target.position);
        game.launch(power: 0, angleOffset: 0);
        game.update(1 / 60);

        expect(game.status, GameStatus.won);
      },
    );
  });
}
