import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GameSettings', () {
    test('haptics is enabled by default', () {
      final settings = GameSettings();
      expect(settings.hapticsEnabled, isTrue);
    });

    test('hapticsEnabled can be toggled off and on', () {
      final settings = GameSettings();
      settings.hapticsEnabled = false;
      expect(settings.hapticsEnabled, isFalse);
      settings.hapticsEnabled = true;
      expect(settings.hapticsEnabled, isTrue);
    });

    test('resetForTest restores the default', () {
      final settings = GameSettings();
      settings.hapticsEnabled = false;
      settings.resetForTest();
      expect(settings.hapticsEnabled, isTrue);
    });

    test('load restores a previously-persisted haptics preference and '
        'future writes save back', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final first = GameSettings();
      first.load(prefs);
      first.hapticsEnabled = false;

      final second = GameSettings();
      second.load(prefs);
      expect(second.hapticsEnabled, isFalse);
    });
  });
}
