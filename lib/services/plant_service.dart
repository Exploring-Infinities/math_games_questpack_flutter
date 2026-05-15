import '../storage/game_prefs.dart';
import '../storage/prefs_keys.dart';

/// Stage thresholds (total waters) — matches [PlantStreak.tsx].
const stageThresholds = [1, 3, 6, 10, 15, 21, 28];

const stageNames = <String>[
  'Empty Pot',
  'First Sprout',
  'Seedling',
  'Growing',
  'Lush',
  'Tall',
  'Budding',
  'In Bloom',
];

String _todayStr() {
  final d = DateTime.now().toUtc();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String _yesterdayStr() {
  final d = DateTime.now().toUtc().subtract(const Duration(days: 1));
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

int calcPlantStage(int waters) {
  if (waters == 0) return 0;
  if (waters <= 2) return 1;
  if (waters <= 5) return 2;
  if (waters <= 9) return 3;
  if (waters <= 14) return 4;
  if (waters <= 20) return 5;
  if (waters <= 27) return 6;
  return 7;
}

class PlantData {
  const PlantData({
    required this.streak,
    required this.totalWaters,
    required this.stage,
    required this.stageName,
    required this.waterAvailable,
    required this.wateredToday,
    required this.missedDay,
    required this.nextThreshold,
    required this.daysToNext,
    required this.growthPct,
  });

  final int streak;
  final int totalWaters;
  final int stage;
  final String stageName;
  final bool waterAvailable;
  final bool wateredToday;
  final bool missedDay;
  final int? nextThreshold;
  final int? daysToNext;
  final int growthPct;
}

class PlantService {
  static int get plantStreak =>
      GamePrefs.instance.getInt(PrefsKeys.plantStreak);

  static int get totalWaters =>
      GamePrefs.instance.getInt(PrefsKeys.plantTotalWaters);

  static String get lastWatered =>
      GamePrefs.instance.getString(PrefsKeys.plantLastWatered);

  static String get activityDate =>
      GamePrefs.instance.getString(PrefsKeys.plantActivityDate);

  static String get plantName =>
      GamePrefs.instance.getString(PrefsKeys.plantName);

  static Future<void> savePlantName(String name) =>
      GamePrefs.instance.setString(PrefsKeys.plantName, name);

  /// Idempotent — call when a game session completes meaningful activity.
  static Future<void> markActivityDone() =>
      GamePrefs.instance.setString(PrefsKeys.plantActivityDate, _todayStr());

  static PlantData getPlantData() {
    final streak = plantStreak;
    final waters = totalWaters;
    final last = lastWatered;
    final today = _todayStr();
    final yesterday = _yesterdayStr();
    final stage = calcPlantStage(waters);
    final act = activityDate;

    final wateredToday = last == today;
    final waterAvailable = act == today && !wateredToday;
    final missedDay =
        !wateredToday && last.isNotEmpty && last != yesterday && streak > 0;

    int? nextThreshold;
    for (final t in stageThresholds) {
      if (t > waters) {
        nextThreshold = t;
        break;
      }
    }
    final daysToNext = nextThreshold != null ? nextThreshold - waters : null;
    final prevThreshold = stage > 0 ? stageThresholds[stage - 1] : 0;
    int growthPct = 100;
    if (nextThreshold != null) {
      final span = nextThreshold - prevThreshold;
      if (span > 0) {
        growthPct =
            ((waters - prevThreshold) / span * 100).round().clamp(0, 100);
      }
    }

    return PlantData(
      streak: streak,
      totalWaters: waters,
      stage: stage,
      stageName: stageNames[stage.clamp(0, stageNames.length - 1)],
      waterAvailable: waterAvailable,
      wateredToday: wateredToday,
      missedDay: missedDay,
      nextThreshold: nextThreshold,
      daysToNext: daysToNext,
      growthPct: growthPct,
    );
  }

  /// DEV helper parity with web: simulate N consecutive watering days.
  static Future<void> simulateGrowth(int addDays) async {
    if (addDays <= 0) return;
    final prefs = GamePrefs.instance;
    final today = _todayStr();
    final newStreak = plantStreak + addDays;
    final newWaters = totalWaters + addDays;
    await prefs.setInt(PrefsKeys.plantStreak, newStreak);
    await prefs.setInt(PrefsKeys.plantTotalWaters, newWaters);
    await prefs.setString(PrefsKeys.plantLastWatered, today);
    await prefs.setString(PrefsKeys.plantActivityDate, today);
  }

  static Future<PlantData> performWatering() async {
    final prefs = GamePrefs.instance;
    final last = lastWatered;
    final yesterday = _yesterdayStr();
    var streak = plantStreak;
    streak = last == yesterday ? streak + 1 : 1;
    final newWaters = totalWaters + 1;
    await prefs.setInt(PrefsKeys.plantStreak, streak);
    await prefs.setInt(PrefsKeys.plantTotalWaters, newWaters);
    await prefs.setString(PrefsKeys.plantLastWatered, _todayStr());
    return getPlantData();
  }
}
