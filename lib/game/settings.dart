import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide settings, persisted via [SharedPreferences] once [load] has
/// been called — typically on [instance] from `main()` before `runApp`,
/// same pattern as [LevelProgress] in `progress.dart`. A test-constructed
/// `GameSettings()` that never calls [load] (as every test in this suite
/// does) stays purely in-memory, since [_save] is a no-op while `_prefs`
/// is null.
///
/// A process-wide static singleton, for the same reason `LevelProgress`
/// is one: [SettingsScreen] (the writer) and every overlay that fires
/// haptics (the readers) are constructed independently with no shared
/// ancestor widget.
class GameSettings {
  GameSettings();

  /// The shared instance used by the real app. Tests that want full
  /// isolation should construct their own `GameSettings()` instead, or
  /// call [resetForTest] on this instance in setUp/tearDown.
  static final GameSettings instance = GameSettings();

  SharedPreferences? _prefs;
  static const _hapticsEnabledKey = 'settings.hapticsEnabled';

  bool _hapticsEnabled = true;
  bool get hapticsEnabled => _hapticsEnabled;
  set hapticsEnabled(bool value) {
    _hapticsEnabled = value;
    _save();
  }

  /// Loads any previously-persisted haptics preference from [prefs], and
  /// remembers [prefs] so future writes to [hapticsEnabled] save back
  /// automatically. Same call-once-from-main()-only contract as
  /// LevelProgress.load — never call this on a test-constructed
  /// GameSettings(), so `_prefs` stays null there and `_save()` no-ops.
  void load(SharedPreferences prefs) {
    _prefs = prefs;
    _hapticsEnabled = prefs.getBool(_hapticsEnabledKey) ?? true;
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setBool(_hapticsEnabledKey, _hapticsEnabled);
  }

  /// Thin wrappers around [HapticFeedback] that check [hapticsEnabled]
  /// fresh on every call (never cached), so every existing call site
  /// that used to call `HapticFeedback.x()` directly can switch to
  /// `GameSettings.instance.x()` as a pure rename with no other logic
  /// change, and can never go stale even if the setting changes
  /// mid-session.
  void selectionClick() {
    if (hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  void mediumImpact() {
    if (hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Test-only: restores defaults so tests don't leak state to each
  /// other via the shared [instance].
  void resetForTest() => hapticsEnabled = true;
}
