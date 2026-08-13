import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/physics/wind.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('totalWindAcceleration', () {
    test('inside a zone applies its full acceleration', () {
      final result = totalWindAcceleration(
        objectPosition: Vector2(100, 100),
        sources: [
          WindZoneSource(
            position: Vector2(100, 100),
            radius: 50,
            acceleration: Vector2(200, 0),
          ),
        ],
      );
      expect(result.x, closeTo(200, 1e-9));
      expect(result.y, closeTo(0, 1e-9));
    });

    test('outside every zone contributes nothing', () {
      final result = totalWindAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [
          WindZoneSource(
            position: Vector2(1000, 1000),
            radius: 50,
            acceleration: Vector2(200, 0),
          ),
        ],
      );
      expect(result.x, 0);
      expect(result.y, 0);
    });

    test('exactly on the boundary counts as inside', () {
      final result = totalWindAcceleration(
        objectPosition: Vector2(150, 100),
        sources: [
          WindZoneSource(
            position: Vector2(100, 100),
            radius: 50,
            acceleration: Vector2(0, 300),
          ),
        ],
      );
      expect(result.y, closeTo(300, 1e-9));
    });

    test('overlapping zones push additively', () {
      final result = totalWindAcceleration(
        objectPosition: Vector2(0, 0),
        sources: [
          WindZoneSource(position: Vector2(0, 0), radius: 50, acceleration: Vector2(100, 0)),
          WindZoneSource(position: Vector2(0, 0), radius: 50, acceleration: Vector2(0, 50)),
        ],
      );
      expect(result.x, closeTo(100, 1e-9));
      expect(result.y, closeTo(50, 1e-9));
    });

    test('no sources yields zero acceleration', () {
      final result = totalWindAcceleration(objectPosition: Vector2(0, 0), sources: const []);
      expect(result.x, 0);
      expect(result.y, 0);
    });
  });
}
