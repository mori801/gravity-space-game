import 'package:flutter/services.dart';

/// In-memory (NOT persisted across app relaunches — same constraint and
/// rationale as [LevelProgress] in `progress.dart`: this project has no
/// local Flutter/Dart SDK anywhere in this environment to validate a new
/// pub dependency like shared_preferences) app-wide settings.
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

  bool hapticsEnabled = true;

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
