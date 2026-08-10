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
  launchAngleRangeDeg: 30,
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
  launchAngleRangeDeg: 35,
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
  launchAngleRangeDeg: 40,
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

/// The MVP's three hand-tuned levels, in increasing order of difficulty.
final List<LevelData> kLevels = [
  _firstOrbit,
  _slingshot,
  _threadingTheNeedle,
];
