import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flame/components.dart';

import 'components/no_fly_zone.dart';
import 'components/planet.dart';
import 'components/rocket.dart';
import 'components/target.dart';
import 'components/wind_zone.dart';
import 'components/wormhole.dart';
import 'levels/level.dart';
import 'levels/levels.dart';
import 'physics/collision.dart';
import 'progress.dart';

enum GameStatus { ready, launched, won, lost }

enum LoseReason { crash, outOfBounds, noFlyZone, outOfFuel }

/// Top-level Flame game for one level: builds the planets/target/rocket
/// from a [LevelData], drives the launch, and arbitrates win/lose so those
/// rules live in exactly one place instead of being scattered across
/// components.
class GravityRocketGame extends FlameGame {
  GravityRocketGame({required this.level});

  /// The level currently being played. Mutable so [loadLevel] can swap in
  /// a new [LevelData] on an already-running game instance instead of the
  /// caller having to construct a whole new [GravityRocketGame].
  LevelData level;

  GameStatus status = GameStatus.ready;
  LoseReason? loseReason;

  /// Number of real launches taken on the current run (since the level was
  /// loaded, or since the last win). Drives [starsForShotCount] on the win
  /// overlay.
  int shotCount = 0;

  late Rocket rocket;

  /// All targets the rocket must reach to win this level (see
  /// [LevelData.targets]). One [Target] component per entry.
  late List<Target> targets;

  /// The primary (first) target. Kept for the common single-target case
  /// and any code that only cares about one target.
  Target get target => targets.first;

  final Set<int> _hitTargetIndices = {};

  /// All linked wormhole pairs in [level] (see [LevelData.wormholes]).
  late List<WormholePair> _wormholePairs;

  /// Counts down after a teleport so the rocket can't immediately re-enter
  /// the exit end (which would otherwise bounce it straight back through
  /// on the very next frame) before it has flown clear.
  double _wormholeCooldown = 0;
  static const double _wormholeCooldownSeconds = 0.3;

  /// The `power`/`angleOffset` most recently passed to [launch], remembered
  /// so [retrySameShot] can repeat an attempt exactly without the player
  /// having to re-aim and re-charge. Null until the first real launch.
  double? lastLaunchPower;
  double? lastLaunchAngleOffset;

  /// How far outside the nominal play bounds the rocket is allowed to
  /// stray before the run is judged lost, to avoid a harsh cutoff right
  /// at the edge of the visible area.
  static const double _outOfBoundsMargin = 60;

  @override
  Color backgroundColor() => const Color(0xFF04061A);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _buildLevel();
  }

  /// Builds the camera framing and all of [level]'s components (planets,
  /// no-fly zones, target, rocket) into [world]. Shared by [onLoad] (first
  /// level) and [loadLevel] (swapping to a later level in-place) so the two
  /// never drift apart.
  void _buildLevel() {
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
          isRepulsor: planetSpec.mass < 0,
          motion: planetSpec.motion,
        ),
      );
    }

    for (final zoneSpec in level.noFlyZones) {
      world.add(
        NoFlyZone(position: zoneSpec.position, radius: zoneSpec.radius),
      );
    }

    for (final windZoneSpec in level.windZones) {
      world.add(
        WindZone(
          position: windZoneSpec.position,
          radius: windZoneSpec.radius,
          forceDirectionRad: _degToRad(windZoneSpec.forceDirectionDeg),
          forceMagnitude: windZoneSpec.forceMagnitude,
        ),
      );
    }

    targets = [
      for (final targetSpec in level.targets)
        Target(position: targetSpec.position, radius: targetSpec.radius),
    ];
    for (final t in targets) {
      world.add(t);
    }
    _hitTargetIndices.clear();

    _wormholePairs = [
      for (final spec in level.wormholes) WormholePair(spec),
    ];
    for (final pair in _wormholePairs) {
      world.add(pair.endA);
      world.add(pair.endB);
    }
    _wormholeCooldown = 0;

    rocket = Rocket(
      position: level.rocketStart.clone(),
      initialFacingAngleRad: _degToRad(level.baseLaunchAngleDeg),
      steerRangeRad: _degToRad(level.launchAngleRangeDeg),
    );
    world.add(rocket);
  }

  /// Swaps the running game over to [newLevel] in place, without pushing a
  /// new route or rebuilding the [GameWidget]/[GravityRocketGame] — this is
  /// what "Next Level" uses so advancing feels instant instead of paying
  /// for a full screen transition and a fresh [onLoad]. Tears down the
  /// current level's components, rebuilds everything [_buildLevel] builds
  /// on first load, and resets run state to a fresh "ready" attempt,
  /// mirroring the state reset in [resetLevel].
  void loadLevel(LevelData newLevel) {
    world.removeAll(world.children.query<Planet>());
    world.removeAll(world.children.query<NoFlyZone>());
    world.removeAll(world.children.query<WindZone>());
    world.removeAll(targets);
    world.remove(rocket);
    for (final pair in _wormholePairs) {
      world.remove(pair.endA);
      world.remove(pair.endB);
    }

    level = newLevel;
    lastLaunchPower = null;
    lastLaunchAngleOffset = null;
    shotCount = 0;
    _buildLevel();

    status = GameStatus.ready;
    loseReason = null;
    _hitTargetIndices.clear();
    overlays.remove('WinOverlay');
    overlays.remove('LoseOverlay');
    overlays.remove('GameCompleteOverlay');
    resumeEngine();
  }

  /// Launches the rocket using [power] (0.0-1.0, mapped to the level's
  /// speed range) and [angleOffset] (-1.0-1.0, mapped to the level's
  /// steerable angle range around straight up).
  void launch({required double power, required double angleOffset}) {
    if (status != GameStatus.ready) {
      return;
    }

    final maxShots = level.maxShots;
    if (maxShots != null && shotCount >= maxShots) {
      // Every allowed shot has already been used on a previous attempt
      // (e.g. the player hit Retry after a loss) — refuse to launch again
      // rather than letting shotCount exceed the level's limit. The real
      // failure reason for each actual flight is still reported normally
      // by update(); outOfFuel specifically means "you tried to launch but
      // have none left."
      _lose(LoseReason.outOfFuel);
      return;
    }

    shotCount++;

    lastLaunchPower = power;
    lastLaunchAngleOffset = angleOffset;

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
    // A retry from an already-won state (e.g. WinOverlay's "Retry", to
    // try for a better star rating) starts a fresh shot count; an
    // ordinary mid-run loss-retry keeps accumulating so the count still
    // reflects total attempts-to-win.
    if (status == GameStatus.won) {
      shotCount = 0;
    }
    rocket.reset(
      startPosition: level.rocketStart.clone(),
      facingAngleRad: _degToRad(level.baseLaunchAngleDeg),
    );
    status = GameStatus.ready;
    loseReason = null;
    _hitTargetIndices.clear();
    _wormholeCooldown = 0;
    overlays.remove('WinOverlay');
    overlays.remove('LoseOverlay');
    overlays.remove('GameCompleteOverlay');
    resumeEngine();
  }

  /// Resets the level and immediately relaunches with the exact same
  /// `power`/`angleOffset` as the most recent [launch] call — a one-tap
  /// "repeat that attempt" fast path that skips re-aiming and re-charging.
  /// Only meaningful once at least one real launch has happened, which is
  /// always true by the time a lose overlay can be showing.
  void retrySameShot() {
    final power = lastLaunchPower;
    final angleOffset = lastLaunchAngleOffset;
    if (power == null || angleOffset == null) {
      return;
    }
    resetLevel();
    launch(power: power, angleOffset: angleOffset);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (status != GameStatus.launched) {
      return;
    }

    if (_allTargetsHit()) {
      _win();
      return;
    }

    if (_wormholeCooldown > 0) {
      _wormholeCooldown -= dt;
    } else {
      _checkWormholeTeleport();
    }

    if (_hasCrashed()) {
      _lose(LoseReason.crash);
      return;
    }

    if (_hasEnteredNoFlyZone()) {
      _lose(LoseReason.noFlyZone);
      return;
    }

    if (_isOutOfBounds()) {
      _lose(LoseReason.outOfBounds);
    }
  }

  bool _allTargetsHit() {
    for (var i = 0; i < targets.length; i++) {
      if (_hitTargetIndices.contains(i)) continue;
      final distance = (rocket.position - targets[i].position).length;
      if (distance <= targets[i].radius) {
        _hitTargetIndices.add(i);
      }
    }
    return _hitTargetIndices.length == targets.length;
  }

  /// Checks whether the rocket's most recent movement segment (see
  /// [Rocket.previousPosition]) crossed into either end of any wormhole
  /// pair, and if so teleports it to the paired exit and starts
  /// [_wormholeCooldown] so it can't immediately re-trigger by re-entering
  /// the exit end on the very next frame.
  void _checkWormholeTeleport() {
    for (final pair in _wormholePairs) {
      if (segmentIntersectsCircle(
        start: rocket.previousPosition,
        end: rocket.position,
        center: pair.endA.position,
        radius: pair.endA.radius,
      )) {
        rocket.teleport(pair.endB.position);
        _wormholeCooldown = _wormholeCooldownSeconds;
        return;
      }
      if (segmentIntersectsCircle(
        start: rocket.previousPosition,
        end: rocket.position,
        center: pair.endB.position,
        radius: pair.endB.radius,
      )) {
        rocket.teleport(pair.endA.position);
        _wormholeCooldown = _wormholeCooldownSeconds;
        return;
      }
    }
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

  bool _hasEnteredNoFlyZone() {
    for (final zone in world.children.query<NoFlyZone>()) {
      final hit = segmentIntersectsCircle(
        start: rocket.previousPosition,
        end: rocket.position,
        center: zone.position,
        radius: zone.radius,
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
    LevelProgress.instance.markWon(level.id);
    LevelProgress.instance.recordStars(level.id, starsForShotCount(shotCount));
    // Fires the one-shot win flash before the engine pauses, so its start
    // timestamp is captured at the exact instant of victory and the paused
    // frame reads as an impact rather than a dead stop. pauseEngine() and
    // overlays.add() below run back-to-back synchronously with nothing
    // awaited in between, so there's no artificial delay before the result
    // UI becomes visible.
    rocket.triggerWinFlash();
    pauseEngine();
    final isLastLevel =
        kLevels.indexWhere((l) => l.id == level.id) == kLevels.length - 1;
    overlays.add(isLastLevel ? 'GameCompleteOverlay' : 'WinOverlay');
  }

  void _lose(LoseReason reason) {
    status = GameStatus.lost;
    loseReason = reason;
    rocket.triggerCrashFlash();
    pauseEngine();
    overlays.add('LoseOverlay');
  }

  double _degToRad(double deg) => deg * math.pi / 180;
}

/// Maps shots-taken-to-win to a 1-3 star rating shown on the win
/// overlay: 1 shot = 3 stars, 2-3 shots = 2 stars, 4+ shots = 1 star.
int starsForShotCount(int shots) => shots <= 1 ? 3 : (shots <= 3 ? 2 : 1);
