import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/screens/level_select_screen.dart';
import 'package:gravity_rocket_launcher/screens/main_menu_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tapping Play navigates to the level select screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));

    expect(find.text('Gravity Rocket'), findsOneWidget);
    expect(find.byType(LevelSelectScreen), findsNothing);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(find.byType(LevelSelectScreen), findsOneWidget);
    expect(find.text('Select Level'), findsOneWidget);
  });
}
