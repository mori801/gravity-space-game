import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';
import 'package:gravity_rocket_launcher/screens/level_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('first level is tappable, second is locked with empty progress',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

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
    SharedPreferences.setMockInitialValues({
      'level_stars_${kLevels[0].id}': 3,
    });

    await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsNWidgets(3));
  });
}
