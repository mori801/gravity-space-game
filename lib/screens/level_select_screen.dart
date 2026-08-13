import 'package:flutter/material.dart';

import '../game/levels/level.dart';
import '../game/levels/levels.dart';
import '../game/progress.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  /// Pushes the game screen and, once the player returns here directly
  /// (e.g. a hardware/gesture back press rather than one of WinOverlay's
  /// own buttons, which instead pop past this screen entirely and push a
  /// brand-new instance that already reads fresh state), refreshes this
  /// screen's lock/cleared state. `mounted` guards the case where this
  /// screen was itself popped away in the meantime.
  Future<void> _openLevel(LevelData level) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(level: level)),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = LevelProgress.instance;

    final items = <Widget>[];
    var index = 0;
    for (final section in kLevelSections) {
      items.add(_SectionHeader(label: section.title));
      for (final level in section.levels) {
        items.add(
          _LevelTile(
            index: index,
            level: level,
            unlocked: isLevelUnlocked(index, kLevels, progress),
            stars: progress.bestStars(level.id),
            onTap: _openLevel,
          ),
        );
        index++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Level'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text('${progress.totalStars}/${kLevels.length * 3}'),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(children: items),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.index,
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  final int index;
  final LevelData level;
  final bool unlocked;
  final int stars;
  final void Function(LevelData level) onTap;

  @override
  Widget build(BuildContext context) {
    final disabledColor = Theme.of(context).disabledColor;
    final won = stars > 0;
    return ListTile(
      enabled: unlocked,
      leading: CircleAvatar(
        backgroundColor: unlocked
            ? Theme.of(context).colorScheme.primaryContainer
            : disabledColor.withOpacity(0.2),
        child: !unlocked
            ? Icon(Icons.lock, size: 18, color: disabledColor)
            : (won
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  )
                : Text('${index + 1}')),
      ),
      title: Text(level.name),
      subtitle: !unlocked ? const Text('Clear the previous level to unlock') : null,
      trailing: unlocked
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (won) _StarRow(stars: stars),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            )
          : null,
      onTap: unlocked ? () => onTap(level) : null,
    );
  }
}

/// Three-icon star display: filled up to [stars], outlined after that.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Icon(
          i < stars ? Icons.star : Icons.star_border,
          size: 16,
          color: i < stars ? Colors.amber : Colors.grey,
        ),
      ),
    );
  }
}
