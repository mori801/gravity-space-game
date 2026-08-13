import 'package:flutter/material.dart';

import '../game/levels/levels.dart';
import '../game/progress/level_progress.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  static final List<String> _levelIds = kLevels.map((l) => l.id).toList();

  late Future<LevelProgress> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressFuture = LevelProgress.load();
  }

  /// Re-reads progress after returning from a level, so a just-earned
  /// unlock/star shows up immediately without leaving and re-entering
  /// this screen.
  void _refreshProgress() {
    setState(() {
      _progressFuture = LevelProgress.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Level')),
      body: FutureBuilder<LevelProgress>(
        future: _progressFuture,
        builder: (context, snapshot) {
          final progress = snapshot.data;
          if (progress == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: kLevels.length,
            itemBuilder: (context, index) {
              final level = kLevels[index];
              final unlocked = progress.isUnlocked(level.id, _levelIds);
              final stars = progress.starsFor(level.id);
              return ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(level.name),
                subtitle: unlocked ? _StarRow(stars: stars) : null,
                trailing: Icon(unlocked ? Icons.chevron_right : Icons.lock),
                enabled: unlocked,
                onTap: unlocked
                    ? () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GameScreen(level: level),
                          ),
                        );
                        if (!mounted) return;
                        _refreshProgress();
                      }
                    : null,
              );
            },
          );
        },
      ),
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
