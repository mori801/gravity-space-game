import 'package:flutter/material.dart';

/// Wraps [child] with a quick press-down/settle scale "kick" — the same
/// 260ms `Curves.easeOutBack` pop used by the HUD's power button and the
/// pause overlay, so every overlay in the app shares one tactile feel.
/// Uses a [Listener] rather than a [GestureDetector] so it only observes
/// raw pointer events and never competes with the wrapped
/// button/GestureDetector's own tap handling for the gesture.
class AnimatedPressScale extends StatefulWidget {
  const AnimatedPressScale({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedPressScale> createState() => _AnimatedPressScaleState();
}

class _AnimatedPressScaleState extends State<AnimatedPressScale> {
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
