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
      mass: 3500,
      radius: 55,
      color: Color(0xFFFF9142),
    ),
    PlanetSpec(
      position: Vector2(650, 400),
      mass: 2500,
      radius: 45,
      color: Color(0xFFB06CFF),
    ),
  ],
  targetPosition: Vector2(750, 120),
  targetRadius: 60,
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
      mass: 2800,
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
  targetRadius: 45,
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
    targetRadius: 68.0 - tier * 8 - indexInTier * 2,
    targetXFrac: indexInTier.isEven ? 0.75 : 0.25,
    planetMasses: planetMasses,
    planetRadii: planetRadii,
    planetColors: planetColors,
  );
});

/// The full level roster: 3 hand-tuned levels teaching the mechanic, then
/// 25 procedurally-generated levels of increasing difficulty.
final List<LevelData> kLevels = [
  _firstOrbit,
  _slingshot,
  _threadingTheNeedle,
  ..._generatedLevels,
];
