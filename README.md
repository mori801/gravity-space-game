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

## Auf dem iPhone testen (kostenlos, ohne Apple Developer Account)

Eine iOS-App bauen und signieren geht nur über Xcode auf einem Mac — das ist
eine Apple-Vorgabe, kein Flutter-Detail. Mit einem eigenen Mac und einer
kostenlosen Apple-ID (kein 99$/Jahr Developer Account nötig) kommst du so
direkt auf dein iPhone:

1. **Flutter auf dem Mac installieren**, falls noch nicht vorhanden: siehe
   [docs.flutter.dev/get-started/install/macos](https://docs.flutter.dev/get-started/install/macos).
   Danach `flutter doctor` ausführen — meldet es fehlendes Xcode
   (App Store) oder CocoaPods (`sudo gem install cocoapods`), das zuerst
   nachholen.
2. Repo klonen und den Branch `claude/mobile-game-ios-android-ky9qrz`
   auschecken.
3. Im Projektordner: `flutter create .` (erzeugt den `ios/`-Ordner passend
   zum vorhandenen `pubspec.yaml`/`lib/`, siehe Abschnitt oben), danach
   `flutter pub get`.
4. iPhone per Kabel anschließen (oder Wireless Debugging in Xcode
   einrichten) und dem Mac auf dem iPhone vertrauen, falls gefragt.
5. Auf dem iPhone: **Einstellungen → Datenschutz & Sicherheit →
   Entwicklermodus** aktivieren (bei neueren iOS-Versionen nötig, um
   selbst gebaute Apps auszuführen).
6. `ios/Runner.xcworkspace` (nicht die `.xcodeproj`!) in Xcode öffnen, unter
   **Signing & Capabilities** "Automatically manage signing" aktivieren und
   deine Apple-ID als Team auswählen — Xcode erstellt automatisch ein
   kostenloses Personal-Team-Zertifikat, kein bezahlter Account nötig.
7. Das iPhone als Zielgerät auswählen und in Xcode auf "Run" (▶) drücken,
   oder alternativ im Terminal `flutter run` mit angeschlossenem Gerät —
   installiert und startet das Spiel direkt auf dem Handy.
8. Falls das iPhone das Entwicklerzertifikat nicht sofort akzeptiert: unter
   **Einstellungen → Allgemein → VPN & Geräteverwaltung** dem Zertifikat
   vertrauen.

**Wichtige Einschränkung:** Kostenlose Personal-Team-Signaturen laufen nach
**7 Tagen ab**. Die App startet danach nicht mehr, bis du Schritt 7 vom Mac
aus wiederholst (kurzer Vorgang, kein erneutes Setup nötig).

**Später, falls das Spiel sich lohnt:** Ein Wechsel zum Apple Developer
Program (99$/Jahr) ermöglicht TestFlight-Verteilung ohne 7-Tage-Limit und
ohne dass du jedes Mal den Mac brauchst — dafür bietet sich z. B.
[Codemagic](https://codemagic.io) als Cloud-Build-Dienst an, den man
komplett über den Browser (auch vom Handy aus) verwaltet. Das ist noch nicht
eingerichtet, kann aber bei Bedarf ergänzt werden.

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
