# Gravity Rocket

A gravity-assist puzzle game built with [Flutter](https://flutter.dev) and the
[Flame](https://flame-engine.org) 2D game engine, targeting iOS and Android
from a single codebase.

Launch a rocket from the ground and steer it with two controls, **power** and
**angle**. Once it's airborne, gravity from the planets in the level bends its
path — the goal is to ride those gravity assists all the way to the target
without crashing into a planet or flying off into space.

## Status

This is an MVP: one full game loop (menu → level select → play → win/lose →
replay) across three hand-tuned levels. No fuel system, timers, or IAP —
those are deliberately out of scope for now.

## Project layout

```
lib/
  game/
    physics/       # Pure Dart gravity + collision math (no Flutter/Flame deps)
    levels/         # Declarative level data (planets, target, bounds)
    components/     # Flame components: Rocket, Planet, Target
    gravity_rocket_game.dart  # FlameGame subclass: game loop, win/lose rules
  screens/          # Menu, level select, in-game screen + overlays
  app.dart, main.dart
test/
  physics/, levels/   # Pure Dart unit tests
  game/, widget/      # Flame/Flutter integration tests
```

## Setup

This repo was authored without a local Flutter installation, so the `ios/`
and `android/` platform folders (which are normally machine-generated and
tied to your installed Xcode/Android toolchain versions) aren't included yet.
After cloning, from the repo root:

```bash
flutter create .      # generates ios/ and android/ for this project
flutter pub get
flutter analyze
flutter test
flutter run            # run on a connected device or simulator/emulator
```

`flutter create .` detects the existing `pubspec.yaml`/`lib/` and only adds
the missing platform folders — it won't overwrite your code. Still, run
`git status`/`git diff` afterwards before committing, just to be safe.

The `flame`, `flame_test`, and `flutter_lints` version pins in `pubspec.yaml`
were chosen without being able to run `flutter pub get` in this environment —
if `pub get` reports a version conflict against your installed Flutter SDK,
bump the affected package(s) in `pubspec.yaml`; that's expected housekeeping,
not a sign of a deeper bug.

## Testing

- `test/physics/*_test.dart` and `test/levels/level_data_test.dart` are pure
  Dart and test the gravity/collision math and level data directly.
- `test/game/gravity_rocket_game_test.dart` uses `flame_test` to run the
  actual game loop (launch, physics, win condition) headlessly.
- `test/widget/main_menu_screen_test.dart` is a standard Flutter widget/
  navigation test.

Run all of them with `flutter test`.

## Next steps / ideas

- Swap the primitive-shape rendering for real sprite art.
- A trajectory preview (dotted line) before launch.
- More levels, and a simple level-progress/unlock system.
- Sound effects and a title screen animation.
