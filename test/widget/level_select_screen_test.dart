import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';
import 'package:gravity_rocket_launcher/game/progress.dart';
import 'package:gravity_rocket_launcher/screens/level_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LevelProgress.instance.resetForTest();
  });

  tearDown(() {
    LevelProgress.instance.resetForTest();
  });

  testWidgets('first level is tappable, second is locked with empty progress',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));
    await tester.pumpAndSettle();

    final firstTile = find.widgetWithText(ListTile, kLevels[0].name);
    final secondTile = find.widgetWithText(ListTile, kLevels[1].name);

    expect(tester.widget<ListTile>(firstTile).enabled, isTrue);
    expect(tester.widget<ListTile>(secondTile).enabled, isFalse);
    expect(
      find.descendant(of: secondTile, matching: find.byIcon(Icons.lock)),
      findsOneWidget,
    );
  });

  testWidgets('completed level shows its star count', (tester) async {
    LevelProgress.instance.markWon(kLevels[0].id);
    LevelProgress.instance.recordStars(kLevels[0].id, 3);

    await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));
    await tester.pumpAndSettle();

    // The level tile's 3 per-level stars are size 16; the AppBar's
    // running-total summary also uses Icons.star (size 20), so scope to
    // the tile's row to avoid over/under-counting against that extra icon.
    final firstTile = find.widgetWithText(ListTile, kLevels[0].name);
    expect(
      find.descendant(of: firstTile, matching: find.byIcon(Icons.star)),
      findsNWidgets(3),
    );
  });

  testWidgets('Tier 10 · Repulsors section renders with its first level',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));
    await tester.pumpAndSettle();

    final sectionHeader = find.text('Tier 10 · Repulsors');
    await tester.scrollUntilVisible(
      sectionHeader,
      500,
      scrollable: find.byType(Scrollable),
    );

    expect(sectionHeader, findsOneWidget);
    expect(find.text('Pushback'), findsOneWidget);
  });
}
