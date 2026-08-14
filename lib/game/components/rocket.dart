import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../gravity_rocket_game.dart';
import '../physics/gravity.dart';
import '../physics/trajectory.dart';
import '../physics/wind.dart';
import 'planet.dart';
import 'wind_zone.dart';

/// The player-controlled rocket. Before launch it sits still at the level's
/// start position; after [launch] it is driven purely by the combined
/// gravity of every [Planet] in the same component tree, integrated with
/// semi-implicit Euler for stability.
class Rocket extends PositionComponent {
  Rocket({
    required Vector2 position,
    required double initialFacingAngleRad,
    double? steerRangeRad,
  }) : velocity = Vector2.zero(),
       _facingAngleRad = initialFacingAngleRad,
       _steerRangeRad = steerRangeRad,
       super(position: position, size: Vector2.all(36), anchor: Anchor.center);

  static const double _maxUpdateDt = 1 / 30;

  final Vector2 velocity;
  bool launched = false;

  /// Position at the start of the current frame's update, before gravity
  /// was applied. Used by the main game class to run a segment-vs-circle
  /// crash check that can't be fooled by tunneling through a planet
  /// between two frames.
  final Vector2 previousPosition = Vector2.zero();

  double _facingAngleRad;
  final List<Vector2> _trail = [];

  /// Current touch-drag aim direction. Flashes to full visibility on every
  /// [setAim] call, then eases down to a dim "resting" visibility instead
  /// of disappearing entirely — the aim is remembered (see [reset]) so a
  /// new attempt never has to jump back to some default angle.
  double? _aimAngleRad;
  double _aimOpacity = 0;
  static const double _aimFadeDuration = 0.6;
  // A plain 0.35 blended into some planet colours at a glance (level 3's
  // third planet is the exact same gold as the arrow). 0.42 plus the dark
  // outline stroke in [_renderAim] keeps the resting arrow legible over
  // every planet colour in `levels.dart`, not just the dark background.
  static const double _aimRestingOpacity = 0.42;
  static const double _aimArrowLength = 54;
  // How much longer the arrow grows at full charge, on top of
  // [_aimArrowLength] — makes "how far the power button is charged" and
  // "how far this arrow reaches" read as the same quantity.
  static const double _aimChargeGrowth = 26;

  static const Color _aimColor = Color(0xFFFFD24C);
  // Matches the game background (GravityRocketGame.backgroundColor) so it
  // reads as a soft shadow there, and as a legible contrast ring on top of
  // a bright or similarly-coloured planet.
  static const Color _aimOutlineColor = Color(0xFF04061A);

  static const Color _winFlashColor = Color(0xFF4CFFB0);
  static const Color _crashFlashColor = Color(0xFFFF4C4C);

  /// Half-width, in radians, of the angle range the player is allowed to
  /// steer within (mirrors `LevelData.launchAngleRangeDeg`). Purely
  /// cosmetic: draws a faint gauge arc around the rocket so the aim arrow
  /// reads as "a pointer confined to this range" (joystick/compass style)
  /// instead of a bare floating arrow. Null/zero draws nothing.
  final double? _steerRangeRad;

  final Paint _bodyPaint = Paint()..color = const Color(0xFFFFFFFF);
  final Paint _trailPaint = Paint()..color = const Color(0xFFFFFFFF);

  /// Fraction (0..1) the power button is currently charged. Driving the
  /// arrow's brightness/length/glow from this is what visually ties the
  /// two-step "swipe to aim, then hold the corner button to charge"
  /// gesture together, instead of the two controls feeling unrelated.
  double _chargePower = 0;

  /// Local clock used only to animate the charge-ready flicker; unrelated
  /// to flight time.
  double _time = 0;

  /// Time since [launch] was last called; drives the expanding-ring pulse
  /// in [_renderLaunchPulse]. Starts "finished" so nothing renders before
  /// the first launch.
  double _launchPulseT = double.infinity;
  static const double _launchPulseDuration = 0.5;

  /// Wall-clock timestamp a one-shot win/crash result flash was triggered
  /// at, or null when none is active/pending. This is deliberately timed
  /// off the real clock instead of the game-time counters above (like
  /// [_launchPulseT], which only advances inside [update]): the game class
  /// calls [triggerWinFlash]/[triggerCrashFlash] immediately before
  /// `pauseEngine()`, which stops `update()` from running at all, so a
  /// game-time counter would never progress past its very first frame.
  /// `render()` keeps being invoked every frame even while the engine is
  /// paused (only the update loop halts — the paused canvas stays visible
  /// and painted behind the win/lose overlay), so a wall-clock check inside
  /// [_renderResultFlash] animates correctly regardless of pause state.
  DateTime? _resultFlashStartedAt;
  bool _resultFlashIsWin = false;
  static const Duration _resultFlashDuration = Duration(milliseconds: 380);

  /// Called by [GravityRocketGame._win] at the instant the level is won,
  /// right before it pauses the engine, so the flash's start time is
  /// captured before rendering freezes on the final frame.
  void triggerWinFlash() {
    _resultFlashStartedAt = DateTime.now();
    _resultFlashIsWin = true;
  }

  /// Called by [GravityRocketGame._lose] at the instant the level is lost
  /// (crash or out-of-bounds), right before it pauses the engine.
  void triggerCrashFlash() {
    _resultFlashStartedAt = DateTime.now();
    _resultFlashIsWin = false;
  }

  /// Called while the player drags to aim, with the resulting launch angle
  /// in radians (same convention as [_facingAngleRad]). Makes the aim
  /// arrow flash back to full visibility before it eases down to its
  /// resting visibility again.
  void setAim(double angleRad) {
    _aimAngleRad = angleRad;
    _aimOpacity = 1;
  }

  /// Exposes [_aimAngleRad] for widget tests that need to assert keyboard
  /// steering actually moved the aim, without making the field itself
  /// public.
  @visibleForTesting
  double? get aimAngleRadForTest => _aimAngleRad;

  /// Called continuously while the player holds the power button, with the
  /// current charge fraction (0..1). See [_chargePower].
  void setCharge(double power) {
    _chargePower = power.clamp(0.0, 1.0);
  }

  /// Sets the rocket in motion with the given initial velocity. Call
  /// [reset] first if the rocket has already flown this level once.
  void launch(Vector2 initialVelocity) {
    velocity.setFrom(initialVelocity);
    previousPosition.setFrom(position);
    launched = true;
    _trail.clear();
    // Hide the arrow while flying, but keep the remembered angle so the
    // next attempt (reset) can bring it straight back without a jump.
    _aimOpacity = 0;
    _chargePower = 0;
    _launchPulseT = 0;
    _resultFlashStartedAt = null;
    if (velocity.length2 > 0) {
      _facingAngleRad = math.atan2(velocity.y, velocity.x);
    }
  }

  /// Instantly moves the rocket to [newPosition] (e.g. a wormhole exit),
  /// keeping its current velocity. Also snaps [previousPosition] to match,
  /// so the very next frame's segment-vs-circle crash check doesn't see a
  /// long spurious segment spanning the teleport.
  void teleport(Vector2 newPosition) {
    position.setFrom(newPosition);
    previousPosition.setFrom(newPosition);
  }

  /// Returns the rocket to [startPosition], stationary and facing
  /// [facingAngleRad], ready to be launched again. The last aim direction
  /// (if any) is intentionally kept as-is, at resting visibility, so a
  /// retry doesn't snap the aim to a different angle.
  void reset({required Vector2 startPosition, required double facingAngleRad}) {
    position.setFrom(startPosition);
    previousPosition.setFrom(startPosition);
    velocity.setZero();
    launched = false;
    _facingAngleRad = facingAngleRad;
    _trail.clear();
    // Charge is a transient interaction state (unlike the remembered aim
    // angle) — a retry should never start with a "pre-charged" arrow.
    _chargePower = 0;
    _resultFlashStartedAt = null;
    if (_aimAngleRad != null) {
      _aimOpacity = _aimRestingOpacity;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    if (_aimOpacity > _aimRestingOpacity) {
      _aimOpacity = (_aimOpacity - dt / _aimFadeDuration).clamp(
        _aimRestingOpacity,
        1.0,
      );
    }

    if (_launchPulseT < _launchPulseDuration) {
      _launchPulseT += dt;
    }

    if (!launched) {
      return;
    }

    final clampedDt = dt > _maxUpdateDt ? _maxUpdateDt : dt;
    previousPosition.setFrom(position);

    final planets = parent?.children.query<Planet>() ?? const <Planet>[];
    final sources = [
      for (final planet in planets)
        GravitySource(position: planet.position, mass: planet.mass),
    ];

    final acceleration = gravitationalAcceleration(
      objectPosition: position,
      sources: sources,
    );

    final windZones = parent?.children.query<WindZone>() ?? const <WindZone>[];
    final windSources = [
      for (final zone in windZones)
        WindZoneSource(
          position: zone.position,
          radius: zone.radius,
          acceleration: zone.acceleration,
        ),
    ];
    acceleration.add(
      totalWindAcceleration(objectPosition: position, sources: windSources),
    );

    velocity.addScaled(acceleration, clampedDt);
    position.addScaled(velocity, clampedDt);

    if (velocity.length2 > 0) {
      _facingAngleRad = math.atan2(velocity.y, velocity.x);
    }

    _trail.add(position.clone());
  }

  @override
  void render(Canvas canvas) {
    _renderTrail(canvas);
    _renderLaunchPulse(canvas);
    if (!launched) {
      _renderSteerGuide(canvas);
      _renderTrajectoryPreview(canvas);
    }
    _renderAim(canvas);
    _renderBody(canvas);
    _renderResultFlash(canvas);
  }

  /// Faint dashed arc spanning the steerable angle range, with tick marks
  /// at both boundaries and at the default heading. Only shown pre-launch
  /// (while [_facingAngleRad] is guaranteed to equal the level's base
  /// launch angle — nothing else changes it before [launch] is called).
  /// This is what turns the aim arrow into an at-a-glance "gauge" instead
  /// of a bare arrow: the ends of the arc are a hard visual limit on how
  /// far a swipe can turn it, and the center tick marks the default
  /// no-input heading.
  void _renderSteerGuide(Canvas canvas) {
    final range = _steerRangeRad;
    if (range == null || range <= 0) {
      return;
    }

    final base = _facingAngleRad;
    final radius = size.x / 2 + 6 + _aimArrowLength * 0.55;
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);

    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.18);

    const dashCount = 18;
    final sweep = range * 2;
    final dashSweep = sweep / dashCount * 0.6;
    final gapSweep = sweep / dashCount - dashSweep;
    var angle = base - range;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, angle, dashSweep, false, guidePaint);
      angle += dashSweep + gapSweep;
    }

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.3);
    // At range >= 180°, `base - range` and `base + range` land on the same
    // point (directly opposite `base`), so a "boundary" tick there would
    // be redundant and misleadingly suggest a hard edge that doesn't
    // exist — the full ring already communicates "steer anywhere". Only
    // draw the two boundary ticks for a genuinely bounded arc.
    final tickAngles = range < math.pi
        ? [base - range, base, base + range]
        : [base];
    for (final tickAngle in tickAngles) {
      final dir = Offset(math.cos(tickAngle), math.sin(tickAngle));
      canvas.drawLine(dir * (radius - 5), dir * (radius + 5), tickPaint);
    }
  }

  /// Fallback launch-speed range used only if this rocket somehow isn't
  /// parented under a [GravityRocketGame] (e.g. a bare unit test) when
  /// [_renderTrajectoryPreview] runs, so the preview still draws something
  /// plausible instead of crashing. In the real app [findGame] always
  /// resolves to the owning [GravityRocketGame], whose `level.minLaunchSpeed`
  /// / `level.maxLaunchSpeed` are used instead — see [_renderTrajectoryPreview].
  static const double _fallbackMinLaunchSpeed = 200;
  static const double _fallbackMaxLaunchSpeed = 500;

  /// Integration resolution for the preview. Kept small (same as the real
  /// flight's dt) so the curve's shape — how sharply the nearest planet
  /// bends it — stays accurate even though the preview is cut short well
  /// before the real flight would be (see [_previewMaxPathLength]).
  static const double _previewDt = 1 / 60;

  /// Path-length budget for the preview, in world units: the forecast stops
  /// appending points once the cumulative length of the sampled polyline
  /// would exceed this, regardless of how many steps that took. A fixed
  /// *step* count was the wrong knob — a fully-charged shot covers far more
  /// ground per step than a barely-charged one, so the same step count
  /// reveals wildly different amounts of the flight depending on charge
  /// (including, on many levels, enough to see the shot land in the target
  /// before firing). Capping by arc length instead shows a consistent
  /// amount of curve regardless of speed.
  ///
  /// 200 world units is picked from the game's own scale: planets are
  /// 40-60 units in radius, the target is ~55-58, and planets are placed
  /// 220+ units apart on generated levels (see `levels.dart`). 200 units is
  /// therefore a bit less than one planet-spacing — enough arc to read the
  /// launch direction and how the nearest planet starts to bend it, but
  /// nowhere near enough to reach a target or reveal the outcome.
  static const double _previewMaxPathLength = 200;

  /// Upper bound on integration steps for the preview. Must be large enough
  /// that even the weakest possible shot (`level.minLaunchSpeed`, the
  /// slowest a rocket can ever launch — 200 world units/sec is the lowest
  /// value used across `levels.dart`, matching [_fallbackMinLaunchSpeed])
  /// can still cover the full [_previewMaxPathLength] budget before running
  /// out of steps, rather than stopping short because `steps` was
  /// exhausted first (a slow shot travels less distance per step, so it
  /// needs *more* steps than a fast one to rack up the same path length).
  ///
  /// At minimum speed and with no gravity/wind, each step covers
  /// `minLaunchSpeed * dt` = `200 * (1/60)` ≈ 3.33 world units, so reaching
  /// the 200-unit budget takes `200 / 3.33` = 60 steps. Gravity can slow a
  /// shot down further (e.g. launched back toward a planet it started
  /// near), shrinking the per-step distance and pushing that number up, so
  /// this uses a 2x safety margin over the bare-minimum 60 steps. 180 was
  /// the old fixed step count (3 real-time seconds at 60 steps/sec); 120 is
  /// comfortably under that — cheaper to simulate — while still leaving
  /// slow shots plenty of headroom to fill the budget.
  static const int _previewSteps = 120;

  /// Faded dashed line forecasting the flight path the rocket would take
  /// if launched right now with the current aim angle ([_aimAngleRad]) and
  /// charge ([_chargePower]) — a pure planning aid, no gameplay effect.
  /// Only shown pre-launch, gated by the exact same `!launched` condition
  /// [_renderSteerGuide] is gated by in [render] (see the call site), so
  /// the two can never drift out of sync with each other.
  ///
  /// Mirrors two things exactly so the preview matches the real shot:
  ///  - the speed/angle formula `GravityRocketGame.launch` uses to turn
  ///    aim + charge into an initial velocity (recovering
  ///    `level.minLaunchSpeed`/`maxLaunchSpeed` via [findGame] since the
  ///    rocket itself doesn't otherwise hold a reference to the level);
  ///  - the same live gravity/wind source lookup [update] uses each frame
  ///    (`parent?.children.query<Planet>()` / `query<WindZone>()`), so the
  ///    preview is pulled by the same planets/wind the real flight will be.
  void _renderTrajectoryPreview(Canvas canvas) {
    final angle = _aimAngleRad;
    if (angle == null) {
      return;
    }

    final game = findGame();
    final level = game is GravityRocketGame ? game.level : null;
    final minSpeed = level?.minLaunchSpeed ?? _fallbackMinLaunchSpeed;
    final maxSpeed = level?.maxLaunchSpeed ?? _fallbackMaxLaunchSpeed;
    final speed = minSpeed + (maxSpeed - minSpeed) * _chargePower;

    final startVelocity = Vector2(math.cos(angle), math.sin(angle))
      ..scale(speed);

    final planets = (parent?.children.query<Planet>() ?? const <Planet>[])
        .toList();
    final windZones = (parent?.children.query<WindZone>() ?? const <WindZone>[])
        .toList();

    final points = simulateTrajectory(
      startPosition: position,
      startVelocity: startVelocity,
      planets: planets,
      windZones: windZones,
      dt: _previewDt,
      steps: _previewSteps,
      maxPathLength: _previewMaxPathLength,
    );

    final paint = Paint()
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round;

    final segmentCount = points.length - 1;
    for (var i = 0; i < segmentCount; i++) {
      // Skip every other segment for a dashed look, cheaper than tracking
      // sub-segment dash phase since each simulated step is already a
      // small, roughly-even-length hop.
      if (i.isOdd) {
        continue;
      }

      final t = segmentCount <= 1 ? 0.0 : i / (segmentCount - 1);
      final opacity = 0.5 + (0.05 - 0.5) * t;

      final start = points[i] - position;
      final end = points[i + 1] - position;
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawLine(Offset(start.x, start.y), Offset(end.x, end.y), paint);
    }
  }

  void _renderAim(Canvas canvas) {
    final angle = _aimAngleRad;
    final charging = _chargePower > 0;
    // While the power button is held, the arrow is forced fully bright
    // regardless of its resting fade — the two controls read as one.
    final displayOpacity = charging ? 1.0 : _aimOpacity;
    if (angle == null || displayOpacity <= 0) {
      return;
    }

    final dir = Offset(math.cos(angle), math.sin(angle));
    final perp = Offset(-dir.dy, dir.dx);
    final baseGap = size.x / 2 + 6;
    final length = _aimArrowLength + _chargePower * _aimChargeGrowth;
    final start = dir * baseGap;
    final end = dir * (baseGap + length);

    // Dark outline pass first so the gold stays legible even when it
    // crosses a bright or similarly-coloured planet (see _aimOutlineColor).
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = _aimOutlineColor.withOpacity(displayOpacity * 0.85)
        ..strokeWidth = charging ? 11 : 9
        ..strokeCap = StrokeCap.round,
    );

    // Dim "unfilled" shaft. While charging this sits at half strength so
    // the brighter fill segment below reads as progress along it.
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = _aimColor.withOpacity(displayOpacity * (charging ? 0.5 : 1.0))
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    if (charging) {
      // Bright fill growing from the rocket outward as the button is held
      // — the arrow doubles as a charge gauge pointed the way the shot
      // will go, like a slingshot's pull-back band aimed forward instead
      // of back.
      final fillEnd = start + dir * (length * _chargePower);
      canvas.drawLine(
        start,
        fillEnd,
        Paint()
          ..color = _aimColor.withOpacity(displayOpacity)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );

      // Soft glow at the tip that builds with charge, plus a quick
      // flicker once the shot is fully charged and ready to release.
      final ready = _chargePower >= 0.98;
      final flicker = ready ? 0.85 + 0.15 * math.sin(_time * 14) : 1.0;
      canvas.drawCircle(
        end,
        6 + _chargePower * 10,
        Paint()
          ..color = _aimColor.withOpacity(0.35 * _chargePower * flicker)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    final headScale = charging ? 1.0 + _chargePower * 0.35 : 1.0;
    final headLength = 14 * headScale;
    final headWidth = 8 * headScale;
    final headBase = end - dir * headLength;
    final headPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        (headBase + perp * headWidth).dx,
        (headBase + perp * headWidth).dy,
      )
      ..lineTo(
        (headBase - perp * headWidth).dx,
        (headBase - perp * headWidth).dy,
      )
      ..close();

    canvas.drawPath(
      headPath,
      Paint()
        ..color = _aimOutlineColor.withOpacity(displayOpacity * 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      headPath,
      Paint()..color = _aimColor.withOpacity(displayOpacity),
    );
  }

  /// A quick expanding-and-fading ring centered on the rocket, fired once
  /// per [launch]. Cheap "juice" that makes the moment of release read as
  /// a release of stored energy, echoing the charge-fill gauge drawn in
  /// [_renderAim] a split second earlier.
  void _renderLaunchPulse(Canvas canvas) {
    if (_launchPulseT >= _launchPulseDuration) {
      return;
    }

    final t = (_launchPulseT / _launchPulseDuration).clamp(0.0, 1.0);
    final radius = size.x * 0.5 + t * 46;
    final opacity = (1 - t) * 0.8;

    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = _aimOutlineColor.withOpacity(opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = _aimColor.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  /// One-shot radial burst drawn at the rocket's position the instant a run
  /// is won or lost (see [triggerWinFlash]/[triggerCrashFlash]), so the
  /// frame that freezes behind the win/lose overlay reads as an impact
  /// instead of a dead stop. Progress is computed from wall-clock elapsed
  /// time (see [_resultFlashStartedAt] for why), so it animates correctly
  /// across however many more times `render()` happens to be called after
  /// `pauseEngine()`, and still degrades gracefully to a single sensible
  /// frame if it were only called once.
  void _renderResultFlash(Canvas canvas) {
    final startedAt = _resultFlashStartedAt;
    if (startedAt == null) {
      return;
    }

    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    final durationMs = _resultFlashDuration.inMilliseconds;
    if (elapsedMs >= durationMs) {
      return;
    }

    final t = (elapsedMs / durationMs).clamp(0.0, 1.0);
    final color = _resultFlashIsWin ? _winFlashColor : _crashFlashColor;

    // Bright core flash, brightest at t=0 and quickly fading/blooming out.
    canvas.drawCircle(
      Offset.zero,
      size.x * (0.6 + t * 0.5),
      Paint()
        ..color = color.withOpacity((1 - t) * 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // Expanding ring that outruns the core, echoing _renderLaunchPulse.
    final ringRadius = size.x * 0.5 + t * 80;
    final ringOpacity = (1 - t) * 0.9;
    canvas.drawCircle(
      Offset.zero,
      ringRadius,
      Paint()
        ..color = color.withOpacity(ringOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawCircle(
      Offset.zero,
      ringRadius,
      Paint()
        ..color = Colors.white.withOpacity(ringOpacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// Draws the complete flown path (uncapped — see [update]) rather than
  /// only a recent window: a fixed-size window of the most recent
  /// [_trailFadeWindow] points gets the original brighter "near the
  /// rocket" emphasis for in-flight motion feedback, while every point
  /// keeps a modest constant baseline opacity so the whole trajectory
  /// stays clearly marked on screen long after a long flight ends —
  /// fading by *fractional position in the (now unbounded) list* would
  /// wash early points toward invisibility instead.
  static const int _trailFadeWindow = 40;

  void _renderTrail(Canvas canvas) {
    for (var i = 0; i < _trail.length; i++) {
      final worldPoint = _trail[i];
      final localPoint = worldPoint - position;
      final distanceFromEnd = _trail.length - 1 - i;
      final recency = (1 - distanceFromEnd / _trailFadeWindow).clamp(0.0, 1.0);
      final opacity = 0.18 + recency * 0.35;
      _trailPaint.color = _trailPaint.color.withOpacity(opacity);
      canvas.drawCircle(
        Offset(localPoint.x, localPoint.y),
        1.5 + recency * 1.5,
        _trailPaint,
      );
    }
  }

  void _renderBody(Canvas canvas) {
    canvas.save();
    canvas.rotate(_facingAngleRad);

    final halfWidth = size.x / 2;
    final halfHeight = size.y / 2;
    final path = Path()
      ..moveTo(halfWidth, 0)
      ..lineTo(-halfWidth, -halfHeight * 0.6)
      ..lineTo(-halfWidth, halfHeight * 0.6)
      ..close();

    canvas.drawPath(path, _bodyPaint);
    canvas.restore();
  }
}
