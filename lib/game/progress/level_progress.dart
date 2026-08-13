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
