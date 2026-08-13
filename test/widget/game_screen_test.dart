import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/gravity_rocket_game.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';
import 'package:gravity_rocket_launcher/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps [GameScreen] for [kLevels.first] and returns the live
/// [GravityRocketGame] instance so tests can assert on its state
/// (`_GameScreenState._game` isn't reachable directly, so tests instead
/// find the underlying `GameWidget` and read its `game` field).
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

  testWidgets('left arrow moves the aim angle away from straight up',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(level: kLevels.first)),
    );
    await tester.pump();

    final game = _pumpedGame(tester);
    final baseAngleRad = game.level.baseLaunchAngleDeg * math.pi / 180;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(game.rocket.aimAngleRadForTest, isNotNull);
    expect(
      (game.rocket.aimAngleRadForTest! - baseAngleRad).abs(),
      greaterThan(0.01),
    );
  });

  testWidgets(
      'right arrow / D moves the aim angle away from straight up, opposite '
      'left arrow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(level: kLevels.first)),
    );
    await tester.pump();

    final game = _pumpedGame(tester);
    final baseAngleRad = game.level.baseLaunchAngleDeg * math.pi / 180;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    await tester.pump();

    expect(game.rocket.aimAngleRadForTest, isNotNull);
    final dAngle = game.rocket.aimAngleRadForTest! - baseAngleRad;
    expect(dAngle.abs(), greaterThan(0.01));

    // Reset and confirm arrowLeft moves it the opposite direction.
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(level: kLevels.first)),
    );
    await tester.pump();
    final game2 = _pumpedGame(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    final dAngleLeft = game2.rocket.aimAngleRadForTest! - baseAngleRad;

    expect(dAngle.sign, isNot(dAngleLeft.sign));
  });

  testWidgets('space charges and launches on release', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(level: kLevels.first)),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();

    final game = _pumpedGame(tester);
    expect(game.status, GameStatus.launched);
  });

  testWidgets('R resets the level after a loss', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(level: kLevels.first)),
    );
    await tester.pump();

    final game = _pumpedGame(tester);
    game.launch(power: 1.0, angleOffset: 0);
    await tester.pump();
    game.status = GameStatus.lost;
    game.loseReason = LoseReason.outOfBounds;
    game.overlays.add('LoseOverlay');
    // LoseOverlay's own entrance/pulse animations need real time to
    // settle before the widget tree can be safely torn down at the end
    // of the test — a bare `pump()` leaves their timers pending.
    await tester.pump(const Duration(milliseconds: 500));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyR);
    await tester.pump();

    expect(game.status, GameStatus.ready);
    game.overlays.remove('LoseOverlay');
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('Escape opens the pause overlay while ready, closes it again',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(level: kLevels.first)),
    );
    await tester.pump();

    final game = _pumpedGame(tester);
    expect(game.overlays.isActive('PauseMenu'), isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(game.overlays.isActive('PauseMenu'), isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(game.overlays.isActive('PauseMenu'), isFalse);
  });

  testWidgets('Enter advances to the next level from the win overlay',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(level: kLevels.first)),
    );
    await tester.pump();

    final game = _pumpedGame(tester);
    final firstLevelId = game.level.id;
    game.status = GameStatus.won;
    game.overlays.add('WinOverlay');
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(game.level.id, isNot(firstLevelId));
    expect(game.level.id, kLevels[1].id);

    game.overlays.remove('WinOverlay');
    await tester.pump(const Duration(milliseconds: 500));
  });
}
