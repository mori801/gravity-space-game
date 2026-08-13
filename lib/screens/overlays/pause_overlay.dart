import 'package:flutter/material.dart';

import '../../game/gravity_rocket_game.dart';
import '../../game/settings.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});

  final GravityRocketGame game;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Paused', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 20),
              // Resume is the fastest way back into the action, so it's
              // the clearly biggest, most prominent button of the three —
              // same spirit as the primary action on the win/lose overlays.
              _AnimatedPressScale(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 28),
                    onPressed: () {
                      GameSettings.instance.selectionClick();
                      game.overlays.remove('PauseMenu');
                      game.resumeEngine();
                    },
                    label: const Text('Resume'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _AnimatedPressScale(
                child: OutlinedButton(
                  onPressed: () {
                    GameSettings.instance.selectionClick();
                    game.overlays.remove('PauseMenu');
                    game.resetLevel();
                  },
                  child: const Text('Restart'),
                ),
              ),
              const SizedBox(height: 4),
              _AnimatedPressScale(
                child: TextButton(
                  onPressed: () {
                    GameSettings.instance.selectionClick();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Menu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps [child] with a quick press-down/settle scale "kick", echoing the
/// tactile feedback of the HUD's power button (see `hud_overlay.dart`'s
/// `_kickController`/`_kickScale`): shrinks slightly while held, then
/// eases back to full size with the same 260ms `Curves.easeOutBack` pop
/// used there. Uses a [Listener] rather than a [GestureDetector] so it
/// only observes raw pointer events and never competes with the wrapped
/// button's own tap handling for the gesture.
class _AnimatedPressScale extends StatefulWidget {
  const _AnimatedPressScale({required this.child});

  final Widget child;

  @override
  State<_AnimatedPressScale> createState() => _AnimatedPressScaleState();
}

class _AnimatedPressScaleState extends State<_AnimatedPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
