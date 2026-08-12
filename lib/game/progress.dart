import 'levels/level.dart';

/// In-memory (NOT persisted across app relaunches — this project has no
/// local Flutter/Dart SDK anywhere in this environment to validate a new
/// pub dependency like shared_preferences, so persistence is
/// deliberately out of scope this iteration) record of which levels have
/// been won during the current app session, so [LevelSelectScreen] can
/// gate levels behind clearing the one before them.
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

  /// Marks [levelId] as won. Idempotent — safe to call on every win,
  /// including retries/replays of an already-won level.
  void markWon(String levelId) => _wonLevelIds.add(levelId);

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
