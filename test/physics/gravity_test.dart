import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/physics/gravity.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('gravitationalAcceleration', () {
    test('single planet directly below pulls straight down', () {
      final acceleration = gravitationalAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [GravitySource(position: Vector2(0, 100), mass: 500)],
      );

      expect(acceleration.x, closeTo(0, 1e-9));

      final expectedMagnitude = kGravitationalConstant * 500 / (100 * 100);
      expect(acceleration.y, closeTo(expectedMagnitude, 1e-6));
    });

    test('two symmetric planets cancel horizontal pull', () {
      final acceleration = gravitationalAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [
          GravitySource(position: Vector2(-100, 100), mass: 500),
          GravitySource(position: Vector2(100, 100), mass: 500),
        ],
      );

      expect(acceleration.x, closeTo(0, 1e-6));
      expect(acceleration.y, greaterThan(0));
    });

    test('closer planet pulls harder (inverse-square falloff)', () {
      final near = gravitationalAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [GravitySource(position: Vector2(0, 50), mass: 500)],
      );
      final far = gravitationalAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [GravitySource(position: Vector2(0, 200), mass: 500)],
      );

      expect(near.length, greaterThan(far.length));
    });

    test('no sources yields zero acceleration', () {
      final acceleration = gravitationalAcceleration(
        objectPosition: Vector2(10, 10),
        sources: const [],
      );

      expect(acceleration.x, 0);
      expect(acceleration.y, 0);
    });

    test('distance below the softening minimum is clamped', () {
      final atSoftening = gravitationalAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [
          GravitySource(position: Vector2(0, kSofteningDistance), mass: 500),
        ],
      );
      final insideSoftening = gravitationalAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [
          GravitySource(
            position: Vector2(0, kSofteningDistance / 2),
            mass: 500,
          ),
        ],
      );

      expect(insideSoftening.length, closeTo(atSoftening.length, 1e-6));
    });
  });
}
