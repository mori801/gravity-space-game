import 'package:flutter/material.dart';

import '../game/levels/levels.dart';
import '../game/progress.dart';
import '../game/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _hapticsEnabled = GameSettings.instance.hapticsEnabled;

  void _toggleHaptics(bool value) {
    setState(() => _hapticsEnabled = value);
    GameSettings.instance.hapticsEnabled = value;
    if (value) {
      GameSettings.instance.selectionClick();
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'This clears every unlocked level and star rating. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => LevelProgress.instance.resetProgress());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress reset')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(
              '${LevelProgress.instance.wonLevelIds.length} / ${kLevels.length} levels completed',
            ),
            subtitle: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text('${LevelProgress.instance.totalStars} / ${kLevels.length * 3} stars'),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Haptics'),
            subtitle: const Text('Vibrate on taps and launches'),
            value: _hapticsEnabled,
            onChanged: _toggleHaptics,
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Reset Progress'),
            subtitle: const Text('Clear all unlocked levels and stars'),
            onTap: _confirmReset,
          ),
        ],
      ),
    );
  }
}
