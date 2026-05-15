import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../router/app_router.dart';
import '../../games/equation/equation_math.dart';
import '../../models/lb_entry.dart';
import '../../services/leaderboard_service.dart';
import '../../services/plant_service.dart';
import '../../storage/game_prefs.dart';

const _totalQuestions = 5;
const _idleTilt = 15.0;

enum _EbScreen { loading, game, levelup, streak, end }

class EquationBalanceScreen extends StatefulWidget {
  const EquationBalanceScreen({super.key});

  @override
  State<EquationBalanceScreen> createState() => _EquationBalanceScreenState();
}

class _EquationBalanceScreenState extends State<EquationBalanceScreen>
    with TickerProviderStateMixin {
  final _rng = math.Random();
  late int _currentLevel;
  _EbScreen _screen = _EbScreen.loading;
  int _loadCount = 6;
  Timer? _loadTimer;

  int _qIndex = 0;
  late Equation _equation;
  String _userAnswer = '';
  String _gameState = 'playing'; // playing | correct | wrong
  int _wrongCount = 0;
  int _score = 0;
  final _results = <String>[]; // correct | wrong | skipped
  String _feedback = '';
  bool _isAnimating = false;
  double _tilt = _idleTilt;
  int _gameKey = 0;

  AnimationController? _tiltCtrl;
  Animation<double>? _tiltAnim;
  VoidCallback? _tiltListener;

  DateTime _qStart = DateTime.now();
  final _qTimes = <double>[];

  _EndStats? _endStats;
  int? _streakDays;

  bool _showInfo = false;
  bool _showLevelInfo = false;

  @override
  void initState() {
    super.initState();
    final total = GamePrefs.instance.totalCorrect;
    _currentLevel = calcLevelFromTotal(total);
    _equation = generateEquation(_rng, _currentLevel);
    _qStart = DateTime.now();
    _startLoadingCountdown();
  }

  void _startLoadingCountdown() {
    _loadCount = 6;
    _loadTimer?.cancel();
    _loadTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _loadCount--;
        if (_loadCount <= 0) {
          t.cancel();
          _screen = _EbScreen.game;
        }
      });
      if (_loadCount <= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _runIntroWobble();
        });
      }
    });
  }

  Future<void> _runIntroWobble() async {
    await _animateTilt(21, 440);
    await _animateTilt(11, 380);
    await _animateTilt(17, 320);
    await _animateTilt(_idleTilt, 380);
  }

  Future<void> _animateTilt(double target, int ms) async {
    _tiltCtrl?.dispose();
    _tiltCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    );
    final begin = _tilt;
    _tiltAnim = Tween<double>(begin: begin, end: target).animate(
      CurvedAnimation(parent: _tiltCtrl!, curve: Curves.easeInOut),
    );
    _tiltListener = () {
      setState(() => _tilt = _tiltAnim!.value);
    };
    _tiltAnim!.addListener(_tiltListener!);
    await _tiltCtrl!.forward();
    _tiltAnim?.removeListener(_tiltListener!);
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _tiltCtrl?.dispose();
    super.dispose();
  }

  Future<void> _goToEnd(
      int finalScore, List<String> finalResults, List<double> finalTimes) async {
    final prefs = GamePrefs.instance;
    final oldTotal = prefs.totalCorrect;
    final newTotal = oldTotal + finalScore;
    await prefs.setTotalCorrect(newTotal);

    var streak = prefs.equationStreak;
    for (final r in finalResults) {
      if (r == 'correct') {
        streak += 1;
      } else {
        streak = 0;
      }
    }
    await prefs.setEquationStreak(streak);

    await prefs.setTotalSolved(prefs.totalSolved + finalResults.length);

    final sessionSecs =
        finalTimes.fold<double>(0, (a, b) => a + b).round();
    await prefs.addTimePlayed(sessionSecs);

    await PlantService.markActivityDone();

    final today = todayIsoDate();
    final lastDate = prefs.lastActivityDate;
    var showStreak = false;
    var newDaily = prefs.dailyStreak;
    if (lastDate != today) {
      final y = yesterdayIsoDate();
      newDaily = lastDate == y ? newDaily + 1 : 1;
      await prefs.setDailyStreak(newDaily);
      await prefs.setLastActivityDate(today);
      showStreak = true;
    }
    _streakDays = showStreak ? newDaily : null;

    final myId = prefs.playerId;
    LbEntry? existing;
    for (final e in LeaderboardService.equationBalance) {
      if (e.id == myId) {
        existing = e;
        break;
      }
    }
    await LeaderboardService.saveEquationBalance(LbEntry(
      id: myId,
      name: existing?.name ?? 'You',
      level: calcLevelFromTotal(newTotal),
      totalSolved: prefs.totalSolved,
      totalCorrect: newTotal,
    ));

    if (!mounted) return;
    setState(() {
      _endStats = _EndStats(
        score: finalScore,
        results: List.from(finalResults),
        times: List.from(finalTimes),
        oldTotal: oldTotal,
        newTotal: newTotal,
      );
      _isAnimating = false;
      if (calcLevelFromTotal(newTotal) > calcLevelFromTotal(oldTotal)) {
        _screen = _EbScreen.levelup;
      } else if (showStreak) {
        _screen = _EbScreen.streak;
      } else {
        _screen = _EbScreen.end;
      }
    });
  }

  Future<void> _newQuestion(int nextIndex) async {
    setState(() {
      _qIndex = nextIndex;
      _equation = generateEquation(_rng, _currentLevel);
      _userAnswer = '';
      _wrongCount = 0;
      _feedback = '';
      _qStart = DateTime.now();
    });
    await _animateTilt(21, 380);
    await _animateTilt(12, 340);
    await _animateTilt(_idleTilt, 380);
    setState(() => _gameState = 'playing');
  }

  Future<void> _check() async {
    if (_isAnimating || _gameState != 'playing') return;
    final trimmed = _userAnswer.trim();
    if (trimmed.isEmpty) return;
    final num = int.tryParse(trimmed);
    if (num == null) return;

    setState(() => _isAnimating = true);
    final elapsed = DateTime.now().difference(_qStart).inMilliseconds / 1000.0;

    if (num == _equation.answer) {
      await _animateTilt(0, 600);
      final newScore = _score + 1;
      final newResults = [..._results, 'correct'];
      final newTimes = [..._qTimes, elapsed];
      setState(() {
        _score = newScore;
        _results
          ..clear()
          ..addAll(newResults);
        _qTimes
          ..clear()
          ..addAll(newTimes);
        _gameState = 'correct';
        _feedback = 'Balanced!';
      });
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      if (_qIndex + 1 >= _totalQuestions) {
        await _goToEnd(newScore, newResults, newTimes);
        return;
      }
      await _newQuestion(_qIndex + 1);
    } else {
      final newWrong = _wrongCount + 1;
      setState(() {
        _wrongCount = newWrong;
        _gameState = 'wrong';
        _feedback = newWrong >= 2 ? 'Moving on...' : 'Not balanced!';
      });
      await _animateTilt(27, 100);
      await _animateTilt(7, 170);
      await _animateTilt(25, 130);
      await _animateTilt(11, 180);
      await _animateTilt(20, 150);
      await _animateTilt(14, 200);
      await _animateTilt(_idleTilt, 280);
      if (newWrong >= 2) {
        final newResults = [..._results, 'wrong'];
        final newTimes = [..._qTimes, elapsed];
        setState(() {
          _results
            ..clear()
            ..addAll(newResults);
          _qTimes
            ..clear()
            ..addAll(newTimes);
        });
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        if (_qIndex + 1 >= _totalQuestions) {
          await _goToEnd(_score, newResults, newTimes);
          return;
        }
        await _newQuestion(_qIndex + 1);
      }
    }
    if (mounted) setState(() => _isAnimating = false);
  }

  Future<void> _skip() async {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    final elapsed = DateTime.now().difference(_qStart).inMilliseconds / 1000.0;
    final newResults = [..._results, 'skipped'];
    final newTimes = [..._qTimes, elapsed];
    setState(() {
      _results
        ..clear()
        ..addAll(newResults);
      _qTimes
        ..clear()
        ..addAll(newTimes);
    });
    if (_qIndex + 1 >= _totalQuestions) {
      await _goToEnd(_score, newResults, newTimes);
    } else {
      await _newQuestion(_qIndex + 1);
    }
    if (mounted) setState(() => _isAnimating = false);
  }

  void _playAgain() {
    final fresh = calcLevelFromTotal(GamePrefs.instance.totalCorrect);
    setState(() {
      _currentLevel = fresh;
      _screen = _EbScreen.loading;
      _qIndex = 0;
      _equation = generateEquation(_rng, fresh);
      _userAnswer = '';
      _wrongCount = 0;
      _score = 0;
      _results.clear();
      _qTimes.clear();
      _feedback = '';
      _gameState = 'playing';
      _isAnimating = false;
      _endStats = null;
      _streakDays = null;
      _tilt = _idleTilt;
      _gameKey++;
      _qStart = DateTime.now();
    });
    _startLoadingCountdown();
  }

  void _numpad(String key) {
    if (_gameState != 'playing' || _isAnimating) return;
    if (key == '⌫') {
      setState(() {
        if (_userAnswer.isNotEmpty) {
          _userAnswer = _userAnswer.substring(0, _userAnswer.length - 1);
        }
      });
    } else {
      setState(() {
        if (_userAnswer.length < 3) _userAnswer += key;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF88FFC0);
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              if (_screen == _EbScreen.loading) _buildLoading(accent),
              if (_screen == _EbScreen.game) _buildGame(accent),
              if (_screen == _EbScreen.levelup && _endStats != null)
                _LevelUpView(
                  oldLevel: calcLevelFromTotal(_endStats!.oldTotal),
                  newLevel: calcLevelFromTotal(_endStats!.newTotal),
                  onContinue: () {
                    setState(() {
                      _screen = _streakDays != null
                          ? _EbScreen.streak
                          : _EbScreen.end;
                    });
                  },
                ),
              if (_screen == _EbScreen.streak && _streakDays != null)
                _StreakView(
                  days: _streakDays!,
                  onContinue: () =>
                      setState(() => _screen = _EbScreen.end),
                ),
              if (_screen == _EbScreen.end && _endStats != null)
                _EndView(
                  stats: _endStats!,
                  onPlayAgain: _playAgain,
                  onHome: () => unawaited(goToMathGamesHome(context)),
                  accent: accent,
                ),
              if (_showInfo)
                _HowToSheet(
                  onClose: () => setState(() => _showInfo = false),
                ),
              if (_showLevelInfo)
                _LevelInfoSheet(
                  level: _currentLevel,
                  onClose: () => setState(() => _showLevelInfo = false),
                  accent: accent,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(Color accent) {
    final info = getLevelInfo(_currentLevel);
    return Container(
      key: ValueKey(_gameKey),
      color: Colors.black,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'EQUATION BALANCE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 3.2,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'LV ${_currentLevel.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.white.withValues(alpha: 0.12),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                  Text(
                    info.desc,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Starts in',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.2,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          Text(
            '$_loadCount',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGame(Color accent) {
    final isCorrect = _gameState == 'correct';
    final isWrong = _gameState == 'wrong';
    final canCheck = !_isAnimating &&
        _userAnswer.trim().isNotEmpty &&
        _gameState == 'playing';

    return Container(
      key: const ValueKey('game'),
      color: Colors.black,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => unawaited(goToMathGamesHome(context)),
                    icon: Icon(Icons.arrow_back,
                        color: Colors.white.withValues(alpha: 0.4)),
                  ),
                ),
                Text(
                  'EQUATION BALANCE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2.2,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => setState(() => _showInfo = true),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                    ),
                    icon: Text(
                      'i',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showLevelInfo = true),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Text(
                'LV $_currentLevel',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalQuestions, (i) {
                final r = i < _results.length ? _results[i] : null;
                final isCur = i == _qIndex;
                Color? bg;
                if (r == 'correct') bg = accent;
                if (r == 'wrong' || r == 'skipped') {
                  bg = const Color(0xFFFF6B6B);
                }
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bg ?? Colors.transparent,
                    border: Border.all(
                      color: r != null
                          ? Colors.transparent
                          : isCur
                              ? Colors.white.withValues(alpha: 0.75)
                              : Colors.white.withValues(alpha: 0.18),
                      width: 1.5,
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: Center(
              child: _BalanceScale(
                tilt: _tilt,
                equation: _equation.display,
                userAnswer: _userAnswer,
                gameState: _gameState,
                accent: accent,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              children: [
                SizedBox(
                  height: 20,
                  child: Text(
                    _feedback,
                    style: TextStyle(
                      color: isCorrect
                          ? accent
                          : isWrong
                              ? const Color(0xFFFF6B6B)
                              : Colors.white38,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080808),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCorrect
                          ? accent
                          : isWrong
                              ? const Color(0xFFFF6B6B)
                              : Colors.white54,
                      width: 2,
                    ),
                  ),
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Text(
                    _userAnswer.isEmpty ? '—' : _userAnswer,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isCorrect
                          ? accent
                          : isWrong
                              ? const Color(0xFFFF6B6B)
                              : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_gameState == 'playing')
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canCheck ? _check : null,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            canCheck ? Colors.white : Colors.transparent,
                        foregroundColor:
                            canCheck ? Colors.black : Colors.white24,
                        disabledBackgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: canCheck
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.12),
                            width: 2,
                          ),
                        ),
                      ),
                      child: const Text(
                        'CHECK',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                if (isWrong && _wrongCount < 2 && !_isAnimating)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() {
                            _userAnswer = '';
                            _gameState = 'playing';
                            _feedback = '';
                          }),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6B6B),
                            side: BorderSide(
                              color: const Color(0xFFFF6B6B).withValues(alpha: 0.45),
                            ),
                          ),
                          child: const Text('TRY AGAIN'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _skip,
                          child: const Text('NEXT →'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                _Numpad(onKey: _numpad, disabled: _gameState != 'playing' || _isAnimating),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EndStats {
  _EndStats({
    required this.score,
    required this.results,
    required this.times,
    required this.oldTotal,
    required this.newTotal,
  });
  final int score;
  final List<String> results;
  final List<double> times;
  final int oldTotal;
  final int newTotal;
}

class _BalanceScale extends StatelessWidget {
  const _BalanceScale({
    required this.tilt,
    required this.equation,
    required this.userAnswer,
    required this.gameState,
    required this.accent,
  });

  final double tilt;
  final String equation;
  final String userAnswer;
  final String gameState;
  final Color accent;

  static const px = 195.0, py = 128.0, arm = 118.0, hang = 78.0, pw = 136.0;

  @override
  Widget build(BuildContext context) {
    final rad = tilt * 3.1415926535 / 180;
    final lx = px - arm * math.cos(rad);
    final ly = py + arm * math.sin(rad);
    final rx = px + arm * math.cos(rad);
    final ry = py - arm * math.sin(rad);
    final ltY = ly + hang;
    final rtY = ry + hang;
    final hw = pw / 2;
    final ok = gameState == 'correct';
    final bad = gameState == 'wrong';
    final ps = ok ? accent : (bad ? const Color(0xFFFF6B6B) : Colors.white);

    return AspectRatio(
      aspectRatio: 390 / 440,
      child: CustomPaint(
        painter: _ScalePainter(
          lx: lx,
          ly: ly,
          rx: rx,
          ry: ry,
          ltY: ltY,
          rtY: rtY,
          hw: hw,
          panStroke: ps,
          equation: equation,
          userAnswer: userAnswer,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ScalePainter extends CustomPainter {
  _ScalePainter({
    required this.lx,
    required this.ly,
    required this.rx,
    required this.ry,
    required this.ltY,
    required this.rtY,
    required this.hw,
    required this.panStroke,
    required this.equation,
    required this.userAnswer,
  });

  static const px = 195.0, py = 128.0, pw = 136.0, ph = 66.0;

  final double lx, ly, rx, ry, ltY, rtY, hw;
  final Color panStroke;
  final String equation;
  final String userAnswer;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 390;
    canvas.save();
    canvas.scale(scale);

    final pole = Paint()
      ..color = const Color(0xFF484848)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(px, py + 5), Offset(px, 394), pole);

    final base = Paint()..color = const Color(0xFF4E4E4E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(px, 400), width: 72, height: 20),
        const Radius.circular(10),
      ),
      base,
    );

    final beam = Paint()
      ..color = const Color(0xFF383838)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(lx, ly), Offset(rx, ry), beam);

    canvas.drawCircle(Offset(px, py), 5, Paint()..color = const Color(0xFF606060));

    final chain = Paint()
      ..color = const Color(0xFF6E6E6E)
      ..strokeWidth = 1.3;
    const dash = [5.0, 4.0];
    _dashLine(canvas, Offset(lx, ly), Offset(lx - hw, ltY), chain, dash);
    _dashLine(canvas, Offset(lx, ly), Offset(lx + hw, ltY), chain, dash);
    _dashLine(canvas, Offset(rx, ry), Offset(rx - hw, rtY), chain, dash);
    _dashLine(canvas, Offset(rx, ry), Offset(rx + hw, rtY), chain, dash);

    final panBorder = Paint()
      ..color = panStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fill = Paint()..color = const Color(0xFF080808);
    _drawPan(canvas, Rect.fromLTWH(lx - hw, ltY, pw, ph), fill, panBorder);
    _drawPan(canvas, Rect.fromLTWH(rx - hw, rtY, pw, ph), fill, panBorder);

    final tp = TextPainter(
      text: TextSpan(
        text: equation,
        style: TextStyle(
          color: panStroke,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(lx - tp.width / 2, ltY + ph / 2 - tp.height / 2));

    if (userAnswer.isNotEmpty) {
      final tp2 = TextPainter(
        text: TextSpan(
          text: userAnswer,
          style: TextStyle(
            color: panStroke,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp2.paint(canvas, Offset(rx - tp2.width / 2, rtY + ph / 2 - tp2.height / 2));
    }

    canvas.restore();
  }

  void _drawPan(Canvas c, Rect r, Paint fill, Paint border) {
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)), fill);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)), border);
  }

  void _dashLine(Canvas c, Offset a, Offset b, Paint p, List<double> dash) {
    final path = Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy);
    c.drawPath(
      path,
      p
        ..shader = null
        ..strokeWidth = 1.3,
    );
  }

  @override
  bool shouldRepaint(covariant _ScalePainter oldDelegate) =>
      oldDelegate.lx != lx ||
      oldDelegate.userAnswer != userAnswer ||
      oldDelegate.equation != equation ||
      oldDelegate.panStroke != panStroke;
}

class _Numpad extends StatelessWidget {
  const _Numpad({required this.onKey, required this.disabled});
  final void Function(String) onKey;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', ''];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      childAspectRatio: 2.2,
      children: keys.map((k) {
        if (k.isEmpty) return const SizedBox();
        final del = k == '⌫';
        return Material(
          color: del ? Colors.transparent : const Color(0xFF161616),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: disabled ? null : () => onKey(k),
            borderRadius: BorderRadius.circular(10),
            child: Center(
              child: Text(
                k,
                style: TextStyle(
                  fontSize: del ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: disabled
                      ? Colors.white24
                      : del
                          ? Colors.white38
                          : Colors.white,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LevelUpView extends StatelessWidget {
  const _LevelUpView({
    required this.oldLevel,
    required this.newLevel,
    required this.onContinue,
  });

  final int oldLevel;
  final int newLevel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF88FFC0);
    final info = getLevelInfo(newLevel);
    return GestureDetector(
      onTap: onContinue,
      child: Container(
        color: Colors.black,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('EQUATION BALANCE',
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 3,
                    color: Colors.white.withValues(alpha: 0.2))),
            const SizedBox(height: 18),
            const Text('LEVEL',
                style: TextStyle(
                    fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('UP!',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  shadows: [
                    Shadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 40,
                    ),
                  ],
                )),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('LV ${oldLevel.toString().padLeft(2, '0')}',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.15))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('→',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3), fontSize: 20)),
                ),
                Text('LV ${newLevel.toString().padLeft(2, '0')}',
                    style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: accent)),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.22)),
              ),
              child: Column(
                children: [
                  Text(info.name,
                      style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(info.desc,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38), fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Tap to continue',
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.4,
                    color: Colors.white.withValues(alpha: 0.35))),
          ],
        ),
      ),
    );
  }
}

class _StreakView extends StatefulWidget {
  const _StreakView({required this.days, required this.onContinue});
  final int days;
  final VoidCallback onContinue;

  @override
  State<_StreakView> createState() => _StreakViewState();
}

class _StreakViewState extends State<_StreakView> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 4200), () {
      if (mounted) widget.onContinue();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onContinue,
      child: Container(
        color: const Color(0xFF080A0C),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_fire_department, color: Colors.orange, size: 48),
            const SizedBox(height: 24),
            const Text('Water unlocked',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(
              "Your plant is ready for today's water.\nHead home and help it grow.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
            ),
            const SizedBox(height: 20),
            Text(
              widget.days == 1 ? 'Day 1 streak' : '${widget.days} days streak',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndView extends StatelessWidget {
  const _EndView({
    required this.stats,
    required this.onPlayAgain,
    required this.onHome,
    required this.accent,
  });

  final _EndStats stats;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final times = stats.times.isEmpty ? [0.0] : stats.times;
    final total = times.reduce((a, b) => a + b);
    final avg = total / times.length;
    final best = times.reduce((a, b) => a < b ? a : b);
    final pct = (stats.score / _totalQuestions) * 100;
    final msg = pct == 100
        ? 'Perfect Score!'
        : pct >= 80
            ? 'Great Work!'
            : pct >= 60
                ? 'Good Job!'
                : 'Keep Practicing!';
    final newLv = calcLevelFromTotal(stats.newTotal);
    final info = getLevelInfo(newLv);
    final progress = calcProgressInLevel(stats.newTotal);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('EQUATION BALANCE',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2.5,
                  color: Colors.white.withValues(alpha: 0.3))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${stats.score}',
                  style: const TextStyle(
                      fontSize: 88, fontWeight: FontWeight.w800, height: 1)),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('/$_totalQuestions',
                    style: TextStyle(
                        fontSize: 36, color: Colors.white.withValues(alpha: 0.25))),
              ),
            ],
          ),
          Text(msg,
              style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: stats.results
                .map((r) => Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: r == 'correct' ? accent : const Color(0xFFFF6B6B),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statCol('${avg.toStringAsFixed(1)}s', 'avg time'),
              _statCol('${best.toStringAsFixed(1)}s', 'best'),
              _statCol('${total.toStringAsFixed(0)}s', 'total'),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('LV $newLv  ${info.name}',
                        style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
                    Text('$progress/$answersPerLevel',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35))),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress / answersPerLevel,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onPlayAgain,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: const Text('PLAY AGAIN',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onHome,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              foregroundColor: Colors.white38,
            ),
            child: const Text('← HOME'),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String v, String l) => Column(
        children: [
          Text(v,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(l.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: Colors.white.withValues(alpha: 0.3))),
        ],
      );
}

class _HowToSheet extends StatelessWidget {
  const _HowToSheet({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ModalBarrier(
          onDismiss: onClose,
          color: Colors.black.withValues(alpha: 0.72),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: const Color(0xFF0F0F0F),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How to Play',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(
                    'Balance the scale by finding the missing number!',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  const SizedBox(height: 16),
                  const Text('• Look at the equation on the left pan.'),
                  const Text('• Enter the number that balances the scale.'),
                  const Text('• Tap Check to submit.'),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onClose,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF88FFC0),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('GOT IT'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelInfoSheet extends StatelessWidget {
  const _LevelInfoSheet({
    required this.level,
    required this.onClose,
    required this.accent,
  });

  final int level;
  final VoidCallback onClose;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final total = GamePrefs.instance.totalCorrect;
    final progress = calcProgressInLevel(total);
    final info = getLevelInfo(level);
    final next = getLevelInfo(level + 1);
    final pct = progress / answersPerLevel;

    return Stack(
      children: [
        ModalBarrier(
          onDismiss: onClose,
          color: Colors.black.withValues(alpha: 0.72),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: const Color(0xFF0F0F0F),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accent.withValues(alpha: 0.3)),
                        ),
                        child: Text('LV $level',
                            style: TextStyle(
                                color: accent, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(info.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                            Text(info.desc,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('PROGRESS TO LEVEL ${level + 1}',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.8,
                          color: Colors.white.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: pct, color: accent),
                  const SizedBox(height: 8),
                  Text('$progress / $answersPerLevel correct',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.45))),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: CircleAvatar(
                        backgroundColor: accent.withValues(alpha: 0.15),
                        child: Text('${level + 1}',
                            style: TextStyle(color: accent, fontWeight: FontWeight.w800))),
                    title: Text(next.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(next.desc),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onClose,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('KEEP GOING!'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
