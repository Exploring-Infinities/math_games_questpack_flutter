import 'dart:convert';

import '../models/lb_entry.dart';
import '../storage/game_prefs.dart';
import '../storage/prefs_keys.dart';

/// Equation Balance leaderboard (matches React `getLB` / `saveLBEntry`).
class LeaderboardService {
  static const _seeds = <LbEntry>[
    LbEntry(
        id: 'seed1',
        name: 'AceRocket',
        level: 4,
        totalSolved: 41,
        totalCorrect: 38),
    LbEntry(
        id: 'seed2',
        name: 'StarKid',
        level: 3,
        totalSolved: 29,
        totalCorrect: 27),
    LbEntry(
        id: 'seed3',
        name: 'QuickFox',
        level: 2,
        totalSolved: 22,
        totalCorrect: 19),
    LbEntry(
        id: 'seed4',
        name: 'MathWiz',
        level: 2,
        totalSolved: 16,
        totalCorrect: 14),
    LbEntry(
        id: 'seed5',
        name: 'BrainBolt',
        level: 1,
        totalSolved: 8,
        totalCorrect: 7),
  ];

  static List<LbEntry> get equationBalance {
    final raw = GamePrefs.instance.getStringOrNull(PrefsKeys.lbEquationBalance);
    if (raw == null || raw.isEmpty) return List.from(_seeds);
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => LbEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final ids = list.map((e) => e.id).toSet();
      for (final s in _seeds) {
        if (!ids.contains(s.id)) list.add(s);
      }
      return list;
    } catch (_) {
      return List.from(_seeds);
    }
  }

  static Future<void> saveEquationBalance(LbEntry entry) async {
    final entries = List<LbEntry>.from(equationBalance);
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      entries.add(entry);
    }
    final encoded =
        jsonEncode(entries.map((e) => e.toJson()).toList());
    await GamePrefs.instance.setString(PrefsKeys.lbEquationBalance, encoded);
  }
}
