import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'levels/level.dart';

/// Record of which levels have been won, so [LevelSelectScreen] can gate
/// levels behind clearing the one before them. Persisted via
/// [SharedPreferences] once [load] has been called — typically on
/// [instance] from `main()` before `runApp`. A test-constructed
/// `LevelProgress()` that never calls [load] (as every test in this
/// suite does) stays purely in-memory, since [_save] is a no-op while
/// `_prefs` is null.
///
/// A process-wide static singleton, rather than threading a field
/// through main.dart/app.dart: [GravityRocketGame] (which fires the win
/// event) and [LevelSelectScreen] (which reads it to decide lock state)
/// are constructed independently by separate `Navigator.push` call
/// sites with no shared ancestor widget today, so a singleton is the
/// lowest-risk way to connect them without inventing new plumbing.
class LevelProgress {
  LevelProgress();

  /// The shared instance used by the real app. Tests that want full
  /// isolation from other tests in the same file's isolate should
  /// construct their own `LevelProgress()` instead, or call
  /// [resetForTest] on this instance in setUp/tearDown.
  static final LevelProgress instance = LevelProgress();

  final Set<String> _wonLevelIds = <String>{};
  final Map<String, int> _bestStars = <String, int>{};

  SharedPreferences? _prefs;
  static const _wonLevelIdsKey = 'levelProgress.wonLevelIds';
  static const _bestStarsKey = 'levelProgress.bestStars';

  /// Loads any previously-persisted progress from [prefs] into this
  /// instance, and remembers [prefs] so every future markWon/recordStars/
  /// resetProgress call saves back automatically. Call exactly once, on
  /// `instance`, from `main()` before `runApp` — never call this on a
  /// test-constructed `LevelProgress()`, since doing so would make that
  /// test touch the real SharedPreferences platform channel. No test in
  /// this suite calls `load`, so `_prefs` stays null for every
  /// test-constructed instance and `_save()` is always a safe no-op —
  /// this is what keeps `flutter test` from ever touching a real
  /// SharedPreferences platform channel.
  void load(SharedPreferences prefs) {
    _prefs = prefs;
    final storedIds = prefs.getStringList(_wonLevelIdsKey);
    _wonLevelIds.clear();
    if (storedIds != null) {
      _wonLevelIds.addAll(storedIds);
    }
    _bestStars.clear();
    final storedStars = prefs.getString(_bestStarsKey);
    if (storedStars != null) {
      final decoded = jsonDecode(storedStars) as Map<String, dynamic>;
      decoded.forEach((id, stars) => _bestStars[id] = stars as int);
    }
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setStringList(_wonLevelIdsKey, _wonLevelIds.toList());
    prefs.setString(_bestStarsKey, jsonEncode(_bestStars));
  }

  /// Marks [levelId] as won. Idempotent — safe to call on every win,
  /// including retries/replays of an already-won level.
  void markWon(String levelId) {
    _wonLevelIds.add(levelId);
    _save();
  }

  /// Whether [levelId] has been won at least once this app run.
  bool isWon(String levelId) => _wonLevelIds.contains(levelId);

  Set<String> get wonLevelIds => Set.unmodifiable(_wonLevelIds);

  /// Records a 1-3 star result for [levelId], keeping only the best value
  /// ever recorded — a worse retry can never lower an already-recorded
  /// best, mirroring markWon's "safe to call on every win" contract.
  /// Callers should pass starsForShotCount(shotCount).
  void recordStars(String levelId, int stars) {
    final current = _bestStars[levelId] ?? 0;
    if (stars > current) {
      _bestStars[levelId] = stars;
      _save();
    }
  }

  /// Best star rating (1-3) ever achieved on [levelId], or 0 if never won.
  /// This is the single source of truth for "has this level been starred"
  /// — UI should derive that from `bestStars(id) > 0`, not track a
  /// separate flag (same discipline as isLevelUnlocked: derive from real
  /// state, don't duplicate it).
  int bestStars(String levelId) => _bestStars[levelId] ?? 0;

  /// Sum of every level's best star rating. Used for a level-select
  /// summary readout.
  int get totalStars => _bestStars.values.fold(0, (sum, s) => sum + s);

  /// Clears all recorded progress (won levels and star ratings). Backs
  /// the Settings screen's "Reset Progress" action.
  void resetProgress() {
    _wonLevelIds.clear();
    _bestStars.clear();
    _save();
  }

  /// Test-only name for [resetProgress]. [instance] is a process-wide
  /// singleton shared by every test in the same isolate, so tests that
  /// mutate it must reset it to stay independent of each other.
  void resetForTest() => resetProgress();
}

/// Whether the level at [index] within [levels] should be selectable:
/// unconditionally true for the first level, otherwise true iff the
/// immediately preceding level has been won, OR this level itself has
/// already been won (so an already-cleared level can never spuriously
/// re-lock). A pure function of its three arguments, recomputed on every
/// call rather than cached, so it can't drift out of sync with the real
/// win-state invariant it derives from — the same discipline
/// `LoseOverlay._outOfAttempts` already follows for its fuel-lockout
/// condition (derive from real state, don't check one narrow flag).
bool isLevelUnlocked(
  int index,
  List<LevelData> levels,
  LevelProgress progress,
) {
  if (index <= 0) return true;
  return progress.isWon(levels[index - 1].id) || progress.isWon(levels[index].id);
}
