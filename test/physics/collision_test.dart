import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/physics/collision.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('segmentIntersectsCircle', () {
    test('segment passing through the circle counts as a hit', () {
      final hit = segmentIntersectsCircle(
        start: Vector2(-100, 0),
        end: Vector2(100, 0),
        center: Vector2(0, 0),
        radius: 10,
      );
      expect(hit, isTrue);
    });

    test('segment passing outside the circle is a miss', () {
      final hit = segmentIntersectsCircle(
        start: Vector2(-100, 100),
        end: Vector2(100, 100),
        center: Vector2(0, 0),
        radius: 10,
      );
      expect(hit, isFalse);
    });

    test('segment starting inside the circle counts as a hit', () {
      final hit = segmentIntersectsCircle(
        start: Vector2(2, 2),
        end: Vector2(50, 50),
        center: Vector2(0, 0),
        radius: 10,
      );
      expect(hit, isTrue);
    });

    test('zero-length segment falls back to a point-distance check', () {
      final insideHit = segmentIntersectsCircle(
        start: Vector2(5, 0),
        end: Vector2(5, 0),
        center: Vector2(0, 0),
        radius: 10,
      );
      final outsideHit = segmentIntersectsCircle(
        start: Vector2(50, 0),
        end: Vector2(50, 0),
        center: Vector2(0, 0),
        radius: 10,
      );
      expect(insideHit, isTrue);
      expect(outsideHit, isFalse);
    });
  });
}
