import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/gravity_rocket_game.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';
import 'package:gravity_rocket_launcher/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps [GameScreen] for [level] and returns the live [GravityRocketGame]
/// instance so tests can assert on its state (`_GameScreenState._game` isn't
/// reachable directly, so tests instead find the underlying `GameWidget` and
/// read its `game` field). Mirrors the identical helper in
/// `test/widget/game_screen_test.dart`.
GravityRocketGame _pumpedGame(WidgetTester tester) {
  final gameWidgetFinder = find.byType(GameWidget<GravityRocketGame>);
  final gameWidget =
      tester.widget<GameWidget<GravityRocketGame>>(gameWidgetFinder);
  return gameWidget.game!;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'Next: target readout is shown for an ordered level and hidden for a '
      'non-ordered one', (tester) async {
    final orderedLevel = kLevels.firstWhere((level) => level.ordered);

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(key: UniqueKey(), level: orderedLevel),
      ),
    );
    await tester.pump();

    // The level's targets are hit in list order, so before any target is
    // hit the readout should point at target 1 of however many this level
    // has (primary target + additionalTargets).
    final game = _pumpedGame(tester);
    final totalTargets = game.targets.length;
    expect(totalTargets, greaterThan(1));
    expect(find.text('Next: target 1 of $totalTargets'), findsOneWidget);

    // A non-ordered level (the tutorial's first level) must not show the
    // readout at all. A fresh UniqueKey forces GameScreen to rebuild its
    // State (and thus its GravityRocketGame) from scratch rather than
    // reusing the previous element in place, since GameScreen otherwise
    // has no key and Flutter would just update the existing State with
    // the new `level` — leaving `_game` (created once in `initState`)
    // still pointing at the old, ordered level.
    final nonOrderedLevel = kLevels.firstWhere((level) => !level.ordered);
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(key: UniqueKey(), level: nonOrderedLevel),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Next: target'), findsNothing);
  });
}
