import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/levels/level.dart';
import 'package:gravity_rocket_launcher/game/progress.dart';
import 'package:vector_math/vector_math.dart';

LevelData _dummy(String id) => LevelData(
      id: id,
      name: id,
      rocketStart: Vector2.zero(),
      baseLaunchAngleDeg: -90,
      launchAngleRangeDeg: 90,
      minLaunchSpeed: 1,
      maxLaunchSpeed: 1,
      planets: const [],
      targetPosition: Vector2.zero(),
      targetRadius: 1,
      playBounds: const Rect.fromLTWH(0, 0, 1, 1),
    );

void main() {
  group('LevelProgress', () {
    test('markWon is idempotent and isWon reflects only won ids', () {
      final progress = LevelProgress();
      expect(progress.isWon('a'), isFalse);
      progress.markWon('a');
      progress.markWon('a');
      expect(progress.isWon('a'), isTrue);
      expect(progress.isWon('b'), isFalse);
      expect(progress.wonLevelIds, {'a'});
    });

    test('recordStars keeps the best value across repeated calls', () {
      final progress = LevelProgress();
      expect(progress.bestStars('a'), 0);
      progress.recordStars('a', 2);
      expect(progress.bestStars('a'), 2);
      progress.recordStars('a', 3);
      expect(progress.bestStars('a'), 3);
      progress.recordStars('a', 1); // worse retry must not lower the best
      expect(progress.bestStars('a'), 3);
    });

    test('totalStars sums best ratings across levels', () {
      final progress = LevelProgress();
      progress.recordStars('a', 3);
      progress.recordStars('b', 1);
      progress.recordStars('c', 2);
      expect(progress.totalStars, 6);
    });

    test('resetProgress clears both won levels and star ratings', () {
      final progress = LevelProgress();
      progress.markWon('a');
      progress.recordStars('a', 3);
      progress.resetProgress();
      expect(progress.isWon('a'), isFalse);
      expect(progress.bestStars('a'), 0);
    });
  });

  group('isLevelUnlocked', () {
    final levels = [_dummy('a'), _dummy('b'), _dummy('c')];

    test('the first level is always unlocked', () {
      final progress = LevelProgress();
      expect(isLevelUnlocked(0, levels, progress), isTrue);
    });

    test('a later level unlocks only once its predecessor is won', () {
      final progress = LevelProgress();
      expect(isLevelUnlocked(1, levels, progress), isFalse);
      progress.markWon('a');
      expect(isLevelUnlocked(1, levels, progress), isTrue);
      expect(isLevelUnlocked(2, levels, progress), isFalse);
    });

    test('a level that is already won stays unlocked even if re-checked', () {
      final progress = LevelProgress();
      progress.markWon('b');
      expect(isLevelUnlocked(1, levels, progress), isTrue);
    });
  });
}
