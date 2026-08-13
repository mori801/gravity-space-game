# New Mechanics + Progress System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three new level mechanics (moving planets, wormholes, multi-target levels) and a local level-progress/unlock system with star ratings to the Gravity Rocket game.

**Architecture:** Extend the existing declarative `LevelData`/`PlanetSpec` schema with optional fields that default to today's behavior (zero changes to the 23 existing levels), add a pure-Dart `physics/motion.dart` module for deterministic planet motion, add a `shared_preferences`-backed `LevelProgress` class for unlock/star state, and wire win-condition/gravity/UI code to the new fields.

**Tech Stack:** Flutter/Dart, Flame 2D game engine, `shared_preferences` (new dependency), `flutter_test`/`flame_test`.

**Spec:** `docs/superpowers/specs/2026-08-13-mechanics-and-progress-design.md`

## Global Constraints

- Dart SDK `>=3.3.0 <4.0.0`, Flutter `>=3.19.0` (from `pubspec.yaml`) — don't use newer-only syntax.
- `flutter_lints: ^5.0.0` is active; every task's code must pass `flutter analyze` with zero issues before its commit.
- Physics logic stays pure Dart with no Flame/Flutter import, in `lib/game/physics/`; Flame components live in `lib/game/components/`; level content stays declarative in `lib/game/levels/`. Follow this split for all new files.
- No fuel system, no timers, no audio, no sprite/art replacement — explicitly out of scope (see spec "Motivation").
- All persistence goes through `shared_preferences` only, via `LevelProgress` (Task 2) — no other storage mechanism, no direct `SharedPreferences` calls outside that file.
- Multi-target levels win when all targets are hit, in any order.
- Star thresholds are fixed: 1 attempt → 3★, 2-3 attempts → 2★, 4+ attempts → 1★, implemented once as `starsForAttempts` in Task 2 and reused everywhere else — never redefined.
- A `PostToolUse` hook already runs `dart format` on every saved `.dart` file automatically; don't hand-format.
- Every new public class/member gets a doc comment, matching the existing style in `lib/game/levels/level.dart` and `lib/game/components/rocket.dart`.

---

### Task 1: Level schema foundation + planet motion math

**Files:**
- Modify: `lib/game/levels/level.dart`
- Create: `lib/game/physics/motion.dart`
- Test: `test/physics/motion_test.dart`

**Interfaces:**
- Produces (used by Tasks 4, 5, 6, 7, 8):
  - `sealed class PlanetMotion` with subtypes `OrbitMotion({required Vector2 center, required double radius, required double angularSpeedRadPerSec})` and `OscillateMotion({required Vector2 axis, required double amplitude, required double periodSeconds})`.
  - `PlanetSpec` gains `final PlanetMotion? motion` (optional, default `null`).
  - `class TargetSpec({required Vector2 position, required double radius})`.
  - `class WormholeSpec({required Vector2 a, required Vector2 b, required double radius})`.
  - `LevelData` gains `final List<TargetSpec> additionalTargets` (default `const []`) and `final List<WormholeSpec> wormholes` (default `const []`), plus a getter `List<TargetSpec> get targets` returning `[TargetSpec(position: targetPosition, radius: targetRadius), ...additionalTargets]`.
  - `Vector2 planetPositionAt({required Vector2 basePosition, required PlanetMotion? motion, required double t})` in `physics/motion.dart`.

- [ ] **Step 1: Write the failing test**

Create `test/physics/motion_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/physics/motion_test.dart`
Expected: FAIL — `physics/motion.dart` doesn't exist yet (import error), and `OrbitMotion`/`OscillateMotion` aren't defined in `level.dart` yet.

- [ ] **Step 3: Extend `lib/game/levels/level.dart`**

Add above the `PlanetSpec` class:

```dart
/// How a planet's position changes over time. Pure data — the actual
/// position computation lives in `physics/motion.dart` so it can be
/// unit-tested without depending on Flame or a running game loop.
sealed class PlanetMotion {
  const PlanetMotion();
}

/// Circular orbit around [center] at fixed [radius], moving at
/// [angularSpeedRadPerSec] radians/second (positive = counterclockwise in
/// screen space, where +y is down).
class OrbitMotion extends PlanetMotion {
  const OrbitMotion({
    required this.center,
    required this.radius,
    required this.angularSpeedRadPerSec,
  });

  final Vector2 center;
  final double radius;
  final double angularSpeedRadPerSec;
}

/// Linear back-and-forth motion along [axis] (normalized internally),
/// centered on the planet's declared [PlanetSpec.position], swinging
/// [amplitude] to either side with period [periodSeconds].
class OscillateMotion extends PlanetMotion {
  const OscillateMotion({
    required this.axis,
    required this.amplitude,
    required this.periodSeconds,
  });

  final Vector2 axis;
  final double amplitude;
  final double periodSeconds;
}
```

Add `this.motion` to `PlanetSpec`:

```dart
class PlanetSpec {
  const PlanetSpec({
    required this.position,
    required this.mass,
    required this.radius,
    required this.color,
    this.motion,
  });

  final Vector2 position;
  final double mass;
  final double radius;
  final Color color;

  /// If set, the planet moves every frame per `physics/motion.dart`
  /// instead of staying at [position]. Null means static (today's
  /// behavior for every existing level).
  final PlanetMotion? motion;
}
```

Add above `LevelData`:

```dart
/// One point the rocket must reach to win. See [LevelData.targets].
class TargetSpec {
  const TargetSpec({required this.position, required this.radius});

  final Vector2 position;
  final double radius;
}

/// A linked teleport pair: entering the radius of either [a] or [b]
/// teleports the rocket to the other end.
class WormholeSpec {
  const WormholeSpec({required this.a, required this.b, required this.radius});

  final Vector2 a;
  final Vector2 b;
  final double radius;
}
```

Inside `LevelData`, add two new constructor parameters and a getter:

```dart
class LevelData {
  const LevelData({
    required this.id,
    required this.name,
    required this.rocketStart,
    required this.baseLaunchAngleDeg,
    required this.launchAngleRangeDeg,
    required this.minLaunchSpeed,
    required this.maxLaunchSpeed,
    required this.planets,
    required this.targetPosition,
    required this.targetRadius,
    required this.playBounds,
    this.additionalTargets = const [],
    this.wormholes = const [],
  });

  // ... existing fields unchanged ...

  /// Targets beyond the primary [targetPosition]/[targetRadius]. See
  /// [targets] for the combined list; empty for every level that only
  /// has one target (all 23 existing levels).
  final List<TargetSpec> additionalTargets;

  /// Linked teleport pairs in this level. Empty for every level that
  /// doesn't use the mechanic (all 23 existing levels).
  final List<WormholeSpec> wormholes;

  /// Every target the rocket must reach to win, in no particular order:
  /// the primary target followed by [additionalTargets].
  List<TargetSpec> get targets => [
        TargetSpec(position: targetPosition, radius: targetRadius),
        ...additionalTargets,
      ];
}
```

- [ ] **Step 4: Create `lib/game/physics/motion.dart`**

```dart
import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../levels/level.dart';

/// Computes a moving planet's position at elapsed flight time [t] seconds,
/// given its declared [basePosition] (`PlanetSpec.position`, used as the
/// oscillation center) and its [motion] descriptor. Returns [basePosition]
/// unchanged for `null` (static) motion. Pure function — no Flame/Flutter
/// dependency — so both the live game loop and any future trajectory
/// preview can reuse it.
Vector2 planetPositionAt({
  required Vector2 basePosition,
  required PlanetMotion? motion,
  required double t,
}) {
  switch (motion) {
    case null:
      return basePosition.clone();
    case OrbitMotion(:final center, :final radius, :final angularSpeedRadPerSec):
      final angle = angularSpeedRadPerSec * t;
      return Vector2(
        center.x + radius * math.cos(angle),
        center.y + radius * math.sin(angle),
      );
    case OscillateMotion(:final axis, :final amplitude, :final periodSeconds):
      final normalizedAxis = axis.length2 > 0 ? axis.normalized() : Vector2(1, 0);
      final phase = periodSeconds > 0 ? math.sin(2 * math.pi * t / periodSeconds) : 0.0;
      return basePosition + normalizedAxis * (amplitude * phase);
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/physics/motion_test.dart`
Expected: PASS (5/5 tests)

- [ ] **Step 6: Run the full existing suite to confirm no regressions**

Run: `flutter test`
Expected: PASS — `level_data_test.dart` and everything else still green (the new `LevelData` fields are optional/defaulted, so no existing level construction changes).

- [ ] **Step 7: Commit**

```bash
git add lib/game/levels/level.dart lib/game/physics/motion.dart test/physics/motion_test.dart
git commit -m "Add moving-planet motion math and multi-target/wormhole level schema"
```

---

### Task 2: Progress persistence core

**Files:**
- Create: `lib/game/progress/level_progress.dart`
- Modify: `pubspec.yaml`
- Test: `test/progress/level_progress_test.dart`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces (used by Tasks 3 and 7):
  - `int starsForAttempts(int attempts)`.
  - `class LevelProgress` with `static Future<LevelProgress> load()`, `LevelProgress.empty()`, `bool isUnlocked(String levelId, List<String> orderedLevelIds)`, `int starsFor(String levelId)`, `Future<void> recordCompletion(String levelId, int attempts)`.

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml`, under `dependencies:` (after `flame: ^1.18.0`):

```yaml
  shared_preferences: ^2.3.3
```

Run: `flutter pub get`
Expected: resolves cleanly (bump the version in this step if it reports a conflict against the installed Flutter SDK — expected housekeeping per the README).

- [ ] **Step 2: Write the failing test**

Create `test/progress/level_progress_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/progress/level_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('starsForAttempts', () {
    test('1 attempt earns 3 stars', () {
      expect(starsForAttempts(1), 3);
    });

    test('2-3 attempts earn 2 stars', () {
      expect(starsForAttempts(2), 2);
      expect(starsForAttempts(3), 2);
    });

    test('4+ attempts earn 1 star', () {
      expect(starsForAttempts(4), 1);
      expect(starsForAttempts(10), 1);
    });
  });

  group('LevelProgress', () {
    const order = ['a', 'b', 'c'];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('first level is always unlocked with empty storage', () async {
      final progress = await LevelProgress.load();
      expect(progress.isUnlocked('a', order), isTrue);
      expect(progress.isUnlocked('b', order), isFalse);
    });

    test('completing a level unlocks the next one', () async {
      final progress = await LevelProgress.load();
      await progress.recordCompletion('a', 1);
      expect(progress.starsFor('a'), 3);
      expect(progress.isUnlocked('b', order), isTrue);
      expect(progress.isUnlocked('c', order), isFalse);
    });

    test('recording a worse attempt never lowers stored stars', () async {
      final progress = await LevelProgress.load();
      await progress.recordCompletion('a', 1);
      await progress.recordCompletion('a', 5);
      expect(progress.starsFor('a'), 3);
    });

    test('LevelProgress.empty() falls back to level-1-only, no crash', () {
      final progress = LevelProgress.empty();
      expect(progress.isUnlocked('a', order), isTrue);
      expect(progress.isUnlocked('b', order), isFalse);
      expect(progress.starsFor('a'), 0);
    });

    test('recordCompletion on empty progress no-ops without throwing', () async {
      final progress = LevelProgress.empty();
      await progress.recordCompletion('a', 1);
      expect(progress.starsFor('a'), 0);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/progress/level_progress_test.dart`
Expected: FAIL — `lib/game/progress/level_progress.dart` doesn't exist yet.

- [ ] **Step 4: Create `lib/game/progress/level_progress.dart`**

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Stars awarded for winning a level in [attempts] tries (counting the
/// winning attempt). Fixed thresholds, never below 1 or above 3.
int starsForAttempts(int attempts) {
  if (attempts <= 1) return 3;
  if (attempts <= 3) return 2;
  return 1;
}

/// Local (per-device) progress: which levels are unlocked and how many
/// stars each completed level earned. Backed by [SharedPreferences]; falls
/// back to "only the first level unlocked, no stars" if storage can't be
/// read, so a missing/corrupt prefs store never blocks the level select
/// screen or crashes the app.
class LevelProgress {
  LevelProgress._(this._prefs);

  /// Progress with no backing storage — the safe fallback [load] returns
  /// if [SharedPreferences] can't be reached, and directly constructible
  /// in tests to exercise that fallback behavior.
  LevelProgress.empty() : _prefs = null;

  final SharedPreferences? _prefs;

  static const String _starsKeyPrefix = 'level_stars_';

  /// Loads progress from disk. Call once (e.g. in a screen's `initState`)
  /// and hold on to the result — this does not auto-refresh.
  static Future<LevelProgress> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return LevelProgress._(prefs);
    } catch (_) {
      return LevelProgress.empty();
    }
  }

  /// A level is unlocked if it's the first entry in [orderedLevelIds], or
  /// the level immediately before it in that order has at least 1 star.
  bool isUnlocked(String levelId, List<String> orderedLevelIds) {
    final index = orderedLevelIds.indexOf(levelId);
    if (index <= 0) {
      return true;
    }
    return starsFor(orderedLevelIds[index - 1]) > 0;
  }

  /// Stars earned for [levelId], or 0 if not completed (or storage
  /// couldn't be read).
  int starsFor(String levelId) => _prefs?.getInt('$_starsKeyPrefix$levelId') ?? 0;

  /// Records a completion of [levelId] that took [attempts] tries. Only
  /// raises the stored star count — replaying a level worse than a prior
  /// best never lowers it. No-ops silently if storage isn't available.
  Future<void> recordCompletion(String levelId, int attempts) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final stars = starsForAttempts(attempts);
    if (stars > starsFor(levelId)) {
      await prefs.setInt('$_starsKeyPrefix$levelId', stars);
    }
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/progress/level_progress_test.dart`
Expected: PASS (8/8 tests)

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/game/progress/level_progress.dart test/progress/level_progress_test.dart
git commit -m "Add shared_preferences-backed level progress/star tracking"
```

---

### Task 3: Level select screen — lock icons and stars

**Files:**
- Modify: `lib/screens/level_select_screen.dart`
- Test: `test/widget/level_select_screen_test.dart`

**Interfaces:**
- Consumes: `LevelProgress.load()`, `LevelProgress.isUnlocked(levelId, orderedIds)`, `LevelProgress.starsFor(levelId)` from Task 2.
- Produces: nothing new consumed by later tasks.

- [ ] **Step 1: Write the failing test**

Create `test/widget/level_select_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';
import 'package:gravity_rocket_launcher/screens/level_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('first level is tappable, second is locked with empty progress',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));
    await tester.pumpAndSettle();

    final firstTile = find.widgetWithText(ListTile, kLevels[0].name);
    final secondTile = find.widgetWithText(ListTile, kLevels[1].name);

    expect(tester.widget<ListTile>(firstTile).enabled, isTrue);
    expect(tester.widget<ListTile>(secondTile).enabled, isFalse);
    expect(
      find.descendant(of: secondTile, matching: find.byIcon(Icons.lock)),
      findsOneWidget,
    );
  });

  testWidgets('completed level shows its star count', (tester) async {
    SharedPreferences.setMockInitialValues({
      'level_stars_${kLevels[0].id}': 3,
    });

    await tester.pumpWidget(const MaterialApp(home: LevelSelectScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsNWidgets(3));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/level_select_screen_test.dart`
Expected: FAIL — `LevelSelectScreen` doesn't read progress yet, so no lock icon/star icons exist.

- [ ] **Step 3: Rewrite `lib/screens/level_select_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../game/levels/levels.dart';
import '../game/progress/level_progress.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  static final List<String> _levelIds = kLevels.map((l) => l.id).toList();

  late Future<LevelProgress> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressFuture = LevelProgress.load();
  }

  /// Re-reads progress after returning from a level, so a just-earned
  /// unlock/star shows up immediately without leaving and re-entering
  /// this screen.
  void _refreshProgress() {
    setState(() {
      _progressFuture = LevelProgress.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Level')),
      body: FutureBuilder<LevelProgress>(
        future: _progressFuture,
        builder: (context, snapshot) {
          final progress = snapshot.data;
          if (progress == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: kLevels.length,
            itemBuilder: (context, index) {
              final level = kLevels[index];
              final unlocked = progress.isUnlocked(level.id, _levelIds);
              final stars = progress.starsFor(level.id);
              return ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(level.name),
                subtitle: unlocked ? _StarRow(stars: stars) : null,
                trailing: Icon(unlocked ? Icons.chevron_right : Icons.lock),
                enabled: unlocked,
                onTap: unlocked
                    ? () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GameScreen(level: level),
                          ),
                        );
                        _refreshProgress();
                      }
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

/// Three-icon star display: filled up to [stars], outlined after that.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Icon(
          i < stars ? Icons.star : Icons.star_border,
          size: 16,
          color: i < stars ? Colors.amber : Colors.grey,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/level_select_screen_test.dart`
Expected: PASS (2/2 tests)

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: PASS — including `test/widget/main_menu_screen_test.dart`, which navigates to `LevelSelectScreen` and must still find it working.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/level_select_screen.dart test/widget/level_select_screen_test.dart
git commit -m "Show lock icons and star ratings on the level select screen"
```

---

### Task 4: Multi-target win condition

**Files:**
- Modify: `lib/game/gravity_rocket_game.dart`
- Test: `test/game/gravity_rocket_game_test.dart`

**Interfaces:**
- Consumes: `LevelData.targets` (Task 1).
- Produces (used by Task 7): `GravityRocketGame.targets` (`List<Target>`), `GravityRocketGame.target` (getter, first of `targets`, kept for backward compatibility with existing call sites).

- [ ] **Step 1: Write the failing test**

In `test/game/gravity_rocket_game_test.dart`, change the top imports from:

```dart
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/gravity_rocket_game.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';
```

to:

```dart
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_rocket_launcher/game/gravity_rocket_game.dart';
import 'package:gravity_rocket_launcher/game/levels/level.dart';
import 'package:gravity_rocket_launcher/game/levels/levels.dart';
import 'package:vector_math/vector_math.dart';
```

(`dart:ui` for `Rect`; `levels/level.dart` for `LevelData`/`TargetSpec`; `vector_math/vector_math.dart` for `Vector2` explicitly, though it's already available transitively via `flame`/`flame_test`.)

Then add this new test inside the existing `group('GravityRocketGame', () { ... })` block, after the two tests already there ('rocket stays put before launch...' and 'reaching the target wins the level') — do not remove or modify those two:

```dart
    testWithGame<GravityRocketGame>(
      'must hit all targets (any order) to win a multi-target level',
      () => GravityRocketGame(
        level: LevelData(
          id: 'test-multi',
          name: 'Test Multi',
          rocketStart: Vector2(0, 0),
          baseLaunchAngleDeg: 0,
          launchAngleRangeDeg: 10,
          minLaunchSpeed: 100,
          maxLaunchSpeed: 100,
          planets: const [],
          targetPosition: Vector2(200, 0),
          targetRadius: 10,
          additionalTargets: [
            TargetSpec(position: Vector2(-200, 0), radius: 10),
          ],
          playBounds: const Rect.fromLTWH(-500, -500, 1000, 1000),
        ),
      ),
      (game) async {
        await game.ready();

        game.rocket.position.setFrom(Vector2(200, 0));
        game.launch(power: 0, angleOffset: 0);
        game.update(1 / 60);
        expect(game.status, GameStatus.launched);

        game.rocket.position.setFrom(Vector2(-200, 0));
        game.update(1 / 60);
        expect(game.status, GameStatus.won);
      },
    );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/game/gravity_rocket_game_test.dart`
Expected: FAIL — the new test times out at `GameStatus.launched` (still behaves like single-target) or never reaches `won`, because the game only knows about the primary target today.

- [ ] **Step 3: Update `lib/game/gravity_rocket_game.dart`**

Replace the `late Target target;` field with:

```dart
  late List<Target> targets;

  /// The primary (first) target. Kept for the common single-target case
  /// and any code that only cares about one target.
  Target get target => targets.first;

  final Set<int> _hitTargetIndices = {};
```

In `_buildLevel()`, replace the single-target block:

```dart
    target = Target(
      position: level.targetPosition,
      radius: level.targetRadius,
    );
    world.add(target);
```

with:

```dart
    targets = [
      for (final targetSpec in level.targets)
        Target(position: targetSpec.position, radius: targetSpec.radius),
    ];
    for (final t in targets) {
      world.add(t);
    }
    _hitTargetIndices.clear();
```

In `loadLevel()`, replace `world.remove(target);` with `world.removeAll(targets);`.

In `resetLevel()`, add `_hitTargetIndices.clear();` alongside the existing resets.

Replace `_hasReachedTarget()`:

```dart
  bool _hasReachedTarget() {
    final distance = (rocket.position - target.position).length;
    return distance <= target.radius;
  }
```

with:

```dart
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
```

And in `update(double dt)`, change `if (_hasReachedTarget())` to `if (_allTargetsHit())`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/game/gravity_rocket_game_test.dart`
Expected: PASS (3/3 tests) — the existing "reaching the target wins the level" test still passes unchanged since `target` now resolves via the new getter.

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/game/gravity_rocket_game.dart test/game/gravity_rocket_game_test.dart
git commit -m "Support multi-target levels: win when all targets are hit, any order"
```

---

### Task 5: Wormhole mechanic

**Files:**
- Create: `lib/game/components/wormhole.dart`
- Modify: `lib/game/components/rocket.dart`
- Modify: `lib/game/gravity_rocket_game.dart`
- Test: `test/game/gravity_rocket_game_test.dart`

**Interfaces:**
- Consumes: `LevelData.wormholes` (Task 1), `Rocket.previousPosition`/`Rocket.position` (existing), `segmentIntersectsCircle` (existing, `physics/collision.dart`).
- Produces: `Rocket.teleport(Vector2 newPosition)`; `WormholePair` (`endA`, `endB` of type `WormholeEnd extends CircleComponent`).

- [ ] **Step 1: Write the failing test**

Add to `test/game/gravity_rocket_game_test.dart`:

```dart
    testWithGame<GravityRocketGame>(
      'entering a wormhole teleports the rocket to the paired exit',
      () => GravityRocketGame(
        level: LevelData(
          id: 'test-wormhole',
          name: 'Test Wormhole',
          rocketStart: Vector2(0, 0),
          baseLaunchAngleDeg: 0,
          launchAngleRangeDeg: 10,
          minLaunchSpeed: 300,
          maxLaunchSpeed: 300,
          planets: const [],
          targetPosition: Vector2(1000, 1000),
          targetRadius: 10,
          wormholes: [
            WormholeSpec(a: Vector2(100, 0), b: Vector2(-300, 0), radius: 15),
          ],
          playBounds: const Rect.fromLTWH(-1000, -1000, 3000, 3000),
        ),
      ),
      (game) async {
        await game.ready();

        game.rocket.position.setFrom(Vector2(100, 0));
        game.launch(power: 0, angleOffset: 0);
        game.update(1 / 60);

        expect(
          (game.rocket.position - Vector2(-300, 0)).length,
          lessThan(1.0),
        );
      },
    );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/game/gravity_rocket_game_test.dart`
Expected: FAIL — compile error (`WormholeSpec` not imported/no `wormholes` handling) or the rocket position stays near `(100, 0)`.

Note: `WormholeSpec` is already defined (Task 1); this test only needs the game to act on it.

- [ ] **Step 3: Create `lib/game/components/wormhole.dart`**

```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../levels/level.dart';

/// One end of a linked wormhole pair. Purely visual/positional — the
/// teleport logic lives in [GravityRocketGame], which already owns the
/// per-tick collision checks for planets and bounds.
class WormholeEnd extends CircleComponent {
  WormholeEnd({required Vector2 position, required double radius})
      : super(
          position: position,
          radius: radius,
          anchor: Anchor.center,
          paint: Paint()
            ..color = const Color(0xFFB06CFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5,
        );
}

/// The two [WormholeEnd] components built from one [WormholeSpec]. Kept as
/// a plain holder (not a single component) so each end can be added to the
/// world and queried independently by position.
class WormholePair {
  WormholePair(WormholeSpec spec)
      : endA = WormholeEnd(position: spec.a, radius: spec.radius),
        endB = WormholeEnd(position: spec.b, radius: spec.radius);

  final WormholeEnd endA;
  final WormholeEnd endB;
}
```

- [ ] **Step 4: Add `teleport` to `lib/game/components/rocket.dart`**

Add this method to the `Rocket` class (near `launch`/`reset`):

```dart
  /// Instantly moves the rocket to [newPosition] (e.g. a wormhole exit),
  /// keeping its current velocity. Also snaps [previousPosition] to match,
  /// so the very next frame's segment-vs-circle crash check doesn't see a
  /// long spurious segment spanning the teleport.
  void teleport(Vector2 newPosition) {
    position.setFrom(newPosition);
    previousPosition.setFrom(newPosition);
  }
```

- [ ] **Step 5: Wire wormholes into `lib/game/gravity_rocket_game.dart`**

Add the import: `import 'components/wormhole.dart';`

Add fields near `targets`:

```dart
  late List<WormholePair> _wormholePairs;
  double _wormholeCooldown = 0;
  static const double _wormholeCooldownSeconds = 0.3;
```

In `_buildLevel()`, after the target-building block, add:

```dart
    _wormholePairs = [
      for (final spec in level.wormholes) WormholePair(spec),
    ];
    for (final pair in _wormholePairs) {
      world.add(pair.endA);
      world.add(pair.endB);
    }
    _wormholeCooldown = 0;
```

In `loadLevel()`, alongside the existing `world.remove*` calls, add:

```dart
    for (final pair in _wormholePairs) {
      world.remove(pair.endA);
      world.remove(pair.endB);
    }
```

In `resetLevel()`, add `_wormholeCooldown = 0;`.

In `update(double dt)`, after the `_allTargetsHit()` check and before `_hasCrashed()`, add:

```dart
    if (_wormholeCooldown > 0) {
      _wormholeCooldown -= dt;
    } else {
      _checkWormholeTeleport();
    }
```

Add the new method near `_hasCrashed()`:

```dart
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
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/game/gravity_rocket_game_test.dart`
Expected: PASS (4/4 tests)

- [ ] **Step 7: Run the full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/game/components/wormhole.dart lib/game/components/rocket.dart lib/game/gravity_rocket_game.dart test/game/gravity_rocket_game_test.dart
git commit -m "Add wormhole mechanic: paired teleport with re-trigger cooldown"
```

---

### Task 6: Moving planets

**Files:**
- Modify: `lib/game/components/planet.dart`
- Modify: `lib/game/gravity_rocket_game.dart`
- Test: `test/game/gravity_rocket_game_test.dart`

**Interfaces:**
- Consumes: `planetPositionAt` (Task 1), `PlanetSpec.motion` (Task 1). Relies on the existing fact that `Rocket.update` (in `rocket.dart`) already reads each `Planet.position` live from the component tree every frame when building gravity sources — no change needed there.
- Produces: nothing new consumed by later tasks.

- [ ] **Step 1: Write the failing test**

Add to `test/game/gravity_rocket_game_test.dart` (new imports: `dart:math as math`, `gravity_rocket_launcher/game/components/planet.dart`):

```dart
    testWithGame<GravityRocketGame>(
      'a moving planet advances position every frame instead of staying put',
      () => GravityRocketGame(
        level: LevelData(
          id: 'test-moving-planet',
          name: 'Test Moving Planet',
          rocketStart: Vector2(0, 0),
          baseLaunchAngleDeg: 0,
          launchAngleRangeDeg: 10,
          minLaunchSpeed: 0,
          maxLaunchSpeed: 0,
          planets: [
            PlanetSpec(
              position: Vector2(500, 0),
              mass: 5000,
              radius: 20,
              color: const Color(0xFFFFFFFF),
              motion: OrbitMotion(
                center: Vector2(0, 500),
                radius: 500,
                angularSpeedRadPerSec: math.pi,
              ),
            ),
          ],
          targetPosition: Vector2(1000, 1000),
          targetRadius: 10,
          playBounds: const Rect.fromLTWH(-2000, -2000, 4000, 4000),
        ),
      ),
      (game) async {
        await game.ready();
        game.launch(power: 0, angleOffset: 0);

        game.update(1 / 60);

        final planet = game.world.children.query<Planet>().first;
        expect(planet.position.x, isNot(closeTo(500, 1e-6)));
      },
    );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/game/gravity_rocket_game_test.dart`
Expected: FAIL — `Planet` currently ignores `PlanetSpec.motion` entirely (position never changes).

- [ ] **Step 3: Update `lib/game/components/planet.dart`**

```dart
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../levels/level.dart';
import '../physics/motion.dart';

/// A gravity well the rocket's trajectory is bent by. [mass] drives how
/// strongly it pulls (see `game/physics/gravity.dart`); it is kept
/// separate from the visual/collision [radius] so the two can be tuned
/// independently. If [motion] is set, the planet's position advances every
/// frame per `physics/motion.dart` — [Rocket] already reads planets' live
/// [position] each frame when building gravity sources, so no other
/// component needs to know a planet is moving.
class Planet extends CircleComponent {
  Planet({
    required Vector2 position,
    required double radius,
    required this.mass,
    required Color color,
    this.motion,
  })  : _basePosition = position.clone(),
        super(
          position: position,
          radius: radius,
          anchor: Anchor.center,
          paint: Paint()..color = color,
        );

  final double mass;
  final PlanetMotion? motion;

  final Vector2 _basePosition;
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (motion == null) return;
    _elapsed += dt;
    position.setFrom(
      planetPositionAt(basePosition: _basePosition, motion: motion, t: _elapsed),
    );
  }
}
```

- [ ] **Step 4: Pass `motion` through in `lib/game/gravity_rocket_game.dart`**

In `_buildLevel()`, in the planet-building loop, add `motion: planetSpec.motion,`:

```dart
    for (final planetSpec in level.planets) {
      world.add(
        Planet(
          position: planetSpec.position,
          radius: planetSpec.radius,
          mass: planetSpec.mass,
          color: planetSpec.color,
          motion: planetSpec.motion,
        ),
      );
    }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/game/gravity_rocket_game_test.dart`
Expected: PASS (5/5 tests)

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/game/components/planet.dart lib/game/gravity_rocket_game.dart test/game/gravity_rocket_game_test.dart
git commit -m "Animate planets with orbit/oscillate motion; gravity follows live position"
```

---

### Task 7: Attempt counting and star recording

**Files:**
- Modify: `lib/game/gravity_rocket_game.dart`
- Modify: `lib/screens/overlays/win_overlay.dart`
- Test: `test/game/gravity_rocket_game_test.dart`

**Interfaces:**
- Consumes: `LevelProgress.load()`, `LevelProgress.recordCompletion(levelId, attempts)` (Task 2).
- Produces: `GravityRocketGame.attempts` (`int`), read by `WinOverlay`.

Scope note: this task does not add a widget test for `WinOverlay`'s fire-and-forget `recordCompletion` call. The underlying `recordCompletion`/`starsForAttempts` logic is already fully covered by `test/progress/level_progress_test.dart` (Task 2); a widget test here would only re-verify that one `await`/call wiring, which isn't worth the added `SharedPreferences` mock/`pumpAndSettle` scaffolding in a widget test. The `attempts` counter itself (the actual new logic in this task) is covered below.

- [ ] **Step 1: Write the failing test**

Add to `test/game/gravity_rocket_game_test.dart`:

```dart
    testWithGame<GravityRocketGame>(
      'attempts count increments per launch and resets on loadLevel',
      () => GravityRocketGame(level: kLevels.first),
      (game) async {
        await game.ready();
        expect(game.attempts, 0);

        game.launch(power: 0.5, angleOffset: 0);
        expect(game.attempts, 1);

        game.resetLevel();
        game.launch(power: 0.5, angleOffset: 0);
        expect(game.attempts, 2);

        game.loadLevel(kLevels[1]);
        expect(game.attempts, 0);
      },
    );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/game/gravity_rocket_game_test.dart`
Expected: FAIL — `GravityRocketGame` has no `attempts` member yet.

- [ ] **Step 3: Update `lib/game/gravity_rocket_game.dart`**

Add a field near `status`:

```dart
  /// Number of real launches made during the current level session (across
  /// retries), used to compute the star rating on win. Reset by
  /// [loadLevel]; NOT reset by [resetLevel], so retries accumulate toward
  /// a worse star rating exactly as intended.
  int attempts = 0;
```

In `launch()`, right after the `if (status != GameStatus.ready) { return; }` guard, add:

```dart
    attempts++;
```

In `loadLevel()`, alongside the other resets (`lastLaunchPower = null;` etc.), add:

```dart
    attempts = 0;
```

- [ ] **Step 4: Wire recording into `lib/screens/overlays/win_overlay.dart`**

Add the import: `import '../../game/progress/level_progress.dart';`

In `initState()`, after the existing `_currentIndex`/`_hasNextLevel`/`_isLastLevel` assignments, add:

```dart
    LevelProgress.load().then((progress) {
      progress.recordCompletion(widget.game.level.id, widget.game.attempts);
    });
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/game/gravity_rocket_game_test.dart`
Expected: PASS (6/6 tests)

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/game/gravity_rocket_game.dart lib/screens/overlays/win_overlay.dart test/game/gravity_rocket_game_test.dart
git commit -m "Track launch attempts per level session and record star rating on win"
```

---

### Task 8: Showcase levels for the new mechanics

**Files:**
- Modify: `lib/game/levels/levels.dart`
- Modify: `test/levels/level_data_test.dart`

**Interfaces:**
- Consumes: `OrbitMotion`, `WormholeSpec`, `TargetSpec`, `LevelData.wormholes`/`additionalTargets`/`targets` (Task 1).
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the failing test**

Add to `test/levels/level_data_test.dart` (add import `package:gravity_rocket_launcher/game/levels/level.dart` for `OrbitMotion`/`OscillateMotion`):

```dart
    test('every wormhole pair has positive radius and both ends in bounds', () {
      for (final level in kLevels) {
        for (final wormhole in level.wormholes) {
          expect(wormhole.radius, greaterThan(0), reason: level.id);
          expect(
            level.playBounds.contains(Offset(wormhole.a.x, wormhole.a.y)),
            isTrue,
            reason: level.id,
          );
          expect(
            level.playBounds.contains(Offset(wormhole.b.x, wormhole.b.y)),
            isTrue,
            reason: level.id,
          );
        }
      }
    });

    test('targets getter combines the primary target with additionalTargets', () {
      for (final level in kLevels) {
        expect(
          level.targets.length,
          1 + level.additionalTargets.length,
          reason: level.id,
        );
        expect(level.targets.first.position, level.targetPosition, reason: level.id);
      }
    });

    test('every planet motion has sane (positive) parameters', () {
      for (final level in kLevels) {
        for (final planet in level.planets) {
          final motion = planet.motion;
          if (motion is OrbitMotion) {
            expect(motion.radius, greaterThan(0), reason: level.id);
          } else if (motion is OscillateMotion) {
            expect(motion.amplitude, greaterThan(0), reason: level.id);
            expect(motion.periodSeconds, greaterThan(0), reason: level.id);
          }
        }
      }
    });

    test('at least one level uses each new mechanic', () {
      expect(
        kLevels.any((l) => l.planets.any((p) => p.motion is OrbitMotion)),
        isTrue,
        reason: 'expected at least one level with a moving planet',
      );
      expect(
        kLevels.any((l) => l.wormholes.isNotEmpty),
        isTrue,
        reason: 'expected at least one level with a wormhole',
      );
      expect(
        kLevels.any((l) => l.additionalTargets.isNotEmpty),
        isTrue,
        reason: 'expected at least one multi-target level',
      );
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/levels/level_data_test.dart`
Expected: FAIL on the "at least one level uses each new mechanic" test — no level uses any new mechanic yet. (The other three new tests pass vacuously/trivially against the current 23 levels, which is fine — they guard the new content added in this task.)

- [ ] **Step 3: Add three showcase levels to `lib/game/levels/levels.dart`**

Add after `_threadingTheNeedle` (before the `_planetPalette` constant):

```dart
final LevelData _orbitalDance = LevelData(
  id: 'orbital-dance',
  name: 'Orbital Dance',
  rocketStart: Vector2(450, 1230),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 35,
  minLaunchSpeed: 220,
  maxLaunchSpeed: 520,
  planets: [
    PlanetSpec(
      position: Vector2(450, 650),
      mass: 3200,
      radius: 50,
      color: const Color(0xFF4C8DFF),
      motion: OrbitMotion(
        center: Vector2(450, 650),
        radius: 120,
        angularSpeedRadPerSec: 0.6,
      ),
    ),
  ],
  targetPosition: Vector2(750, 150),
  targetRadius: 65,
  playBounds: const Rect.fromLTWH(0, 0, 900, 1300),
);

final LevelData _wormholeShortcut = LevelData(
  id: 'wormhole-shortcut',
  name: 'Wormhole Shortcut',
  rocketStart: Vector2(450, 1230),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 30,
  minLaunchSpeed: 200,
  maxLaunchSpeed: 480,
  planets: [
    PlanetSpec(
      position: Vector2(300, 500),
      mass: 3000,
      radius: 55,
      color: const Color(0xFFFF9142),
    ),
  ],
  targetPosition: Vector2(750, 150),
  targetRadius: 65,
  wormholes: [
    WormholeSpec(a: Vector2(600, 900), b: Vector2(650, 300), radius: 35),
  ],
  playBounds: const Rect.fromLTWH(0, 0, 900, 1300),
);

final LevelData _twinTargets = LevelData(
  id: 'twin-targets',
  name: 'Twin Targets',
  rocketStart: Vector2(450, 1230),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 35,
  minLaunchSpeed: 220,
  maxLaunchSpeed: 520,
  planets: [
    PlanetSpec(
      position: Vector2(450, 650),
      mass: 2800,
      radius: 50,
      color: const Color(0xFFB06CFF),
    ),
  ],
  targetPosition: Vector2(200, 150),
  targetRadius: 55,
  additionalTargets: [
    TargetSpec(position: Vector2(700, 150), radius: 55),
  ],
  playBounds: const Rect.fromLTWH(0, 0, 900, 1300),
);
```

Update the `kLevels` list at the bottom of the file:

```dart
final List<LevelData> kLevels = [
  _firstOrbit,
  _slingshot,
  _threadingTheNeedle,
  ..._generatedLevels,
  _orbitalDance,
  _wormholeShortcut,
  _twinTargets,
];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/levels/level_data_test.dart`
Expected: PASS (all tests, including the new ones)

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/game/levels/levels.dart test/levels/level_data_test.dart
git commit -m "Add showcase levels: moving planet, wormhole, and multi-target"
```

---

### Task 9: Final verification and cleanup pass

**Files:** none fixed — this task reviews everything touched by Tasks 1-8.

**Interfaces:** none — pure verification, no new code contracts.

- [ ] **Step 1: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!" — fix anything it flags in the files touched by Tasks 1-8 before continuing.

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: PASS, with the full new count: `test/physics/motion_test.dart` (5), `test/progress/level_progress_test.dart` (8), `test/widget/level_select_screen_test.dart` (2) new files, plus `test/game/gravity_rocket_game_test.dart` grown from 2 to 6 tests and `test/levels/level_data_test.dart` grown from 5 to 9 tests, alongside every pre-existing test still green.

- [ ] **Step 3: Scan for leftover debug output**

Run: `grep -rn "print(" lib/`
Expected: no matches introduced by this feature work (the codebase had none before). Remove any found.

- [ ] **Step 4: Doc-comment spot check**

Confirm every new public class/member added in Tasks 1-8 has a doc comment in the same style as the surrounding file: `PlanetMotion`/`OrbitMotion`/`OscillateMotion`/`TargetSpec`/`WormholeSpec`/`LevelData.targets` (Task 1), `LevelProgress` and its methods (Task 2), `WormholeEnd`/`WormholePair`/`Rocket.teleport` (Task 5), `Planet.motion` (Task 6), `GravityRocketGame.attempts` (Task 7). Add any that are missing.

- [ ] **Step 5: Manual smoke check (optional but recommended)**

Run: `flutter run -d chrome`
Play through `Orbital Dance`, `Wormhole Shortcut`, and `Twin Targets` (reachable via Level Select once earlier levels are completed, or jump directly by temporarily reordering `kLevels` for local testing only — revert before committing). Confirm: the planet visibly orbits, the wormhole teleports the rocket without a false "crash," and the win overlay fires only after both targets in `Twin Targets` are hit. This step produces no diff by itself — it's a confidence check, not a commit.

- [ ] **Step 6: Commit if Step 1 or Step 4 produced any fixes**

```bash
git add -A
git commit -m "Polish: analyzer/doc-comment cleanup after mechanics + progress feature work"
```

If nothing changed, skip this step — there's nothing to commit.
