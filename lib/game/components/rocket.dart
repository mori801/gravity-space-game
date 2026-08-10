import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../physics/gravity.dart';
import 'planet.dart';

/// The player-controlled rocket. Before launch it sits still at the level's
/// start position; after [launch] it is driven purely by the combined
/// gravity of every [Planet] in the same component tree, integrated with
/// semi-implicit Euler for stability.
class Rocket extends PositionComponent {
  Rocket({
    required Vector2 position,
    required double initialFacingAngleRad,
    double? steerRangeRad,
  })  : velocity = Vector2.zero(),
        _facingAngleRad = initialFacingAngleRad,
        _steerRangeRad = steerRangeRad,
        super(
          position: position,
          size: Vector2.all(36),
          anchor: Anchor.center,
        );

  static const int _maxTrailLength = 40;
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

  /// Called while the player drags to aim, with the resulting launch angle
  /// in radians (same convention as [_facingAngleRad]). Makes the aim
  /// arrow flash back to full visibility before it eases down to its
  /// resting visibility again.
  void setAim(double angleRad) {
    _aimAngleRad = angleRad;
    _aimOpacity = 1;
  }

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
    if (velocity.length2 > 0) {
      _facingAngleRad = math.atan2(velocity.y, velocity.x);
    }
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
    if (_aimAngleRad != null) {
      _aimOpacity = _aimRestingOpacity;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    if (_aimOpacity > _aimRestingOpacity) {
      _aimOpacity = (_aimOpacity - dt / _aimFadeDuration)
          .clamp(_aimRestingOpacity, 1.0);
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

    velocity.addScaled(acceleration, clampedDt);
    position.addScaled(velocity, clampedDt);

    if (velocity.length2 > 0) {
      _facingAngleRad = math.atan2(velocity.y, velocity.x);
    }

    _trail.add(position.clone());
    if (_trail.length > _maxTrailLength) {
      _trail.removeAt(0);
    }
  }

  @override
  void render(Canvas canvas) {
    _renderTrail(canvas);
    _renderLaunchPulse(canvas);
    if (!launched) {
      _renderSteerGuide(canvas);
    }
    _renderAim(canvas);
    _renderBody(canvas);
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
    for (final tickAngle in [base - range, base, base + range]) {
      final dir = Offset(math.cos(tickAngle), math.sin(tickAngle));
      canvas.drawLine(dir * (radius - 5), dir * (radius + 5), tickPaint);
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
      ..lineTo((headBase + perp * headWidth).dx, (headBase + perp * headWidth).dy)
      ..lineTo((headBase - perp * headWidth).dx, (headBase - perp * headWidth).dy)
      ..close();

    canvas.drawPath(
      headPath,
      Paint()
        ..color = _aimOutlineColor.withOpacity(displayOpacity * 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(headPath, Paint()..color = _aimColor.withOpacity(displayOpacity));
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

  void _renderTrail(Canvas canvas) {
    for (var i = 0; i < _trail.length; i++) {
      final worldPoint = _trail[i];
      final localPoint = worldPoint - position;
      final progress = (i + 1) / _trail.length;
      _trailPaint.color = _trailPaint.color.withOpacity(progress * 0.35);
      canvas.drawCircle(
        Offset(localPoint.x, localPoint.y),
        1.5 + progress * 1.5,
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
