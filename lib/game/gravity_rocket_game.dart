import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flame/components.dart';

import 'components/planet.dart';
import 'components/rocket.dart';
import 'components/target.dart';
import 'levels/level.dart';
import 'physics/collision.dart';

enum GameStatus { ready, launched, won, lost }

enum LoseReason { crash, outOfBounds }

/// Top-level Flame game for one level: builds the planets/target/rocket
/// from a [LevelData], drives the launch, and arbitrates win/lose so those
/// rules live in exactly one place instead of being scattered across
/// components.
class GravityRocketGame extends FlameGame {
  GravityRocketGame({required this.level});

  final LevelData level;

  GameStatus status = GameStatus.ready;
  LoseReason? loseReason;

  late final Rocket rocket;
  late final Target target;

  /// How far outside the nominal play bounds the rocket is allowed to
  /// stray before the run is judged lost, to avoid a harsh cutoff right
  /// at the edge of the visible area.
  static const double _outOfBoundsMargin = 60;

  @override
  Color backgroundColor() => const Color(0xFF04061A);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewfinder.visibleGameSize = Vector2(
      level.playBounds.width,
      level.playBounds.height,
    );
    camera.viewfinder.position = Vector2(
      level.playBounds.width / 2,
      level.playBounds.height / 2,
    );
    camera.viewfinder.anchor = Anchor.center;

    for (final planetSpec in level.planets) {
      world.add(
        Planet(
          position: planetSpec.position,
          radius: planetSpec.radius,
          mass: planetSpec.mass,
          color: planetSpec.color,
        ),
      );
    }

    target = Target(
      position: level.targetPosition,
      radius: level.targetRadius,
    );
    world.add(target);

    rocket = Rocket(
      position: level.rocketStart.clone(),
      initialFacingAngleRad: _degToRad(level.baseLaunchAngleDeg),
      steerRangeRad: _degToRad(level.launchAngleRangeDeg),
    );
    world.add(rocket);
  }

  /// Launches the rocket using [power] (0.0-1.0, mapped to the level's
  /// speed range) and [angleOffset] (-1.0-1.0, mapped to the level's
  /// steerable angle range around straight up).
  void launch({required double power, required double angleOffset}) {
    if (status != GameStatus.ready) {
      return;
    }

    final clampedPower = power.clamp(0.0, 1.0);
    final clampedAngleOffset = angleOffset.clamp(-1.0, 1.0);

    final speed = level.minLaunchSpeed +
        (level.maxLaunchSpeed - level.minLaunchSpeed) * clampedPower;
    final angleDeg = level.baseLaunchAngleDeg +
        clampedAngleOffset * level.launchAngleRangeDeg;
    final angleRad = _degToRad(angleDeg);

    final initialVelocity = Vector2(math.cos(angleRad), math.sin(angleRad))
      ..scale(speed);

    rocket.launch(initialVelocity);
    status = GameStatus.launched;
    loseReason = null;
  }

  /// Returns the rocket to its start position, ready to be launched again.
  void resetLevel() {
    rocket.reset(
      startPosition: level.rocketStart.clone(),
      facingAngleRad: _degToRad(level.baseLaunchAngleDeg),
    );
    status = GameStatus.ready;
    loseReason = null;
    overlays.remove('WinOverlay');
    overlays.remove('LoseOverlay');
    resumeEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (status != GameStatus.launched) {
      return;
    }

    if (_hasReachedTarget()) {
      _win();
      return;
    }

    if (_hasCrashed()) {
      _lose(LoseReason.crash);
      return;
    }

    if (_isOutOfBounds()) {
      _lose(LoseReason.outOfBounds);
    }
  }

  bool _hasReachedTarget() {
    final distance = (rocket.position - target.position).length;
    return distance <= target.radius;
  }

  bool _hasCrashed() {
    for (final planet in world.children.query<Planet>()) {
      final hit = segmentIntersectsCircle(
        start: rocket.previousPosition,
        end: rocket.position,
        center: planet.position,
        radius: planet.radius,
      );
      if (hit) {
        return true;
      }
    }
    return false;
  }

  bool _isOutOfBounds() {
    final bounds = level.playBounds.inflate(_outOfBoundsMargin);
    return !bounds.contains(Offset(rocket.position.x, rocket.position.y));
  }

  void _win() {
    status = GameStatus.won;
    pauseEngine();
    overlays.add('WinOverlay');
  }

  void _lose(LoseReason reason) {
    status = GameStatus.lost;
    loseReason = reason;
    pauseEngine();
    overlays.add('LoseOverlay');
  }

  double _degToRad(double deg) => deg * math.pi / 180;
}
