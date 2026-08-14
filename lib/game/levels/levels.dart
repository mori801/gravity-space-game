import 'dart:ui';

import 'package:vector_math/vector_math.dart';

import 'level.dart';

/// -90deg = straight up in screen space (y grows downward), matching the
/// rocket's initial launch direction described in the game concept.
const double _straightUpDeg = -90;

final LevelData _firstOrbit = LevelData(
  id: 'first-orbit',
  name: 'First Orbit',
  rocketStart: Vector2(400, 1130),
  baseLaunchAngleDeg: _straightUpDeg,
  // 90 = a total steerable sweep of 180° (this is the ± half-width around
  // baseLaunchAngleDeg, so the achievable range is base - 90 .. base + 90).
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 200,
  maxLaunchSpeed: 500,
  planets: [
    PlanetSpec(
      position: Vector2(600, 500),
      mass: 3000,
      radius: 60,
      color: Color(0xFF4C8DFF),
    ),
  ],
  targetPosition: Vector2(650, 150),
  targetRadius: 70,
  playBounds: const Rect.fromLTWH(0, 0, 800, 1200),
);

final LevelData _slingshot = LevelData(
  id: 'slingshot',
  name: 'Slingshot',
  rocketStart: Vector2(450, 1230),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 220,
  maxLaunchSpeed: 520,
  planets: [
    PlanetSpec(
      position: Vector2(300, 650),
      mass: 2800,
      radius: 55,
      color: Color(0xFFFF9142),
    ),
    PlanetSpec(
      position: Vector2(650, 400),
      mass: 2000,
      radius: 45,
      color: Color(0xFFB06CFF),
    ),
  ],
  targetPosition: Vector2(750, 120),
  targetRadius: 68,
  playBounds: const Rect.fromLTWH(0, 0, 900, 1300),
);

final LevelData _threadingTheNeedle = LevelData(
  id: 'threading-the-needle',
  name: 'Threading the Needle',
  rocketStart: Vector2(500, 1330),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 250,
  maxLaunchSpeed: 550,
  planets: [
    PlanetSpec(
      position: Vector2(250, 900),
      mass: 3000,
      radius: 50,
      color: Color(0xFF4CE0B3),
    ),
    PlanetSpec(
      position: Vector2(700, 700),
      mass: 2400,
      radius: 45,
      color: Color(0xFFFF6584),
    ),
    PlanetSpec(
      position: Vector2(450, 350),
      mass: 2200,
      radius: 40,
      color: Color(0xFFFFD24C),
    ),
  ],
  targetPosition: Vector2(850, 150),
  targetRadius: 58,
  playBounds: const Rect.fromLTWH(0, 0, 1000, 1400),
);

/// Colors cycled through by [_generatedLevel] so planets stay visually
/// distinguishable from each other and from level to level.
const List<Color> _planetPalette = [
  Color(0xFF4C8DFF),
  Color(0xFFFF9142),
  Color(0xFFB06CFF),
  Color(0xFF4CE0B3),
  Color(0xFFFF6584),
  Color(0xFFFFD24C),
  Color(0xFF6CFFB0),
  Color(0xFF6CA0FF),
];

/// Builds one procedurally-laid-out level. The rocket always starts at
/// bottom-center and the target always sits near the top; planets are
/// spread across [planetCount] evenly-spaced horizontal rows in between,
/// alternating left/right of center by 0.28 * [width] — an offset chosen
/// to always comfortably exceed every planet's radius (radii here never
/// exceed ~60, offsets are always 220+), so no planet can ever overlap
/// the rocket's start position, another planet, or the target purely by
/// construction, without needing per-level manual distance checks.
LevelData _generatedLevel({
  required String id,
  required String name,
  required double width,
  required double height,
  required double launchAngleRangeDeg,
  required double minSpeed,
  required double maxSpeed,
  required double targetRadius,
  required double targetXFrac,
  required List<double> planetMasses,
  required List<double> planetRadii,
  required List<Color> planetColors,
  List<double> noFlyZoneRadii = const <double>[],
  int? maxShots,
  List<WindZoneSpec> windZones = const <WindZoneSpec>[],
}) {
  final planetCount = planetMasses.length;
  final usableHeight = height - 550;
  final rowSpacing = planetCount > 1 ? usableHeight / (planetCount - 1) : 0.0;

  final planets = <PlanetSpec>[
    for (var p = 0; p < planetCount; p++)
      PlanetSpec(
        position: Vector2(
          width / 2 + (p.isEven ? -1 : 1) * width * 0.28,
          350 + rowSpacing * p,
        ),
        mass: planetMasses[p],
        radius: planetRadii[p],
        color: planetColors[p],
      ),
  ];

  // Zones are centered horizontally and spread across the middle 60% of
  // the same usable vertical band the planets use above, so — just like
  // the planets — they're placed well clear of the rocket-start row near
  // the bottom (height - 100) and the target near the top (y = 130) by
  // construction, without needing per-level manual distance checks.
  final noFlyZoneCount = noFlyZoneRadii.length;
  final noFlyZones = <NoFlyZoneSpec>[
    for (var z = 0; z < noFlyZoneCount; z++)
      NoFlyZoneSpec(
        position: Vector2(
          width / 2,
          350 +
              usableHeight *
                  (noFlyZoneCount == 1
                      ? 0.5
                      : 0.2 + 0.6 * z / (noFlyZoneCount - 1)),
        ),
        radius: noFlyZoneRadii[z],
      ),
  ];

  return LevelData(
    id: id,
    name: name,
    rocketStart: Vector2(width / 2, height - 100),
    baseLaunchAngleDeg: _straightUpDeg,
    launchAngleRangeDeg: launchAngleRangeDeg,
    minLaunchSpeed: minSpeed,
    maxLaunchSpeed: maxSpeed,
    planets: planets,
    targetPosition: Vector2(width * targetXFrac, 130),
    targetRadius: targetRadius,
    playBounds: Rect.fromLTWH(0, 0, width, height),
    noFlyZones: noFlyZones,
    maxShots: maxShots,
    windZones: windZones,
  );
}

const List<String> _generatedLevelNames = [
  'Steady Orbit',
  'Solar Drift',
  "Comet's Path",
  'Asteroid Kiss',
  'Lunar Bounce',
  'Binary Dance',
  'Gravity Well',
  'Twin Suns',
  'Nebula Curve',
  'Meteor Alley',
  'Triple Threat',
  'Starlight Maze',
  'Orbital Chain',
  'Deep Space Drift',
  'Cosmic Pinball',
  'Quadrant Four',
  'Galactic Slalom',
  'Dark Nebula',
  'Event Horizon',
  'Final Frontier',
  'Five-Body Problem',
  'Outer Rim',
  'Planetary Gauntlet',
  'The Long Descent',
  'Singularity Run',
];

/// Retrofits a shot budget onto a subset of the mid/high-tier generated
/// levels (keyed by this list's own generation index `i`, not level id).
/// Every other generated level keeps `maxShots: null` (unlimited),
/// unchanged from before this iteration.
const Map<int, int> _generatedMaxShotsByListIndex = {
  18: 5, // level-22 (tier 3, 4 planets)
  19: 4, // level-23 (tier 3, 4 planets)
  22: 5, // level-26 (tier 4, 5 planets)
  23: 4, // level-27 (tier 4, 5 planets)
  24: 4, // level-28 (tier 4, 5 planets)
};

/// Difficulty-curve pass (iteration 4): numeric override for an
/// individual generated level flagged as a spike relative to its
/// neighbors, keyed the same way as _generatedMaxShotsByListIndex.
const Map<int, double> _generatedTargetRadiusOverrideByListIndex = {
  24: 36.0, // level-28: 5-planet gauntlet + a tight shot budget was too punishing combined
};

/// 25 additional levels (on top of the 3 hand-tuned ones above), ramping
/// up in five five-level tiers of 1/2/3/4/5 planets respectively. Every
/// numeric parameter is derived from [tier] and [indexInTier] so the
/// whole batch is generated rather than hand-typed, keeping it easy to
/// reason about correctness (see [_generatedLevel]) without a local
/// Dart/Flutter toolchain to run `level_data_test.dart` against.
final List<LevelData> _generatedLevels = List.generate(25, (i) {
  final tier = i ~/ 5;
  final indexInTier = i % 5;
  final planetCount = tier + 1;

  final width = 800.0 + tier * 200 + indexInTier * 20;
  final height = 1200.0 + tier * 200 + indexInTier * 20;

  final planetMasses = List<double>.generate(
    planetCount,
    (p) => 2200.0 + p * 400 + tier * 200,
  );
  final planetRadii = List<double>.generate(
    planetCount,
    (p) => 60.0 - p * 6 - tier * 2,
  );
  final planetColors = List<Color>.generate(
    planetCount,
    (p) => _planetPalette[(i + p) % _planetPalette.length],
  );

  return _generatedLevel(
    id: 'level-${i + 4}',
    name: _generatedLevelNames[i],
    width: width,
    height: height,
    // 90 = a total steerable sweep of 180° (± half-width around straight
    // up). Angle range is no longer a difficulty knob (difficulty still
    // comes from planet count, speed, bounds, and target size, all still
    // tier/indexInTier-driven above).
    launchAngleRangeDeg: 90.0,
    minSpeed: 200.0 + tier * 15 + indexInTier * 5,
    maxSpeed: 500.0 + tier * 15 + indexInTier * 5,
    targetRadius: _generatedTargetRadiusOverrideByListIndex[i] ??
        (68.0 - tier * 8 - indexInTier * 2),
    targetXFrac: indexInTier.isEven ? 0.75 : 0.25,
    planetMasses: planetMasses,
    planetRadii: planetRadii,
    planetColors: planetColors,
    maxShots: _generatedMaxShotsByListIndex[i],
  );
});

const List<String> _tier6LevelNames = [
  'Restricted Approach',
  'Red Corridor',
  'Quarantine Belt',
  'Minefield Run',
  'Twin Exclusion',
  'Triple Blockade',
  'Hazard Nexus',
  'Full Lockdown',
];

/// Retrofits a shot budget onto the hardest half of the no-fly-zone
/// tier, combining the fuel mechanic with a hazard it didn't originally
/// ship with.
const Map<int, int> _tier6MaxShotsByIdx = {
  4: 5, // level-33
  5: 4, // level-34
  6: 4, // level-35
  7: 3, // level-36
};

/// Difficulty-curve smoothing (iteration 5): tier 6 intentionally resets
/// planet count from tier 5's climb to 5 down to a lower count, so the
/// new no-fly-zone hazard — not gravity complexity — drives this tier's
/// difficulty. But launch speed and target size were resetting right
/// alongside it too, producing an unintended extra difficulty dip at
/// the exact tier boundary. These additive/subtractive boosts close
/// most of that gap for the first two levels only, tapering to 0 by
/// index 2 so the rest of the tier's ramp is unaffected.
const Map<int, double> _tier6SpeedBoostByIdx = {0: 40, 1: 18};
const Map<int, double> _tier6TargetRadiusCutByIdx = {0: 10, 1: 5};

/// 8 additional levels (tier 6): introduces [NoFlyZoneSpec] hazards as a
/// second obstacle type alongside planets. Deliberately keeps planet
/// count low and nearly flat (2-3, vs. tier 5's climb to 5) so the
/// no-fly zones — not more gravity wells — are this tier's primary new
/// difficulty axis, ramping from 1 to 3 zones per level across the 8.
final List<LevelData> _tier6Levels = List.generate(8, (idx) {
  final planetCount = 2 + idx ~/ 4; // 2,2,2,2,3,3,3,3
  final noFlyZoneCount = 1 + idx ~/ 3; // 1,1,1,2,2,2,3,3

  final width = 1800.0 + idx * 25;
  final height = 2200.0 + idx * 25;

  final planetMasses = List<double>.generate(
    planetCount,
    (p) => 3200.0 + p * 400 + idx * 30,
  );
  final planetRadii = List<double>.generate(
    planetCount,
    (p) => 50.0 - p * 6 - idx * 1,
  );
  final planetColors = List<Color>.generate(
    planetCount,
    (p) => _planetPalette[(idx + p) % _planetPalette.length],
  );
  final noFlyZoneRadii = List<double>.generate(
    noFlyZoneCount,
    (z) => 42.0 - z * 4 - idx * 1,
  );

  return _generatedLevel(
    id: 'level-${29 + idx}',
    name: _tier6LevelNames[idx],
    width: width,
    height: height,
    launchAngleRangeDeg: 90.0,
    minSpeed: 230.0 + idx * 6 + (_tier6SpeedBoostByIdx[idx] ?? 0),
    maxSpeed: 530.0 + idx * 6 + (_tier6SpeedBoostByIdx[idx] ?? 0),
    targetRadius: 42.0 - idx * 1.5 - (_tier6TargetRadiusCutByIdx[idx] ?? 0),
    targetXFrac: idx.isEven ? 0.78 : 0.22,
    planetMasses: planetMasses,
    planetRadii: planetRadii,
    planetColors: planetColors,
    noFlyZoneRadii: noFlyZoneRadii,
    maxShots: _tier6MaxShotsByIdx[idx],
  );
});

const List<String> _tier7LevelNames = [
  'Fuel Rationing',
  'Last Reserves',
  'Empty Tank Run',
  'Scorched Corridor',
  'Vapor Trail',
  'Dead Stick Landing',
  'Point of No Return',
  'Final Descent',
];

/// maxShots ramp: forgiving (6) at the start of the tier down to tight
/// (3) at the end, never below 3 so restarting with a fresh budget (see
/// LoseOverlay._restartLevel) is never the *only* path to victory.
const Map<int, int> _tier7MaxShotsByIdx = {
  0: 6,
  1: 6,
  2: 5,
  3: 5,
  4: 4,
  5: 4,
  6: 3,
  7: 3,
};

/// Difficulty-curve smoothing (iteration 5): same rationale as
/// _tier6SpeedBoostByIdx/_tier6TargetRadiusCutByIdx above, but tier 7's
/// boundary dip is real yet smaller than tier 6's or tier 8's, so the
/// magnitude here is smaller. Tapers to 0 by index 2; the tier's own
/// maxShots ramp (_tier7MaxShotsByIdx below) already reads as an
/// intentional, gentle easing-in and is left untouched.
const Map<int, double> _tier7SpeedBoostByIdx = {0: 28, 1: 12};
const Map<int, double> _tier7TargetRadiusCutByIdx = {0: 7, 1: 3};

/// 8 additional levels (tier 7): combines all three obstacle types at
/// once — multi-planet gravity wells, no-fly zone hazards, and a
/// maxShots fuel budget — rather than any of them in isolation like
/// tiers 1-6 each introduced separately.
final List<LevelData> _tier7Levels = List.generate(8, (idx) {
  final planetCount = 3 + idx ~/ 4; // 3,3,3,3,4,4,4,4
  final noFlyZoneCount = 2 + idx ~/ 4; // 2,2,2,2,3,3,3,3

  final width = 2000.0 + idx * 30;
  final height = 2450.0 + idx * 30;

  final planetMasses = List<double>.generate(
    planetCount,
    (p) => 3400.0 + p * 400 + idx * 30,
  );
  final planetRadii = List<double>.generate(
    planetCount,
    (p) => 48.0 - p * 6 - idx * 1,
  );
  final planetColors = List<Color>.generate(
    planetCount,
    (p) => _planetPalette[(idx + p) % _planetPalette.length],
  );
  final noFlyZoneRadii = List<double>.generate(
    noFlyZoneCount,
    (z) => 40.0 - z * 4 - idx * 1,
  );

  return _generatedLevel(
    id: 'level-${37 + idx}',
    name: _tier7LevelNames[idx],
    width: width,
    height: height,
    launchAngleRangeDeg: 90.0,
    minSpeed: 240.0 + idx * 6 + (_tier7SpeedBoostByIdx[idx] ?? 0),
    maxSpeed: 540.0 + idx * 6 + (_tier7SpeedBoostByIdx[idx] ?? 0),
    targetRadius: 40.0 - idx * 1.5 - (_tier7TargetRadiusCutByIdx[idx] ?? 0),
    targetXFrac: idx.isEven ? 0.8 : 0.2,
    planetMasses: planetMasses,
    planetRadii: planetRadii,
    planetColors: planetColors,
    noFlyZoneRadii: noFlyZoneRadii,
    maxShots: _tier7MaxShotsByIdx[idx],
  );
});

const List<String> _tier8LevelNames = [
  'Solar Breeze',
  'Crosswind Pass',
  'Jet Stream',
  'Ion Storm',
  'Gale Force',
];

/// Difficulty-curve smoothing (iteration 5): tier 8's boundary dip is the
/// largest of the three, since it loses BOTH the no-fly-zone hazard and
/// the fuel-budget cap at once, on top of the planet-count reset — so on
/// top of the same speed/target treatment as tiers 6/7, the wind zone's
/// own severity (radius and force) also gets a small first-levels-only
/// boost. Tapers to 0 by index 2 exactly like the other tiers.
const Map<int, double> _tier8SpeedBoostByIdx = {0: 20, 1: 8};
const Map<int, double> _tier8TargetRadiusCutByIdx = {0: 12, 1: 5};
const Map<int, double> _tier8WindRadiusBoostByIdx = {0: 20, 1: 8};
const Map<int, double> _tier8WindForceBoostByIdx = {0: 30, 1: 12};

/// 5 additional levels (tier 8): introduces [WindZoneSpec] — a constant
/// directional push — as a new mechanic. Kept to a flat 2 planets and
/// 1-2 wind zones throughout (no further planet-count ramp) so the wind
/// force, not more gravity, is this tier's sole new difficulty axis,
/// mirroring how tier 6 kept planet count flat while ramping no-fly
/// zones. Push direction alternates by level so wind sometimes assists
/// toward the target and sometimes fights it.
final List<LevelData> _tier8Levels = List.generate(5, (idx) {
  const planetCount = 2;
  final windZoneCount = 1 + idx ~/ 3; // 1,1,1,2,2

  final width = 2100.0 + idx * 30;
  final height = 2550.0 + idx * 30;
  final usableHeight = height - 550; // mirrors _generatedLevel's own calc

  final planetMasses = List<double>.generate(
    planetCount,
    (p) => 3600.0 + p * 400 + idx * 30,
  );
  final planetRadii = List<double>.generate(
    planetCount,
    (p) => 46.0 - p * 6 - idx * 1,
  );
  final planetColors = List<Color>.generate(
    planetCount,
    (p) => _planetPalette[(idx + p) % _planetPalette.length],
  );

  final pushRight = idx.isEven;
  final forceDirectionDeg = pushRight ? 0.0 : 180.0;
  final windZones = List<WindZoneSpec>.generate(
    windZoneCount,
    (z) => WindZoneSpec(
      position: Vector2(
        width / 2,
        350 +
            usableHeight *
                (windZoneCount == 1
                    ? 0.5
                    : 0.25 + 0.5 * z / (windZoneCount - 1)),
      ),
      radius: 130.0 + idx * 10 + (_tier8WindRadiusBoostByIdx[idx] ?? 0),
      forceDirectionDeg: forceDirectionDeg,
      forceMagnitude: 120.0 + idx * 15 + (_tier8WindForceBoostByIdx[idx] ?? 0),
    ),
  );

  return _generatedLevel(
    id: 'level-${45 + idx}',
    name: _tier8LevelNames[idx],
    width: width,
    height: height,
    launchAngleRangeDeg: 90.0,
    minSpeed: 260.0 + idx * 6 + (_tier8SpeedBoostByIdx[idx] ?? 0),
    maxSpeed: 560.0 + idx * 6 + (_tier8SpeedBoostByIdx[idx] ?? 0),
    targetRadius: 46.0 - idx * 2 - (_tier8TargetRadiusCutByIdx[idx] ?? 0),
    targetXFrac: pushRight ? 0.78 : 0.22,
    planetMasses: planetMasses,
    planetRadii: planetRadii,
    planetColors: planetColors,
    windZones: windZones,
  );
});

final LevelData _orbitalDance = LevelData(
  id: 'orbital-dance',
  name: 'Orbital Dance',
  rocketStart: Vector2(450, 1230),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
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
  launchAngleRangeDeg: 90,
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
  launchAngleRangeDeg: 90,
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

final LevelData _repulsorIntro = LevelData(
  id: 'repulsor-intro',
  name: 'Pushback',
  rocketStart: Vector2(450, 1230),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 220,
  maxLaunchSpeed: 520,
  planets: [
    PlanetSpec(
      position: Vector2(450, 700),
      mass: -2600,
      radius: 55,
      color: const Color(0xFFFF6584),
    ),
  ],
  targetPosition: Vector2(750, 150),
  targetRadius: 65,
  playBounds: const Rect.fromLTWH(0, 0, 900, 1300),
);

final LevelData _repulsorGauntlet = LevelData(
  id: 'repulsor-gauntlet',
  name: 'The Gauntlet',
  rocketStart: Vector2(450, 1230),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 220,
  maxLaunchSpeed: 540,
  planets: [
    PlanetSpec(
      position: Vector2(300, 850),
      mass: 2800,
      radius: 55,
      color: const Color(0xFF4C8DFF),
    ),
    PlanetSpec(
      position: Vector2(600, 450),
      mass: -2200,
      radius: 50,
      color: const Color(0xFFFF6584),
    ),
  ],
  targetPosition: Vector2(800, 150),
  targetRadius: 65,
  playBounds: const Rect.fromLTWH(0, 0, 950, 1350),
);

final LevelData _repulsorSlalom = LevelData(
  id: 'repulsor-slalom',
  name: 'Slalom',
  rocketStart: Vector2(500, 1330),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 240,
  maxLaunchSpeed: 550,
  planets: [
    PlanetSpec(
      position: Vector2(320, 850),
      mass: -2000,
      radius: 48,
      color: const Color(0xFFFF6584),
    ),
    PlanetSpec(
      position: Vector2(680, 850),
      mass: -2000,
      radius: 48,
      color: const Color(0xFFFF6584),
    ),
    PlanetSpec(
      position: Vector2(500, 500),
      mass: 2600,
      radius: 50,
      color: const Color(0xFFB06CFF),
    ),
  ],
  targetPosition: Vector2(500, 150),
  targetRadius: 62,
  playBounds: const Rect.fromLTWH(0, 0, 1000, 1450),
);

final LevelData _repulsorOrbitBreak = LevelData(
  id: 'repulsor-orbit-break',
  name: 'Orbit Break',
  rocketStart: Vector2(475, 1380),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 220,
  maxLaunchSpeed: 540,
  planets: [
    PlanetSpec(
      position: Vector2(475, 700),
      mass: 3400,
      radius: 60,
      color: const Color(0xFF4C8DFF),
    ),
    PlanetSpec(
      position: Vector2(675, 700),
      mass: -1800,
      radius: 42,
      color: const Color(0xFFFF6584),
      motion: OrbitMotion(
        center: Vector2(475, 700),
        radius: 200,
        angularSpeedRadPerSec: 0.35,
      ),
    ),
  ],
  targetPosition: Vector2(800, 150),
  targetRadius: 65,
  playBounds: const Rect.fromLTWH(0, 0, 950, 1450),
);

final LevelData _sequenceIntro = LevelData(
  id: 'sequence-intro',
  name: 'First, Then',
  rocketStart: Vector2(450, 1230),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 220,
  maxLaunchSpeed: 520,
  ordered: true,
  planets: [
    PlanetSpec(
      position: Vector2(450, 700),
      mass: 2800,
      radius: 55,
      color: const Color(0xFF4C8DFF),
    ),
  ],
  targetPosition: Vector2(300, 950),
  targetRadius: 58,
  additionalTargets: [
    TargetSpec(position: Vector2(750, 150), radius: 58),
  ],
  playBounds: const Rect.fromLTWH(0, 0, 900, 1300),
);

final LevelData _sequenceSlingshotRelay = LevelData(
  id: 'sequence-slingshot-relay',
  name: 'Relay',
  rocketStart: Vector2(475, 1330),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 230,
  maxLaunchSpeed: 540,
  ordered: true,
  planets: [
    PlanetSpec(
      position: Vector2(280, 800),
      mass: 2600,
      radius: 50,
      color: const Color(0xFFFF9142),
    ),
    PlanetSpec(
      position: Vector2(700, 800),
      mass: 2400,
      radius: 48,
      color: const Color(0xFFB06CFF),
    ),
  ],
  // Greedy "nearest first" would grab target 2 (near planet B, roughly
  // level with target 1 across the play area) before target 1 (near
  // planet A) since both sit at a similar distance from rocketStart —
  // but the required order is: near A, then near B, then top-center.
  targetPosition: Vector2(230, 650),
  targetRadius: 56,
  additionalTargets: [
    TargetSpec(position: Vector2(750, 650), radius: 56),
    TargetSpec(position: Vector2(490, 150), radius: 56),
  ],
  playBounds: const Rect.fromLTWH(0, 0, 980, 1450),
);

final LevelData _sequenceOrbitalCheckpoints = LevelData(
  id: 'sequence-orbital-checkpoints',
  name: 'Checkpoints',
  rocketStart: Vector2(475, 1380),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 240,
  maxLaunchSpeed: 550,
  ordered: true,
  planets: [
    PlanetSpec(
      position: Vector2(475, 750),
      mass: 3200,
      radius: 58,
      color: const Color(0xFF4CE0B3),
    ),
    PlanetSpec(
      position: Vector2(675, 750),
      mass: 2000,
      radius: 40,
      color: const Color(0xFFFFD24C),
      motion: OrbitMotion(
        center: Vector2(475, 750),
        radius: 200,
        angularSpeedRadPerSec: 0.42,
      ),
    ),
  ],
  targetPosition: Vector2(220, 1050),
  targetRadius: 58,
  additionalTargets: [
    TargetSpec(position: Vector2(820, 600), radius: 58),
    TargetSpec(position: Vector2(475, 150), radius: 58),
  ],
  playBounds: const Rect.fromLTWH(0, 0, 950, 1450),
);

final LevelData _sequenceGauntletLoop = LevelData(
  id: 'sequence-gauntlet-loop',
  name: 'Full Circuit',
  rocketStart: Vector2(475, 1230),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 230,
  maxLaunchSpeed: 530,
  ordered: true,
  planets: [
    PlanetSpec(
      position: Vector2(300, 650),
      mass: 2600,
      radius: 50,
      color: const Color(0xFF6CA0FF),
    ),
    PlanetSpec(
      position: Vector2(650, 650),
      mass: 2600,
      radius: 50,
      color: const Color(0xFFFF6584),
    ),
  ],
  // Target 1 is a tight, low-energy loop right in front of the rocket;
  // targets 2 and 3 are near-symmetric on opposite far sides, tempting a
  // player to grab whichever is more convenient first — but the required
  // order is center, then left, then right.
  targetPosition: Vector2(475, 950),
  targetRadius: 55,
  additionalTargets: [
    TargetSpec(position: Vector2(150, 200), radius: 55),
    TargetSpec(position: Vector2(800, 200), radius: 55),
  ],
  playBounds: const Rect.fromLTWH(0, 0, 950, 1300),
);

final LevelData _blackHoleIntro = LevelData(
  id: 'black-hole-intro',
  name: 'Event Horizon',
  rocketStart: Vector2(450, 1230),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 220,
  maxLaunchSpeed: 520,
  // No planets: nothing else to plan around yet — just aim into the hole
  // and see what "portal, not planet" means. Its own gravity is strong
  // enough on its own to bend a wide range of approach angles toward it.
  blackHoles: [
    BlackHoleSpec(
      position: Vector2(450, 650),
      radius: 34,
      mass: 11000,
      exitPosition: Vector2(760, 200),
      // Slowed on exit so the sudden re-emergence right next to the
      // target reads as a gentle arrival, not an overshoot — this is the
      // one level in the tier that leans on exitVelocityScale to make the
      // very first capture forgiving.
      exitVelocityScale: 0.5,
    ),
  ],
  targetPosition: Vector2(770, 190),
  targetRadius: 70,
  playBounds: const Rect.fromLTWH(0, 0, 900, 1300),
);

final LevelData _blackHoleFlyby = LevelData(
  id: 'black-hole-flyby',
  name: 'Flyby',
  rocketStart: Vector2(450, 1230),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 230,
  maxLaunchSpeed: 540,
  // A planet now shares the sky with the hole — the player has to decide
  // whether to swing past it for a gravity assist into the hole, or steer
  // wide of it entirely. Unlike the intro, the exit hands the incoming
  // velocity straight back (scale 1.0): how fast and from what angle the
  // hole is entered now directly shapes the shot that comes out the other
  // side.
  planets: [
    PlanetSpec(
      position: Vector2(300, 750),
      mass: 2600,
      radius: 50,
      color: const Color(0xFFFF9142),
    ),
  ],
  blackHoles: [
    BlackHoleSpec(
      position: Vector2(700, 450),
      radius: 32,
      mass: 10000,
      exitPosition: Vector2(200, 180),
    ),
  ],
  targetPosition: Vector2(150, 150),
  targetRadius: 65,
  playBounds: const Rect.fromLTWH(0, 0, 900, 1300),
);

final LevelData _blackHoleCorridor = LevelData(
  id: 'black-hole-corridor',
  name: 'Tight Corridor',
  rocketStart: Vector2(475, 1330),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 230,
  maxLaunchSpeed: 540,
  // A no-fly zone now sits squarely on the naive straight shot up toward
  // the target, so a player who ignores the hole has to route carefully
  // around it (or slingshot off the planet). Diving into the hole instead
  // sidesteps the corridor entirely and re-emerges past it — but the exit
  // is boosted (scale 1.4) precisely because the hole's own gravity keeps
  // pulling after the teleport, and a slow exit would just fall straight
  // back in.
  planets: [
    PlanetSpec(
      position: Vector2(300, 850),
      mass: 2400,
      radius: 48,
      color: const Color(0xFF4CE0B3),
    ),
  ],
  blackHoles: [
    BlackHoleSpec(
      position: Vector2(650, 700),
      radius: 40,
      mass: 11000,
      exitPosition: Vector2(350, 320),
      exitVelocityScale: 1.4,
    ),
  ],
  noFlyZones: [NoFlyZoneSpec(position: Vector2(620, 550), radius: 80)],
  targetPosition: Vector2(700, 150),
  targetRadius: 70,
  playBounds: const Rect.fromLTWH(0, 0, 950, 1400),
);

final LevelData _blackHoleGauntlet = LevelData(
  id: 'black-hole-gauntlet',
  name: 'Singularity Gauntlet',
  rocketStart: Vector2(475, 1380),
  baseLaunchAngleDeg: _straightUpDeg,
  launchAngleRangeDeg: 90,
  minLaunchSpeed: 220,
  maxLaunchSpeed: 560,
  // The capstone: a planet to route around, a wind zone drifting the
  // approach sideways, and a hole with a boosted (1.3x) exit — every
  // earlier lesson in this tier (planning the approach, respecting the
  // hole's lingering pull after exit, reading a non-gravity force) has to
  // come together to land the exit on the target.
  planets: [
    PlanetSpec(
      position: Vector2(300, 900),
      mass: 2800,
      radius: 52,
      color: const Color(0xFFFF6584),
    ),
  ],
  windZones: [
    WindZoneSpec(
      position: Vector2(650, 700),
      radius: 140,
      forceDirectionDeg: 0,
      forceMagnitude: 130,
    ),
  ],
  blackHoles: [
    BlackHoleSpec(
      position: Vector2(600, 450),
      radius: 30,
      mass: 12000,
      exitPosition: Vector2(250, 200),
      exitVelocityScale: 1.3,
    ),
  ],
  targetPosition: Vector2(200, 150),
  targetRadius: 55,
  playBounds: const Rect.fromLTWH(0, 0, 950, 1450),
);

/// The full level roster: 3 hand-tuned levels teaching the mechanic, then
/// 25 procedurally-generated levels of increasing difficulty (5 tiers of
/// 1-5 planets), then 8 tier-6 levels adding no-fly zone hazards, then 8
/// tier-7 levels combining planets + no-fly zones + a maxShots fuel
/// budget, then 5 tier-8 levels adding wind zones, then 3 hand-tuned
/// showcase levels for moving planets, wormholes, and multi-target wins,
/// then 4 hand-tuned levels introducing repulsor planets (negative mass,
/// same inverse-square gravity, but pushing the rocket away instead of
/// pulling it in), ramping from an isolated repulsor up to a repulsor
/// combined with the existing moving-planet mechanic, then 4 hand-tuned
/// levels introducing ordered targets (the rocket must hit `targets` in
/// list order — primary target, then additionalTargets in sequence;
/// hitting a later target early simply doesn't register yet), ramping
/// from an isolated two-target intro up through a there-and-back relay,
/// an orbiting-planet timing puzzle, and a symmetric-decoy gauntlet, then
/// 4 hand-tuned levels introducing black holes (an extreme, high-mass
/// gravity well the rocket is funneled into and re-emerges from
/// elsewhere — portal-like, but unlike a wormhole it actively pulls the
/// rocket in and the puzzle is managing the approach/exit vector rather
/// than precise aim), ramping from an isolated capture-and-arrive intro,
/// through combining it with a planet to slingshot past, then a no-fly
/// zone blocking the naive direct route, up to a capstone combining a
/// planet, a wind zone, and a boosted exit (64 levels, 13 tiers total
/// including the tutorial).
final List<LevelData> kLevels = [
  _firstOrbit,
  _slingshot,
  _threadingTheNeedle,
  ..._generatedLevels,
  ..._tier6Levels,
  ..._tier7Levels,
  ..._tier8Levels,
  _orbitalDance,
  _wormholeShortcut,
  _twinTargets,
  _repulsorIntro,
  _repulsorGauntlet,
  _repulsorSlalom,
  _repulsorOrbitBreak,
  _sequenceIntro,
  _sequenceSlingshotRelay,
  _sequenceOrbitalCheckpoints,
  _sequenceGauntletLoop,
  _blackHoleIntro,
  _blackHoleFlyby,
  _blackHoleCorridor,
  _blackHoleGauntlet,
];

/// Describes one named, contiguous section of [kLevels] for level-select
/// grouping. Built directly from the same private level lists used to
/// assemble [kLevels] above, so tier boundaries can never drift out of
/// sync with the real roster.
class LevelSection {
  const LevelSection({required this.title, required this.levels});

  final String title;
  final List<LevelData> levels;
}

final List<LevelSection> kLevelSections = [
  LevelSection(
    title: 'Tutorial',
    levels: [_firstOrbit, _slingshot, _threadingTheNeedle],
  ),
  LevelSection(
    title: 'Tier 1 · Single Planet',
    levels: _generatedLevels.sublist(0, 5),
  ),
  LevelSection(
    title: 'Tier 2 · Twin Planets',
    levels: _generatedLevels.sublist(5, 10),
  ),
  LevelSection(
    title: 'Tier 3 · Triple Planets',
    levels: _generatedLevels.sublist(10, 15),
  ),
  LevelSection(
    title: 'Tier 4 · Four Planets',
    levels: _generatedLevels.sublist(15, 20),
  ),
  LevelSection(
    title: 'Tier 5 · Five Planets',
    levels: _generatedLevels.sublist(20, 25),
  ),
  LevelSection(title: 'Tier 6 · No-Fly Zones', levels: _tier6Levels),
  LevelSection(title: 'Tier 7 · Fuel & Hazards', levels: _tier7Levels),
  LevelSection(title: 'Tier 8 · Wind Zones', levels: _tier8Levels),
  LevelSection(
    title: 'Tier 9 · Showcase',
    levels: [_orbitalDance, _wormholeShortcut, _twinTargets],
  ),
  LevelSection(
    title: 'Tier 10 · Repulsors',
    levels: [
      _repulsorIntro,
      _repulsorGauntlet,
      _repulsorSlalom,
      _repulsorOrbitBreak,
    ],
  ),
  LevelSection(
    title: 'Tier 11 · Sequence',
    levels: [
      _sequenceIntro,
      _sequenceSlingshotRelay,
      _sequenceOrbitalCheckpoints,
      _sequenceGauntletLoop,
    ],
  ),
  LevelSection(
    title: 'Tier 12 · Black Holes',
    levels: [
      _blackHoleIntro,
      _blackHoleFlyby,
      _blackHoleCorridor,
      _blackHoleGauntlet,
    ],
  ),
];

/// Finds which [kLevelSections] entry contains the level with [levelId],
/// returning its [LevelSection.title], or null if none does (defensive
/// — every real level belongs to exactly one section by construction,
/// since kLevelSections is built from the same lists that assemble
/// kLevels).
String? tierTitleForLevel(String levelId) {
  for (final section in kLevelSections) {
    if (section.levels.any((level) => level.id == levelId)) {
      return section.title;
    }
  }
  return null;
}
