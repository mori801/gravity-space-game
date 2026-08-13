import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/levels/level.dart';
import 'package:gravity_rocket_launcher/game/physics/motion.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('planetPositionAt', () {
    test('null motion returns basePosition unchanged', () {
      final base = Vector2(10, 20);
      final result = planetPositionAt(basePosition: base, motion: null, t: 5);
      expect(result.x, 10);
      expect(result.y, 20);
    });

    test('orbit motion at t=0 starts at center + (radius, 0)', () {
      final motion = OrbitMotion(
        center: Vector2(100, 100),
        radius: 50,
        angularSpeedRadPerSec: 1.0,
      );
      final result = planetPositionAt(
        basePosition: Vector2(150, 100),
        motion: motion,
        t: 0,
      );
      expect(result.x, closeTo(150, 1e-9));
      expect(result.y, closeTo(100, 1e-9));
    });

    test('orbit motion at quarter turn reaches the expected point', () {
      final motion = OrbitMotion(
        center: Vector2(0, 0),
        radius: 10,
        angularSpeedRadPerSec: math.pi / 2, // 90 deg/sec
      );
      final result = planetPositionAt(
        basePosition: Vector2(10, 0),
        motion: motion,
        t: 1, // 90 degrees traveled
      );
      expect(result.x, closeTo(0, 1e-9));
      expect(result.y, closeTo(10, 1e-9));
    });

    test('oscillate motion returns to basePosition at t=0', () {
      final motion = OscillateMotion(
        axis: Vector2(1, 0),
        amplitude: 40,
        periodSeconds: 2,
      );
      final result = planetPositionAt(
        basePosition: Vector2(100, 200),
        motion: motion,
        t: 0,
      );
      expect(result.x, closeTo(100, 1e-9));
      expect(result.y, closeTo(200, 1e-9));
    });

    test('oscillate motion reaches +amplitude at a quarter period', () {
      final motion = OscillateMotion(
        axis: Vector2(1, 0),
        amplitude: 40,
        periodSeconds: 4,
      );
      final result = planetPositionAt(
        basePosition: Vector2(0, 0),
        motion: motion,
        t: 1, // sin(2*pi*1/4) = sin(pi/2) = 1
      );
      expect(result.x, closeTo(40, 1e-9));
      expect(result.y, closeTo(0, 1e-9));
    });
  });
}
