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

  /// Marks [levelId] as won. Idempotent — safe to call on every win,
  /// including retries/replays of an already-won level.
  void markWon(String levelId) => _wonLevelIds.add(levelId);

  /// Whether [levelId] has been won at least once this app run.
  bool isWon(String levelId) => _wonLevelIds.contains(levelId);

  Set<String> get wonLevelIds => Set.unmodifiable(_wonLevelIds);

  /// Test-only: clears all recorded progress. [instance] is a
  /// process-wide singleton shared by every test in the same isolate, so
  /// tests that mutate it must reset it to stay independent of each
  /// other.
  void resetForTest() => _wonLevelIds.clear();
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
