import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_keys.dart';

/// Global prefs accessor; initialized in [GamePrefs.init].
class GamePrefs {
  GamePrefs(this._p);

  static GamePrefs? _instance;
  static GamePrefs get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('GamePrefs not initialized. Call GamePrefs.init() first.');
    }
    return i;
  }

  final SharedPreferences _p;

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _instance = GamePrefs(p);
  }

  int getInt(String key, [int fallback = 0]) => _p.getInt(key) ?? fallback;

  Future<void> setInt(String key, int v) => _p.setInt(key, v);

  String getString(String key, [String fallback = '']) =>
      _p.getString(key) ?? fallback;

  Future<void> setString(String key, String v) => _p.setString(key, v);

  String? getStringOrNull(String key) => _p.getString(key);

  Future<void> remove(String key) => _p.remove(key);

  // --- Typed helpers ---

  int get totalCorrect => getInt(PrefsKeys.totalCorrect);
  Future<void> setTotalCorrect(int n) => setInt(PrefsKeys.totalCorrect, n);

  /// Per-game consecutive correct (Equation Balance).
  int get equationStreak => getInt(PrefsKeys.streak);
  Future<void> setEquationStreak(int n) => setInt(PrefsKeys.streak, n);

  int get dailyStreak => getInt(PrefsKeys.dailyStreak);
  Future<void> setDailyStreak(int n) => setInt(PrefsKeys.dailyStreak, n);

  int get totalSolved => getInt(PrefsKeys.totalSolved);
  Future<void> setTotalSolved(int n) => setInt(PrefsKeys.totalSolved, n);

  String get lastActivityDate => getString(PrefsKeys.lastActivityDate);

  Future<void> setLastActivityDate(String d) =>
      setString(PrefsKeys.lastActivityDate, d);

  int get timePlayedSecs => getInt(PrefsKeys.timePlayed);

  Future<void> addTimePlayed(int seconds) async {
    final prev = timePlayedSecs;
    await setInt(PrefsKeys.timePlayed, prev + seconds);
  }

  String get playerId {
    var id = getStringOrNull(PrefsKeys.playerId);
    if (id == null || id.isEmpty) {
      id = 'player_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      _p.setString(PrefsKeys.playerId, id);
    }
    return id;
  }

  int get ninjaCorrect => getInt(PrefsKeys.ninjaCorrect);
  Future<void> addNinjaCorrect(int n) =>
      setInt(PrefsKeys.ninjaCorrect, ninjaCorrect + n);

  int get flipQuestLevel {
    final v = getInt(PrefsKeys.flipQuestLevel, 1);
    return v < 1 ? 1 : v;
  }

  Future<void> setFlipQuestLevel(int lv) =>
      setInt(PrefsKeys.flipQuestLevel, lv);

  int get tetrisBest => getInt(PrefsKeys.tetrisBest);
  Future<void> saveTetrisBestIfHigher(int n) async {
    if (n > tetrisBest) await setInt(PrefsKeys.tetrisBest, n);
  }

  int get numberCrushLevel => getInt(PrefsKeys.numberCrushLevel);
  Future<void> setNumberCrushLevel(int l) =>
      setInt(PrefsKeys.numberCrushLevel, l);
}
