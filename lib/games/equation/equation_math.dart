import 'dart:math';

/// Ported from [EquationBalance.tsx] — equation generator & level bands.
const answersPerLevel = 10;

class Equation {
  const Equation(this.display, this.answer);
  final String display;
  final int answer;
}

class LevelInfo {
  const LevelInfo(this.name, this.desc);
  final String name;
  final String desc;
}

const levelInfoList = <LevelInfo>[
  LevelInfo('STARTER', 'Addition & Subtraction'),
  LevelInfo('RISING', 'All Four Operations'),
  LevelInfo('SHARP', 'Bigger Numbers'),
  LevelInfo('EXPERT', 'Complex Equations'),
  LevelInfo('ELITE', 'Master-Level Problems'),
];

LevelInfo getLevelInfo(int level) {
  final idx = (level - 1).clamp(0, levelInfoList.length - 1);
  return levelInfoList[idx];
}

int calcLevelFromTotal(int total) => (total ~/ answersPerLevel) + 1;

int calcProgressInLevel(int total) => total % answersPerLevel;

int randBetween(Random rng, int min, int max) =>
    min + rng.nextInt(max - min + 1);

Equation generateEquation(Random rng, int level) {
  final lvl = min(level, 5);
  final ops = lvl >= 2 ? [0, 1, 2, 3] : [0, 1];
  final op = ops[rng.nextInt(ops.length)];

  final addMax = [0, 10, 14, 18, 22, 25][lvl];
  final mulMax = [0, 0, 5, 7, 9, 11][lvl];

  late int a, b, answer;
  late String display;
  switch (op) {
    case 0:
      a = randBetween(rng, 1, addMax);
      b = randBetween(rng, 1, addMax);
      answer = a + b;
      display = '$a + $b';
      break;
    case 1:
      final minA = addMax ~/ 2;
      a = randBetween(rng, minA, addMax + minA);
      b = randBetween(rng, 1, minA);
      answer = a - b;
      display = '$a − $b';
      break;
    case 2:
      a = randBetween(rng, 2, mulMax);
      b = randBetween(rng, 2, mulMax);
      answer = a * b;
      display = '$a × $b';
      break;
    default:
      b = randBetween(rng, 2, mulMax);
      answer = randBetween(rng, 2, mulMax);
      a = b * answer;
      display = '$a ÷ $b';
      break;
  }
  return Equation(display, answer);
}

String todayIsoDate() {
  final d = DateTime.now().toUtc();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String yesterdayIsoDate() {
  final d = DateTime.now().toUtc().subtract(const Duration(days: 1));
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
