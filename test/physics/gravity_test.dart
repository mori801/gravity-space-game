import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/physics/gravity.dart';
import 'package:vector_math/vector_math.dart';

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

      // vector_math's Vector2 is backed by Float32List, so a near-zero
      // cancellation carries float32 rounding error (~1.2e-6 here) well
      // above a float64-scale 1e-6 tolerance; 1e-4 comfortably covers that
      // while still catching a real (non-cancelling) miscalculation.
      expect(acceleration.x, closeTo(0, 1e-4));
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

    test('single negative-mass planet directly below pushes straight up', () {
      final acceleration = gravitationalAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [GravitySource(position: Vector2(0, 100), mass: -500)],
      );

      expect(acceleration.x, closeTo(0, 1e-9));

      final expectedMagnitude = kGravitationalConstant * 500 / (100 * 100);
      expect(acceleration.y, closeTo(-expectedMagnitude, 1e-6));
    });

    test(
      'negative-mass repulsion magnitude matches positive-mass attraction '
      'at the same distance',
      () {
        final attraction = gravitationalAcceleration(
          objectPosition: Vector2(0, 0),
          sources: [GravitySource(position: Vector2(0, 100), mass: 500)],
        );
        final repulsion = gravitationalAcceleration(
          objectPosition: Vector2(0, 0),
          sources: [GravitySource(position: Vector2(0, 100), mass: -500)],
        );

        expect(repulsion.x, closeTo(-attraction.x, 1e-6));
        expect(repulsion.y, closeTo(-attraction.y, 1e-6));
      },
    );

    test('positive and negative mass sources compose via vector addition', () {
      final attractorSource = GravitySource(
        position: Vector2(-100, 100),
        mass: 500,
      );
      final repulsorSource = GravitySource(
        position: Vector2(100, 50),
        mass: -300,
      );

      final combined = gravitationalAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [attractorSource, repulsorSource],
      );

      final fromAttractorOnly = gravitationalAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [attractorSource],
      );
      final fromRepulsorOnly = gravitationalAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [repulsorSource],
      );

      // As with the symmetric-cancellation test above, comparing a value
      // accumulated in one float32 Vector2 against the sum of two
      // independently-rounded float32 results carries rounding noise above
      // a float64-scale 1e-6 tolerance, so 1e-4 is used here too.
      expect(
        combined.x,
        closeTo(fromAttractorOnly.x + fromRepulsorOnly.x, 1e-4),
      );
      expect(
        combined.y,
        closeTo(fromAttractorOnly.y + fromRepulsorOnly.y, 1e-4),
      );
    });

    test('closer negative-mass planet repels harder (inverse-square falloff)',
        () {
      final near = gravitationalAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [GravitySource(position: Vector2(0, 50), mass: -500)],
      );
      final far = gravitationalAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [GravitySource(position: Vector2(0, 200), mass: -500)],
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
