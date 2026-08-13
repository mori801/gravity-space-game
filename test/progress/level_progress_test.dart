import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/progress/level_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('starsForAttempts', () {
    test('1 attempt earns 3 stars', () {
      expect(starsForAttempts(1), 3);
    });

    test('2-3 attempts earn 2 stars', () {
      expect(starsForAttempts(2), 2);
      expect(starsForAttempts(3), 2);
    });

    test('4+ attempts earn 1 star', () {
      expect(starsForAttempts(4), 1);
      expect(starsForAttempts(10), 1);
    });
  });

  group('LevelProgress', () {
    const order = ['a', 'b', 'c'];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('first level is always unlocked with empty storage', () async {
      final progress = await LevelProgress.load();
      expect(progress.isUnlocked('a', order), isTrue);
      expect(progress.isUnlocked('b', order), isFalse);
    });

    test('completing a level unlocks the next one', () async {
      final progress = await LevelProgress.load();
      await progress.recordCompletion('a', 1);
      expect(progress.starsFor('a'), 3);
      expect(progress.isUnlocked('b', order), isTrue);
      expect(progress.isUnlocked('c', order), isFalse);
    });

    test('recording a worse attempt never lowers stored stars', () async {
      final progress = await LevelProgress.load();
      await progress.recordCompletion('a', 1);
      await progress.recordCompletion('a', 5);
      expect(progress.starsFor('a'), 3);
    });

    test('LevelProgress.empty() falls back to level-1-only, no crash', () {
      final progress = LevelProgress.empty();
      expect(progress.isUnlocked('a', order), isTrue);
      expect(progress.isUnlocked('b', order), isFalse);
      expect(progress.starsFor('a'), 0);
    });

    test('recordCompletion on empty progress no-ops without throwing', () async {
      final progress = LevelProgress.empty();
      await progress.recordCompletion('a', 1);
      expect(progress.starsFor('a'), 0);
    });
  });
}
