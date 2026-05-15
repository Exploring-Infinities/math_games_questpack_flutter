import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';
import '../services/plant_service.dart';
import '../storage/game_prefs.dart';

enum _Phase { start, memorize, question, reveal, levelUp, end }
enum _Op { add, sub, mul }

class _LevelCfg {
  const _LevelCfg({
    required this.cards,
    required this.revealSecs,
    required this.ops,
    required this.range,
  });

  final int cards;
  final int revealSecs;
  final List<_Op> ops;
  final (int, int) range;
}

class _Question {
  const _Question({required this.text, required this.answer});
  final String text;
  final int answer;
}

class _CardState {
  _CardState({
    required this.id,
    required this.value,
  });

  final int id;
  final int value;
  bool faceDown = false;
  bool revealed = false;
  bool correct = false;
  bool wrong = false;
}

const _levelCfgs = <_LevelCfg>[
  _LevelCfg(cards: 4, revealSecs: 4, ops: [_Op.add], range: (2, 8)),
  _LevelCfg(cards: 4, revealSecs: 4, ops: [_Op.add], range: (3, 10)),
  _LevelCfg(cards: 6, revealSecs: 3, ops: [_Op.add, _Op.sub], range: (3, 12)),
  _LevelCfg(cards: 6, revealSecs: 3, ops: [_Op.add, _Op.sub], range: (4, 14)),
  _LevelCfg(cards: 6, revealSecs: 3, ops: [_Op.add, _Op.sub, _Op.mul], range: (2, 9)),
  _LevelCfg(cards: 8, revealSecs: 3, ops: [_Op.add, _Op.sub, _Op.mul], range: (2, 9)),
  _LevelCfg(cards: 8, revealSecs: 2, ops: [_Op.add, _Op.sub, _Op.mul], range: (3, 12)),
  _LevelCfg(cards: 9, revealSecs: 2, ops: [_Op.add, _Op.sub, _Op.mul], range: (3, 12)),
];

const _levelNames = ['NOVICE', 'SEEKER', 'THINKER', 'SHARP', 'SWIFT', 'MASTER', 'LEGEND', 'SUPREME'];

_LevelCfg _cfgFor(int level) => _levelCfgs[math.min(level - 1, _levelCfgs.length - 1)];
String _levelName(int level) => _levelNames[math.min(level - 1, _levelNames.length - 1)];
int _cols(int count) => count <= 4 ? 2 : count == 9 ? 3 : count <= 6 ? 3 : 4;

class FlipQuestScreen extends StatefulWidget {
  const FlipQuestScreen({super.key});

  @override
  State<FlipQuestScreen> createState() => _FlipQuestScreenState();
}

class _FlipQuestScreenState extends State<FlipQuestScreen> {
  final _rng = math.Random();
  _Phase _phase = _Phase.start;

  int _level = 1;
  int _lives = 3;
  int _score = 0;
  int _combo = 0;
  int _sessionCorrect = 0;
  int _countdown = 4;
  int _levelUpFrom = 1;
  int _levelUpTo = 2;

  _Question _question = const _Question(text: '', answer: 0);
  List<_CardState> _cards = [];

  String? _feedText;
  bool _feedGood = false;
  DateTime _startTime = DateTime.now();
  bool _sessionStored = false;
  Timer? _countTimer;
  Timer? _nextTimer;
  Timer? _feedTimer;

  @override
  void initState() {
    super.initState();
    _level = GamePrefs.instance.flipQuestLevel;
  }

  @override
  void dispose() {
    _clearTimers();
    super.dispose();
  }

  void _clearTimers() {
    _countTimer?.cancel();
    _nextTimer?.cancel();
    _feedTimer?.cancel();
    _countTimer = null;
    _nextTimer = null;
    _feedTimer = null;
  }

  int _ri(int a, int b) => a + _rng.nextInt(b - a + 1);

  _Question _makeQuestion(int level) {
    final cfg = _cfgFor(level);
    final op = cfg.ops[_rng.nextInt(cfg.ops.length)];
    final (lo, hi) = cfg.range;
    if (op == _Op.add) {
      final a = _ri(lo, hi), b = _ri(lo, hi);
      return _Question(text: '$a + $b', answer: a + b);
    }
    if (op == _Op.sub) {
      final a = _ri(lo + 3, hi + 4);
      final b = _ri(lo, math.min(a - 1, hi));
      return _Question(text: '$a − $b', answer: a - b);
    }
    final a = _ri(2, 9), b = _ri(2, 9);
    return _Question(text: '$a × $b', answer: a * b);
  }

  List<int> _makeCardValues(int answer, int count, int level) {
    final set = <int>{answer};
    final spread = level <= 3 ? 10 : level <= 5 ? 16 : 22;
    var tries = 0;
    while (set.length < count && tries < 300) {
      tries++;
      final v = answer + _ri(-spread, spread);
      if (v > 0 && v != answer) set.add(v);
    }
    for (var fallback = 1; set.length < count; fallback++) {
      set.add(fallback);
    }
    return set.toList()..shuffle(_rng);
  }

  void _startRound(int lv) {
    _clearTimers();
    final q = _makeQuestion(lv);
    final cfg = _cfgFor(lv);
    final vals = _makeCardValues(q.answer, cfg.cards, lv);
    setState(() {
      _question = q;
      _cards = List.generate(vals.length, (i) => _CardState(id: i, value: vals[i]));
      _countdown = cfg.revealSecs;
      _phase = _Phase.memorize;
      _feedText = null;
    });

    var rem = cfg.revealSecs;
    _countTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      rem -= 1;
      if (!mounted) return;
      setState(() => _countdown = rem);
      if (rem <= 0) {
        timer.cancel();
        if (!mounted) return;
        setState(() {
          for (final c in _cards) {
            c.faceDown = true;
          }
          _phase = _Phase.question;
        });
      }
    });
  }

  Future<void> _onCardTap(_CardState card) async {
    if (_phase != _Phase.question) return;
    _clearTimers();
    final isRight = card.value == _question.answer;
    final newCombo = isRight ? _combo + 1 : 0;
    final mult = math.min(newCombo, 3);
    final pts = isRight ? 10 * mult : 0;
    final newLives = isRight ? _lives : _lives - 1;

    setState(() {
      for (final c in _cards) {
        if (c.id == card.id) {
          c.faceDown = false;
          c.revealed = true;
          c.correct = isRight;
          c.wrong = !isRight;
        }
      }
      _phase = _Phase.reveal;
      _combo = newCombo;
      _score += pts;
      _lives = newLives;
      _feedGood = isRight;
      _feedText = isRight ? (newCombo >= 3 ? 'x$mult COMBO!' : newCombo == 2 ? 'x2' : '+$pts') : 'Not quite!';
    });
    _feedTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _feedText = null);
    });

    if (isRight) {
      _sessionCorrect++;
      await PlantService.markActivityDone();
      if (_sessionCorrect % 5 == 0) {
        final nextLv = _level + 1;
        await GamePrefs.instance.setFlipQuestLevel(nextLv);
        if (!mounted) return;
        setState(() {
          _levelUpFrom = _level;
          _levelUpTo = nextLv;
          _level = nextLv;
          _phase = _Phase.levelUp;
        });
        _nextTimer = Timer(const Duration(milliseconds: 2400), () {
          if (mounted) _startRound(_level);
        });
        return;
      }
    }

    if (newLives <= 0) {
      await _storeSessionStats();
      _nextTimer = Timer(const Duration(milliseconds: 1050), () {
        if (!mounted) return;
        setState(() => _phase = _Phase.end);
      });
      return;
    }

    _nextTimer = Timer(Duration(milliseconds: isRight ? 680 : 1050), () {
      if (mounted) _startRound(_level);
    });
  }

  void _startGame() {
    _clearTimers();
    _level = GamePrefs.instance.flipQuestLevel;
    _lives = 3;
    _score = 0;
    _combo = 0;
    _sessionCorrect = 0;
    _feedText = null;
    _sessionStored = false;
    _startTime = DateTime.now();
    _startRound(_level);
  }

  Future<void> _storeSessionStats() async {
    if (_sessionStored) return;
    _sessionStored = true;
    final elapsed = DateTime.now().difference(_startTime).inSeconds;
    await GamePrefs.instance.addTimePlayed(elapsed);
  }

  void _toHome() {
    _clearTimers();
    context.goNamed(GameRouteNames.home);
  }

  Future<void> _showHowTo() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('How to Play'),
        content: const Text(
          '1) Memorize the shown numbers before timer ends.\n'
          '2) Cards flip to ? and a math expression appears.\n'
          '3) Tap the card hiding the correct answer.\n'
          '4) Combo multiplies points. 3 wrong answers ends run.\n'
          '5) Every 5 correct answers, you level up.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF88FFC0);
    final cfg = _cfgFor(_level);

    if (_phase == _Phase.start) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flip Quest')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MEMORY · MATH', style: TextStyle(color: Colors.white38, letterSpacing: 2)),
                const SizedBox(height: 8),
                const Text('FlipQuest', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Memorize cards, solve equation, find answer.', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFF0D0D0D), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('LV $_level  ·  ${_levelName(_level)}', style: const TextStyle(color: green, fontWeight: FontWeight.w800)),
                      Text('${cfg.cards} cards', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: _startGame, child: const Text('START QUEST'))),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _showHowTo, child: const Text('How to Play'))),
              ],
            ),
          ),
        ),
      );
    }

    if (_phase == _Phase.end) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flip Quest')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('GAME OVER', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('Score $_score', style: const TextStyle(fontSize: 24, color: green, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Level $_level · Correct $_sessionCorrect', style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 18),
                FilledButton(onPressed: _startGame, child: const Text('PLAY AGAIN')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _toHome, child: const Text('HOME')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Flip Quest · Lv $_level'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('$_score pts', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('♥' * _lives + '♡' * (3 - _lives), style: const TextStyle(fontSize: 18, color: Colors.redAccent)),
                      const Spacer(),
                      if (_combo >= 2) Text('COMBO x${math.min(_combo, 3)}', style: const TextStyle(color: green, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _phase == _Phase.memorize ? const Color(0xFF0D0D0D) : green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _phase == _Phase.memorize ? Colors.white10 : green.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _phase == _Phase.memorize ? 'Memorize numbers' : '${_question.text} = ?',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _phase == _Phase.memorize ? Colors.white : green),
                          ),
                        ),
                        if (_phase == _Phase.memorize)
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.white10,
                            child: Text('$_countdown', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _phase == _Phase.memorize ? 'Cards will flip soon' : _phase == _Phase.question ? 'Tap the right card' : '',
                    style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      itemCount: _cards.length,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _cols(_cards.length),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, i) {
                        final c = _cards[i];
                        final showNum = !c.faceDown;
                        final tapped = c.revealed;
                        final frontColor = tapped && c.correct
                            ? green.withValues(alpha: 0.12)
                            : tapped && c.wrong
                                ? const Color(0x33FF6464)
                                : const Color(0xFF0D0D0D);
                        final borderColor = tapped && c.correct
                            ? green.withValues(alpha: 0.5)
                            : tapped && c.wrong
                                ? const Color(0x88FF6464)
                                : Colors.white10;
                        return InkWell(
                          onTap: _phase == _Phase.question ? () => _onCardTap(c) : null,
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            decoration: BoxDecoration(color: frontColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Text(
                                  showNum ? '${c.value}' : '?',
                                  key: ValueKey('${c.id}_${c.faceDown}_${c.revealed}'),
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: tapped && c.correct ? green : tapped && c.wrong ? const Color(0xFFFF9090) : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_feedText != null)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Chip(
                  backgroundColor: _feedGood ? green.withValues(alpha: 0.15) : const Color(0x33FF6464),
                  label: Text(_feedText!, style: TextStyle(color: _feedGood ? green : const Color(0xFFFF8F8F), fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          if (_phase == _Phase.levelUp)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.9),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('LEVEL UP', style: TextStyle(color: Colors.white38, letterSpacing: 4)),
                    const SizedBox(height: 8),
                    Text('$_levelUpFrom → $_levelUpTo', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: green)),
                    const SizedBox(height: 10),
                    Text(_levelName(_levelUpTo), style: const TextStyle(color: green, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
