import 'package:flutter/material.dart';

import '../../game/gravity_rocket_game.dart';

/// Pre-launch: lets the player set launch power and angle and fire the
/// rocket. Post-launch: shows a single pause button. Shown/hidden by
/// [GameScreen] via Flame's overlay system.
class HudOverlay extends StatefulWidget {
  const HudOverlay({super.key, required this.game});

  final GravityRocketGame game;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  double _power = 0.6;
  double _angleOffset = 0.0;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    if (game.status != GameStatus.ready) {
      return SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IconButton.filled(
              icon: const Icon(Icons.pause),
              onPressed: () {
                game.pauseEngine();
                game.overlays.add('PauseMenu');
              },
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: Colors.black.withOpacity(0.6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSliderRow(
                    label: 'Power',
                    value: _power,
                    onChanged: (value) => setState(() => _power = value),
                  ),
                  _buildSliderRow(
                    label: 'Angle',
                    value: (_angleOffset + 1) / 2,
                    onChanged: (value) =>
                        setState(() => _angleOffset = value * 2 - 1),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => game.launch(
                      power: _power,
                      angleOffset: _angleOffset,
                    ),
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Launch'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: const TextStyle(color: Colors.white)),
        ),
        Expanded(
          child: Slider(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}
