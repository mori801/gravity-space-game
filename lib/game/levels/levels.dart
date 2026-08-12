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
    targetRadius: _generatedTargetRadiusOverrideByListIndex[i] ?? (68.0 - tier * 8 - indexInTier * 2),
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
    minSpeed: 230.0 + idx * 6,
    maxSpeed: 530.0 + idx * 6,
    targetRadius: 42.0 - idx * 1.5,
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
  0: 6, 1: 6, 2: 5, 3: 5, 4: 4, 5: 4, 6: 3, 7: 3,
};

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
    minSpeed: 240.0 + idx * 6,
    maxSpeed: 540.0 + idx * 6,
    targetRadius: 40.0 - idx * 1.5,
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
                (windZoneCount == 1 ? 0.5 : 0.25 + 0.5 * z / (windZoneCount - 1)),
      ),
      radius: 130.0 + idx * 10,
      forceDirectionDeg: forceDirectionDeg,
      forceMagnitude: 120.0 + idx * 15,
    ),
  );

  return _generatedLevel(
    id: 'level-${45 + idx}',
    name: _tier8LevelNames[idx],
    width: width,
    height: height,
    launchAngleRangeDeg: 90.0,
    minSpeed: 260.0 + idx * 6,
    maxSpeed: 560.0 + idx * 6,
    targetRadius: 46.0 - idx * 2,
    targetXFrac: pushRight ? 0.78 : 0.22,
    planetMasses: planetMasses,
    planetRadii: planetRadii,
    planetColors: planetColors,
    windZones: windZones,
  );
});

/// The full level roster: 3 hand-tuned levels teaching the mechanic, then
/// 25 procedurally-generated levels of increasing difficulty (5 tiers of
/// 1-5 planets), then 8 tier-6 levels adding no-fly zone hazards, then 8
/// tier-7 levels combining planets + no-fly zones + a maxShots fuel
/// budget, then 5 tier-8 levels adding wind zones (49 levels, 9 tiers
/// total including the tutorial).
final List<LevelData> kLevels = [
  _firstOrbit,
  _slingshot,
  _threadingTheNeedle,
  ..._generatedLevels,
  ..._tier6Levels,
  ..._tier7Levels,
  ..._tier8Levels,
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
];
