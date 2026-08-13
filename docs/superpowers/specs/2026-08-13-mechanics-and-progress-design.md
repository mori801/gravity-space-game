# New Mechanics + Progress System — Design

Date: 2026-08-13
Status: Approved

## Motivation

The game (23 hand-tuned/procedural levels, full menu→play→win/lose loop) has no
persistent progression and no gameplay variety beyond static planets and a
single target. This design adds three new level mechanics (moving planets,
wormholes, multi-target levels) and a local progress/unlock system with a
star rating, using only what already exists in the codebase (no new backend,
no new physics engine).

Explicitly out of scope (per existing README "Status" section and user
choice during brainstorming): fuel system, timers, sprite/art replacement,
audio. Star rating is based on attempt count, not fuel or time, to avoid
introducing either of those systems.

## Decisions

- **Progress persistence:** `shared_preferences`. Standard Flutter local
  key-value store; no native config, no schema migration tooling needed for
  a level-id → stars map.
- **Moving planets:** parametric time function `position(t)`, not simulated
  orbital mechanics. Deterministic, unit-testable without a game loop,
  no drift.
- **Level schema:** extend `LevelData` with optional fields defaulting to
  today's behavior, rather than a new level-data subtype. All 23 existing
  levels keep working unchanged.
- **Multi-target order:** any order — all targets must be hit, sequence
  doesn't matter (simpler to implement and to play).
- **Star rating:** based on attempts-to-win within a level session.
  1 attempt → 3 stars, 2-3 attempts → 2 stars, 4+ attempts → 1 star.

## Data Model Changes (`lib/game/levels/level.dart`)

- `PlanetSpec` gains an optional `motion` field:
  - `OrbitMotion(center, radius, angularSpeedRadPerSec)` — circular orbit.
  - `OscillateMotion(axis, amplitude, periodSeconds)` — linear back-and-forth.
  - `null` (default) — static, current behavior.
- `LevelData.targetPosition`/`targetRadius` (singular) become
  `targets: List<TargetSpec>` (`TargetSpec(position, radius)`). Existing
  levels get a single-element list via a compatibility constructor path so
  no existing level definition needs to change.
- `LevelData` gains `wormholes: List<WormholeSpec>` (default `[]`).
  `WormholeSpec(a: Vector2, b: Vector2, radius: double)` — entering either
  end teleports the rocket to the other, velocity vector preserved.

## New Files

- `lib/game/physics/motion.dart` — pure functions computing a moving
  planet's position at elapsed time `t` for `OrbitMotion` and
  `OscillateMotion`. No Flame/Flutter dependency, matches the existing
  `physics/` convention (see `gravity.dart`, `collision.dart`).
- `lib/game/components/wormhole.dart` — Flame component pair for a
  `WormholeSpec`. Teleport triggers on radius entry; a short per-rocket
  cooldown after teleporting prevents immediately re-triggering the exit end.
- `lib/game/progress/level_progress.dart` — wraps `shared_preferences`:
  - `Future<void> load()`
  - `bool isUnlocked(String levelId)`
  - `int starsFor(String levelId)` (0 if not completed)
  - `Future<void> recordCompletion(String levelId, int attempts)`
  - On read failure/missing data: defaults to "only the first level
    unlocked, no stars anywhere" — never throws, never blocks the menu.

## Changed Files

- `lib/game/components/planet.dart` — `update(dt)` advances position from
  `motion.dart` when the spec has a `motion` value; unchanged otherwise.
- `lib/game/components/target.dart` — game spawns one instance per
  `TargetSpec`; each tracks its own hit state.
- `lib/game/gravity_rocket_game.dart`:
  - Gravity sources are rebuilt from planets' *current* (possibly moving)
    positions each tick, not fixed at level load.
  - Win condition: all targets hit (order-independent).
  - Wormhole entry checked alongside existing planet-collision/out-of-bounds
    checks.
  - Tracks attempt count for the current level-session (increments on each
    launch, used for the star calculation at win time).
- `lib/screens/level_select_screen.dart` — reads `LevelProgress`; locked
  levels show a lock icon and are not tappable; completed levels show their
  star count.
- `lib/screens/overlays/win_overlay.dart` / `lib/screens/game_screen.dart` —
  on win, call `LevelProgress.recordCompletion(levelId, attempts)`.
- `pubspec.yaml` — add `shared_preferences` dependency.
- `lib/game/levels/levels.dart` — add 3-4 new levels (ids 24+): one
  showcasing a moving planet, one a wormhole, one multi-target, optionally
  one combining more than one mechanic as a capstone level.

## Error Handling

- `shared_preferences` read failure → `LevelProgress` falls back to "level 1
  only, zero stars" rather than crashing or blocking the level-select screen.
- Wormhole teleport cooldown prevents an infinite teleport loop between
  paired ends.
- Each `TargetSpec` counts as hit at most once per level session, even if
  its collision circle overlaps another target's, to avoid double-counting
  toward the win condition.

## Testing

- `test/physics/motion_test.dart` (new) — deterministic position checks for
  `OrbitMotion`/`OscillateMotion` at known `t` values.
- `test/levels/level_data_test.dart` (extended) — new levels validate:
  wormhole pairs complete, `targets` non-empty, motion parameters sane
  (radius/amplitude > 0, period > 0).
- `test/progress/level_progress_test.dart` (new) — unlock progression and
  star calculation from attempt counts, using
  `SharedPreferences.setMockInitialValues` for isolation; verifies the
  fallback behavior on empty/corrupt storage.
- `test/game/gravity_rocket_game_test.dart` (extended, `flame_test`
  headless) — multi-target win (any order), wormhole teleport (position +
  velocity after the jump), moving-planet gravity influence over time.
- `test/widget/level_select_screen_test.dart` (new) — locked levels are not
  tappable, stars render from mocked progress data.

All new/changed code follows the existing convention: physics stays pure
Dart in `physics/`, Flame components in `components/`, level content stays
declarative in `levels/`. `flutter test` covers everything; no manual test
step required beyond the existing optional browser check.

## Team Execution Plan

Orchestrator (this session, running as Sonnet — not Opus; switching the
lead to Opus requires the user to run `/model opus`, which the orchestrator
cannot do to itself) dispatches subagents, all running Sonnet, in staged
waves rather than one fully-parallel batch — the working tree is shared (no
per-agent git worktree), so real concurrency is limited to non-overlapping
files:

| Wave | Role | Parallel count | Files |
|---|---|---|---|
| 1 | Planner | 1 | Implementation plan from this spec |
| 2 | Programmer A — Foundation | 1 | `level.dart`, `physics/motion.dart` |
| 2 | Programmer B — Progress | 1 (parallel to A) | `progress/level_progress.dart`, `level_select_screen.dart`, `pubspec.yaml` |
| 3 | Programmer C — Game-loop integration | 1 (after A) | `wormhole.dart`, `target.dart`, `planet.dart`, `gravity_rocket_game.dart` |
| 4 | Programmer D — Level content | 1 (after C) | `levels.dart` |
| 5 | Testers | up to 4 parallel | one `*_test.dart` file each |
| 6 | Bugfixers | reactive, 1-3 | whichever files test failures point to |
| 7 | Optimizer | 1 | cleanup/perf pass once tests are green |

~9-10 subagent dispatches total across the whole effort; at most 2 run
simultaneously (wave 2), everything else is sequential to avoid conflicting
edits to `gravity_rocket_game.dart` in particular.
