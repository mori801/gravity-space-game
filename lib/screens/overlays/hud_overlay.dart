import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../game/gravity_rocket_game.dart';
import '../../game/levels/levels.dart';
import '../../game/settings.dart';

/// Pre-launch: drag anywhere on screen to aim (a fading arrow on the
/// rocket briefly shows the resulting direction), then press and hold the
/// power button in the corner to charge the shot and release to launch.
/// Post-launch: shows a single pause button.
///
/// The whole control scheme is meant to be learnable without reading a
/// word: the first time this overlay appears in a given app run, a faint
/// wordless "ghost" demo loops in the background — a touch icon wiggling
/// left/right to mime a swipe, followed by a pulse on the power button's
/// own charge ring — until the player's first real touch, at which point
/// it fades out for good. See [_tutorialShownThisSession] for the exact
/// scope of "for good".
class HudOverlay extends StatefulWidget {
  const HudOverlay({super.key, required this.game});

  final GravityRocketGame game;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> with TickerProviderStateMixin {
  static const _chargeDuration = Duration(milliseconds: 1200);
  static const _minLaunchPower = 0.15;

  /// Whether the wordless onboarding demo has already played during this
  /// app run. Scoped per *app session*, not per level: the control scheme
  /// is identical on every level, so replaying the demo each time a new
  /// level loads would be repetitive for a player who already showed —
  /// by touching the screen at all in level 1 — that they've got it.
  /// `static` so it also covers retries within a level for free, and
  /// survives leaving a level and re-entering it, with no extra
  /// bookkeeping. A fresh app launch naturally resets it.
  static bool _tutorialShownThisSession = false;

  static const Duration _tutorialCycleDuration = Duration(milliseconds: 3600);

  double _angleOffset = 0;
  bool _leftHanded = false;

  late final AnimationController _powerController;

  /// Fires a quick "pop then settle" kick on the power button at the
  /// moment of launch, echoing the rocket's own launch-pulse ring.
  late final AnimationController _kickController;
  late final Animation<double> _kickScale;

  /// Drives the looping ghost-demo animation. Only ticks while the demo
  /// is actually being shown (see [_tutorialMounted]).
  late final AnimationController _tutorialLoopController;

  /// Whether the ghost-demo widgets are built at all. Starts true only
  /// for the first HUD of the app run; flips false for good once its
  /// fade-out finishes.
  late bool _tutorialMounted;

  /// Target opacity for the ghost demo; animated via [AnimatedOpacity].
  /// Set to false the instant the player makes a real gesture.
  bool _tutorialVisible = false;

  /// Which arrow/A-D steer key(s) are currently held down. Driven by
  /// [_KeyboardControls]' key-down/key-up callbacks; [_steerTicker] reads
  /// this every frame while non-empty to apply continuous steering, so
  /// holding a key feels like a held drag rather than a single nudge per
  /// keystroke.
  final Set<LogicalKeyboardKey> _heldSteerKeys = {};

  /// Tracks whether Space is currently held, to collapse the OS's repeated
  /// key-down events for a held key into a single [_startCharging] call.
  /// See [_handleKeyEvent].
  bool _spaceHeld = false;

  /// Advances steering by one [_adjustAim] step per frame for every held
  /// arrow/A-D key, only while the game is in [GameStatus.ready] (the
  /// same state the on-screen aim/charge UI is shown in). Stopped/started
  /// as keys are pressed/released rather than left running idle, since a
  /// `Ticker` still costs a frame callback registration while active.
  late final Ticker _steerTicker;

  @override
  void initState() {
    super.initState();
    _steerTicker = createTicker((_) {
      if (_heldSteerKeys.contains(LogicalKeyboardKey.arrowLeft) ||
          _heldSteerKeys.contains(LogicalKeyboardKey.keyA)) {
        _steerLeft();
      }
      if (_heldSteerKeys.contains(LogicalKeyboardKey.arrowRight) ||
          _heldSteerKeys.contains(LogicalKeyboardKey.keyD)) {
        _steerRight();
      }
    });
    _powerController = AnimationController(
      vsync: this,
      duration: _chargeDuration,
    );
    _kickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
    _kickScale = Tween<double>(begin: 1.22, end: 1.0).animate(
      CurvedAnimation(parent: _kickController, curve: Curves.easeOutBack),
    );

    _tutorialLoopController = AnimationController(
      vsync: this,
      duration: _tutorialCycleDuration,
    );
    _tutorialMounted = !_tutorialShownThisSession;
    if (_tutorialMounted) {
      // Claim it immediately (not on dismiss) so that if this overlay is
      // ever rebuilt from scratch while the demo is still visible, a
      // second copy never starts stacking on top of it.
      _tutorialShownThisSession = true;
      _tutorialVisible = true;
      _tutorialLoopController.repeat();
    }
  }

  @override
  void dispose() {
    _steerTicker.dispose();
    _powerController.dispose();
    _kickController.dispose();
    _tutorialLoopController.dispose();
    super.dispose();
  }

  /// Pixels of horizontal swipe needed to sweep the full -1..1 angle
  /// range. Deliberately not tied to screen width: the angle only moves
  /// relative to how far you swipe, never jumps to an absolute touch
  /// position, so it can never snap away from wherever it was left.
  ///
  /// Tuned for a one-handed thumb swipe on a roughly 350-430px-wide phone
  /// screen: a relaxed thumb arc without repositioning your grip covers
  /// about 180-260px, so 260px lets a single natural swipe reach full
  /// deflection while still requiring deliberate travel.
  static const double _dragPixelsForFullSweep = 260;
  static const double _dragSensitivity = 2.0 / _dragPixelsForFullSweep;

  /// Visual (drawn) size of the power button.
  static const double _powerButtonVisualSize = 72;

  /// Extra invisible margin added around the visible circle so the tap
  /// target is comfortably bigger than what's drawn. 16px on every side
  /// turns the 72px circle into a ~104px square hit box — comfortably
  /// above the ~44-48px minimum recommended touch target and forgiving
  /// of an imprecise thumb hit near the rim, which is exactly where most
  /// missed presses land.
  static const double _powerButtonHitPadding = 16;

  /// Baseline distance from the screen corner, inside SafeArea. Bumped
  /// further at runtime if the platform reports a system gesture inset
  /// (e.g. an edge back-swipe strip) wider than this, so a thumb press
  /// near the button's outer edge can't get hijacked by the OS instead
  /// of the game.
  static const double _powerButtonEdgeMargin = 24;

  static const _lowChargeColor = Color(0xFF4FC3F7);
  static const _midChargeColor = Color(0xFFFFD24C);
  static const _highChargeColor = Color(0xFFFF5252);

  /// Charge-level color ramp: cool at low charge, through the game's own
  /// gold around mid-charge, to a hot red-orange once nearly maxed. Gives
  /// an at-a-glance read of power level without a numeric readout, and
  /// the shift toward "hot" as charge nears 100% doubles as a highly
  /// visible "about to release at full power" cue.
  Color _chargeColor(double power) {
    if (power < 0.5) {
      return Color.lerp(_lowChargeColor, _midChargeColor, power / 0.5)!;
    }
    return Color.lerp(_midChargeColor, _highChargeColor, (power - 0.5) / 0.5)!;
  }

  void _adjustAim(double dxDelta) {
    _dismissTutorial();
    setState(() {
      _angleOffset =
          (_angleOffset + dxDelta * _dragSensitivity).clamp(-1.0, 1.0);
    });

    final level = widget.game.level;
    final angleDeg =
        level.baseLaunchAngleDeg + _angleOffset * level.launchAngleRangeDeg;
    widget.game.rocket.setAim(angleDeg * math.pi / 180);
  }

  /// One arrow-key/A-D "tick" worth of steering, expressed in the same
  /// pixel-delta units [_adjustAim] already accepts from mouse/touch drag
  /// — reusing that exact math is what keeps keyboard, mouse, and touch
  /// steering indistinguishable to the rocket. Tuned so holding the key
  /// sweeps the full -1..1 range in under a second at [_steerTicker]'s
  /// per-frame (~60Hz) rate.
  static const double _keyboardStepPixels = 10;

  void _steerLeft() => _adjustAim(-_keyboardStepPixels);

  void _steerRight() => _adjustAim(_keyboardStepPixels);

  /// Routes a raw keyboard event to steering/charging, mirroring the
  /// touch/mouse gestures below: arrow keys / A-D hold-to-steer via
  /// [_steerTicker], Space hold-to-charge via the same
  /// [_startCharging]/[_release] the on-screen power button calls. Ignores
  /// anything else so unrelated keys (e.g. browser devtools shortcuts)
  /// pass through untouched. Only active while [GameStatus.ready] — the
  /// same state the aim/charge UI itself is shown in — so a key held from
  /// a previous attempt can't "steer" a rocket that's already flying.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.game.status != GameStatus.ready) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final steerKeys = {
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyD,
    };
    if (steerKeys.contains(key)) {
      if (event is KeyDownEvent) {
        if (_heldSteerKeys.add(key) && !_steerTicker.isActive) {
          _steerTicker.start();
        }
      } else if (event is KeyUpEvent) {
        _heldSteerKeys.remove(key);
        if (_heldSteerKeys.isEmpty) {
          _steerTicker.stop();
        }
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      // Guards against the OS sending repeated KeyDownEvents while a key
      // stays physically held (no `.repeat` flag exists on this event
      // type to check instead) — without this, each repeat would restart
      // `_powerController` from 0, so the charge could never progress
      // past whatever a single repeat interval allows.
      if (event is KeyDownEvent && !_spaceHeld) {
        _spaceHeld = true;
        _startCharging();
      } else if (event is KeyUpEvent) {
        _spaceHeld = false;
        _release();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _startCharging() {
    _dismissTutorial();
    GameSettings.instance.selectionClick();
    _powerController.forward(from: 0);
  }

  void _release() {
    final power = _powerController.value.clamp(_minLaunchPower, 1.0);
    _powerController.stop();
    GameSettings.instance.mediumImpact();
    // `game.status` is a plain field, not a ValueNotifier/ChangeNotifier —
    // Flame's GameWidget only rebuilds overlay widgets when the active
    // overlay *set* changes (via overlays.add/remove) or when this
    // widget's own State is told to rebuild, never automatically on a
    // per-frame basis. launch() doesn't touch overlays.add/remove, so
    // without this setState this build() would keep showing the
    // pre-launch aim/charge UI instead of switching to the in-flight view.
    setState(() {
      widget.game.launch(power: power, angleOffset: _angleOffset);
    });
    _kickController.forward(from: 0);
    // Snap the ring/arrow charge back to 0 immediately instead of leaving
    // it frozen at the released value (the controller won't otherwise
    // notify listeners again until the next charge starts, which would
    // otherwise make a retried level start with a stale "charged" look).
    _powerController.value = 0;
  }

  /// Ends the ghost demo for the rest of the app session. Safe to call
  /// repeatedly — no-ops once already dismissed.
  void _dismissTutorial() {
    if (!_tutorialVisible) {
      return;
    }
    setState(() => _tutorialVisible = false);
    _tutorialLoopController.stop();
  }

  /// Linear progress through the sub-window [start, end] of the looping
  /// controller's 0..1 value, clamped to 0..1 outside that window.
  double _phase(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  /// Fades a phase's opacity in over its first 15% and out over its last
  /// 15%, full strength in between. Keeps every beat of the ghost demo
  /// from popping abruptly in/out.
  double _edgeFade(double phaseProgress) {
    const fadeIn = 0.15;
    const fadeOut = 0.85;
    if (phaseProgress <= 0 || phaseProgress >= 1) return 0;
    if (phaseProgress < fadeIn) return phaseProgress / fadeIn;
    if (phaseProgress > fadeOut) return (1 - phaseProgress) / (1 - fadeOut);
    return 1;
  }

  /// Builds one frame of the wordless ghost demo: first a touch icon
  /// wiggles left/right over a faint double-headed-arrow glyph (miming
  /// "swipe here to aim"), then — after a short gap — the power button's
  /// own charge ring fills up under a touch icon (miming "press and hold
  /// here"), then the cycle loops. Timed as fractions of one full
  /// [_tutorialLoopController] cycle. Mirrors [_leftHanded] so the demo
  /// always points at wherever the real button currently is.
  Widget _buildTutorialGhost() {
    final t = _tutorialLoopController.value;

    final swipeProgress = _phase(t, 0.00, 0.42);
    final swipeOpacity = _edgeFade(swipeProgress);
    final swipeDx = 60 * math.sin(2 * math.pi * swipeProgress);

    final holdProgress = _phase(t, 0.50, 0.92);
    final holdOpacity = _edgeFade(holdProgress);
    final chargeProgress =
        Curves.easeIn.transform(_phase(t, 0.54, 0.88).clamp(0.0, 1.0));

    return Stack(
      children: [
        Center(
          child: Opacity(
            opacity: swipeOpacity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.swap_horiz,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
                Transform.translate(
                  offset: Offset(swipeDx, 0),
                  child: const Icon(
                    Icons.touch_app,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: _leftHanded ? null : 24,
          left: _leftHanded ? 24 : null,
          bottom: 24,
          child: SafeArea(
            child: Opacity(
              opacity: holdOpacity,
              child: SizedBox(
                width: _powerButtonVisualSize,
                height: _powerButtonVisualSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: chargeProgress,
                      strokeWidth: 4,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFFFD24C),
                      ),
                    ),
                    const Icon(
                      Icons.touch_app,
                      size: 26,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Compact "N shots left" pill anchored to the top-center, shown only on
  /// levels that set a [LevelData.maxShots] budget. The vast majority of
  /// levels leave `maxShots` null, in which case this returns an empty
  /// [SizedBox] and those levels are visually unaffected. Purely a
  /// readout — it never mutates game state, so unlike the gesture
  /// handlers elsewhere in this file it needs no `setState` plumbing of
  /// its own to stay in sync; it just reflects whatever `build()` was
  /// last called with.
  Widget _buildShotsReadout(GravityRocketGame game) {
    final maxShots = game.level.maxShots;
    if (maxShots == null) {
      return const SizedBox.shrink();
    }
    final remaining = (maxShots - game.shotCount).clamp(0, maxShots);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_gas_station,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(
                  '$remaining shot${remaining == 1 ? '' : 's'} left',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Small, persistent, non-interactive readout of which tier/level the
  /// player is currently on, anchored top-left. Purely a readout (no
  /// `GestureDetector`) so it never competes for touches with the
  /// full-screen swipe-to-aim gesture area or the ready-branch handedness
  /// toggle it sits below. Shown across every [GravityRocketGame.status]
  /// branch of [build] so it stays visible for the whole play session, not
  /// just pre-launch.
  Widget _buildLevelLabel(GravityRocketGame game) {
    final tierTitle = tierTitleForLevel(game.level.id);
    final text =
        tierTitle != null ? '$tierTitle · ${game.level.name}' : game.level.name;
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 48, left: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPauseButton(GravityRocketGame game) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: IconButton.filled(
            icon: const Icon(Icons.pause),
            onPressed: () {
              game.pauseEngine();
              game.overlays.add('PauseMenu');
            },
          ),
        ),
      ),
    );
  }

  /// The corner button while the rocket is mid-flight: same footprint the
  /// power button occupies pre-launch (same position/handedness/size), but
  /// now a plain tap-to-reset action, so aborting a bad shot early doesn't
  /// require waiting for it to resolve into a win/lose.
  Widget _buildResetButton(GravityRocketGame game, double positionedOffset) {
    return Positioned(
      right: _leftHanded ? null : positionedOffset,
      left: _leftHanded ? positionedOffset : null,
      bottom: positionedOffset,
      child: SafeArea(
        child: Semantics(
          label: 'Reset level',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              GameSettings.instance.selectionClick();
              // See the comment in _release(): game.status doesn't notify
              // Flutter on its own, and resetLevel() mid-flight doesn't
              // touch overlays.add/remove either (neither WinOverlay nor
              // LoseOverlay is active to remove), so nothing would tell
              // this widget to rebuild and show the aim/charge UI again
              // without this explicit setState.
              setState(() {
                game.resetLevel();
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(_powerButtonHitPadding),
              child: Container(
                width: _powerButtonVisualSize,
                height: _powerButtonVisualSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.4),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    // Platforms reserve a strip along the screen edges for system
    // back-swipe gestures; SafeArea alone doesn't account for it. Keep
    // the corner button clear of that strip so a thumb press near its
    // outer rim can't be stolen by the OS instead of the game. Computed
    // up front so both the pre-launch power button and the mid-flight
    // reset button (which occupies the exact same spot) share it.
    final gestureInsets = MediaQuery.of(context).systemGestureInsets;
    final sideInset = _leftHanded ? gestureInsets.left : gestureInsets.right;
    final edgeMargin = math.max(_powerButtonEdgeMargin, sideInset + 8);
    // Positioned offset for the (padded) hit box: subtracting the hit
    // padding here keeps the *visible* circle at exactly `edgeMargin`
    // from the corner, while the invisible tap area extends further out
    // and further in than what's drawn.
    final positionedOffset = edgeMargin - _powerButtonHitPadding;

    final Widget statusContent;
    if (game.status == GameStatus.launched) {
      statusContent = Stack(
        children: [
          _buildPauseButton(game),
          _buildResetButton(game, positionedOffset),
          _buildShotsReadout(game),
        ],
      );
    } else if (game.status != GameStatus.ready) {
      // Won/lost: the result overlay is the primary interaction now, so
      // just the pause button remains, same as before.
      statusContent = _buildPauseButton(game);
    } else {
      statusContent = Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              label: 'Swipe to aim the rocket',
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanDown: (_) => _dismissTutorial(),
                onPanUpdate: (details) => _adjustAim(details.delta.dx),
              ),
            ),
          ),
          if (_tutorialMounted)
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _tutorialVisible ? 1 : 0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                onEnd: () {
                  if (!_tutorialVisible && _tutorialMounted) {
                    setState(() => _tutorialMounted = false);
                  }
                },
                child: AnimatedBuilder(
                  animation: _tutorialLoopController,
                  builder: (context, _) => _buildTutorialGhost(),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton(
                  icon: const Icon(Icons.swap_horiz, size: 20),
                  color: Colors.white.withOpacity(0.5),
                  tooltip: 'Bedienung links/rechts tauschen',
                  onPressed: () {
                    _dismissTutorial();
                    setState(() => _leftHanded = !_leftHanded);
                  },
                ),
              ),
            ),
          ),
          Positioned(
            right: _leftHanded ? null : positionedOffset,
            left: _leftHanded ? positionedOffset : null,
            bottom: positionedOffset,
            child: SafeArea(
              child: Semantics(
                label: 'Hold to charge power, release to launch',
                child: GestureDetector(
                  // Explicitly opaque so this exact padded square always
                  // wins the hit test outright and the full-screen
                  // swipe-to-aim detector underneath is never considered
                  // for a pointer that starts here — a press-and-hold on
                  // the button can't drift the aim angle from hand tremor,
                  // and a swipe merely passing over the button can't
                  // accidentally trigger it.
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _startCharging(),
                  onTapUp: (_) => _release(),
                  onTapCancel: _release,
                  child: Padding(
                    padding: const EdgeInsets.all(_powerButtonHitPadding),
                    child: AnimatedBuilder(
                      animation:
                          Listenable.merge([_powerController, _kickController]),
                      builder: (context, child) {
                        final power = _powerController.value;
                        // Continuously feed the charge level to the rocket
                        // so its aim arrow can grow/brighten/glow in
                        // lockstep with this button. Safe without an
                        // "isLoaded" guard: this only runs from inside the
                        // button's own AnimatedBuilder, which can only be
                        // rebuilding because the user already tapped the
                        // rendered button — by then `game.onLoad()` (which
                        // sets `rocket`) has necessarily already run, same
                        // as the pre-existing `rocket.setAim(...)` call in
                        // `_adjustAim` below.
                        widget.game.rocket.setCharge(power);
                        final ready = power >= 0.98;
                        final chargeColor = _chargeColor(power);
                        final iconColor =
                            Color.lerp(Colors.white, chargeColor, power)!;
                        // Continuous, subtle growth as charge builds, plus
                        // a distinct little "pop" once fully charged, on
                        // top of the release "kick" recoil.
                        final growScale =
                            1.0 + 0.06 * power + (ready ? 0.05 : 0.0);

                        return Transform.scale(
                          scale: growScale * _kickScale.value,
                          child: Container(
                            width: _powerButtonVisualSize,
                            height: _powerButtonVisualSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.4),
                              border: Border.all(
                                color: power > 0 ? chargeColor : Colors.white,
                                width: ready ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: chargeColor.withOpacity(
                                    0.12 + power * 0.38,
                                  ),
                                  blurRadius: 12 + power * 16,
                                  spreadRadius: power * 2,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: _powerButtonVisualSize,
                                  height: _powerButtonVisualSize,
                                  child: CircularProgressIndicator(
                                    value: power,
                                    strokeWidth: 4,
                                    backgroundColor: Colors.white24,
                                    valueColor: AlwaysStoppedAnimation(
                                      chargeColor,
                                    ),
                                  ),
                                ),
                                Transform.scale(
                                  scale: 1.0 + power * 0.15,
                                  child: Icon(
                                    Icons.rocket_launch,
                                    color: iconColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildShotsReadout(game),
        ],
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        children: [
          statusContent,
          _buildLevelLabel(game),
        ],
      ),
    );
  }
}
