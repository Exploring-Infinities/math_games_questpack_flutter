import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';
import '../services/plant_service.dart';
import '../storage/game_prefs.dart';

class NumberNinjaScreen extends StatefulWidget {
  const NumberNinjaScreen({super.key});

  @override
  State<NumberNinjaScreen> createState() => _NumberNinjaScreenState();
}

class _NumberNinjaScreenState extends State<NumberNinjaScreen> {
  final _rng = math.Random();
  static const _gameSecs = 60;
  static const _maxOnScreen = 9;
  static const _advanceAt = 7;
  static const _maxWrongSlices = 5;
  static const _slashRadiusPad = 10.0;

  int _secs = _gameSecs;
  int _target = 7;
  int _score = 0;
  int _roundHits = 0;
  int _wrongSlices = 0;
  Timer? _secTimer;
  Timer? _frameTimer;
  final _pool = <(String, bool)>[];
  final _orbs = <_NinjaOrb>[];
  final _slashTrail = <Offset>[];
  Size _arenaSize = Size.zero;
  double _spawnAccumulator = 0;
  int _orbId = 0;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _newTargetRound();
    _secTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secs <= 1) {
        _endGame();
        return;
      }
      setState(() => _secs--);
    });
    _frameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _tick(0.016);
    });
  }

  int _difficulty() => 1 + (GamePrefs.instance.ninjaCorrect ~/ 20).clamp(0, 4);

  void _newTargetRound() {
    final d = _difficulty();
    _target = _pickTarget(d);
    final pool = _buildPool(_target, d)..shuffle(_rng);
    _pool
      ..clear()
      ..addAll(pool);
    _roundHits = 0;
    _orbs.clear();
    _spawnAccumulator = 0;
    setState(() {});
  }

  int _pickTarget(int diff) {
    if (diff == 1) return 3 + _rng.nextInt(6);
    if (diff == 2) return 5 + _rng.nextInt(11);
    return 8 + _rng.nextInt(16);
  }

  List<(String, bool)> _buildPool(int t, int diff) {
    final ok = <String>{'$t'};
    for (var a = 1; a <= t ~/ 2; a++) {
      final b = t - a;
      if (b > 0) ok.add('$a+$b');
    }
    if (diff >= 2) {
      for (var b = 1; b <= 6; b++) {
        ok.add('${t + b}-$b');
      }
    }
    if (diff >= 3) {
      for (var a = 2; a <= 9; a++) {
        if (t % a == 0) {
          final q = t ~/ a;
          if (q >= 2 && q <= 9) ok.add('$a×$q');
        }
      }
    }
    final bad = <String>{};
    for (final d in [-4, -3, -2, -1, 1, 2, 3, 4, 5]) {
      final v = t + d;
      if (v < 1) continue;
      bad.add('$v');
    }
    return [
      ...ok.map((e) => (e, true)),
      ...bad.map((e) => (e, false)),
    ];
  }

  void _tick(double dt) {
    if (!mounted || _ended || _secs <= 0 || _arenaSize == Size.zero) return;

    final h = _arenaSize.height;
    final spawnEvery = _spawnIntervalSeconds();
    _spawnAccumulator += dt;

    if (_orbs.length < _maxOnScreen && _spawnAccumulator >= spawnEvery) {
      _spawnAccumulator = 0;
      _orbs.add(_spawnOrb(_arenaSize.width));
    }

    for (final orb in _orbs) {
      orb.position += orb.velocity * dt;
      orb.rotation += orb.rotationSpeed * dt;
    }

    _orbs.removeWhere((o) => o.position.dy - o.radius > h + 40);
    setState(() {});
  }

  double _spawnIntervalSeconds() {
    final base = 0.95 - (_difficulty() - 1) * 0.1;
    final scorePressure = (_score / 200).clamp(0.0, 0.3);
    return (base - scorePressure).clamp(0.45, 0.95);
  }

  _NinjaOrb _spawnOrb(double w) {
    final correctPool = _pool.where((e) => e.$2).toList();
    final wrongPool = _pool.where((e) => !e.$2).toList();
    final useCorrect = _rng.nextDouble() < 0.42 && correctPool.isNotEmpty;
    final src = useCorrect ? correctPool : (wrongPool.isNotEmpty ? wrongPool : correctPool);
    final picked = src[_rng.nextInt(src.length)];

    final radius = 37.0;
    final x = radius + _rng.nextDouble() * (w - radius * 2).clamp(1, double.infinity);
    const y = -80.0;
    final drift = (_rng.nextDouble() * 100) - 50; // slight horizontal sway while falling
    final levelSpeed = 130 + (_difficulty() - 1) * 35;
    final vy = levelSpeed + _rng.nextDouble() * 70;
    final vx = drift * 0.6;
    final spinDir = _rng.nextBool() ? 1 : -1;
    final spinDegPerSec = 35 + _rng.nextDouble() * 80;

    return _NinjaOrb(
      id: (++_orbId).toString(),
      expr: picked.$1,
      correct: picked.$2,
      position: Offset(x, y),
      velocity: Offset(vx, vy),
      radius: radius,
      rotation: 0,
      rotationSpeed: spinDir * spinDegPerSec * (math.pi / 180),
    );
  }

  Future<void> _endGame() async {
    if (_ended) return;
    _ended = true;
    _secTimer?.cancel();
    _frameTimer?.cancel();
    await GamePrefs.instance.addNinjaCorrect(_score);
    await PlantService.markActivityDone();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Time up'),
        content: Text('Score: $_score'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    if (mounted) context.goNamed(GameRouteNames.home);
  }

  void _slashBySegment(Offset a, Offset b) {
    if (_secs <= 0 || _ended) return;

    final hitIds = <String>[];
    for (final orb in _orbs) {
      if (_segmentHitsCircle(a, b, orb.position, orb.radius + _slashRadiusPad)) {
        hitIds.add(orb.id);
      }
    }

    for (final id in hitIds) {
      _slashOrb(id);
    }
  }

  bool _segmentHitsCircle(Offset a, Offset b, Offset c, double radius) {
    final ab = b - a;
    final abLen2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLen2 == 0) {
      final d = a - c;
      return d.dx * d.dx + d.dy * d.dy <= radius * radius;
    }
    final ac = c - a;
    final t = ((ac.dx * ab.dx + ac.dy * ab.dy) / abLen2).clamp(0.0, 1.0);
    final p = a + ab * t;
    final d = p - c;
    return d.dx * d.dx + d.dy * d.dy <= radius * radius;
  }

  void _slashOrb(String id) {
    final idx = _orbs.indexWhere((o) => o.id == id);
    if (idx == -1) return;
    final orb = _orbs.removeAt(idx);

    if (orb.correct) {
      _score++;
      _roundHits++;
      if (_roundHits >= _advanceAt) {
        _newTargetRound();
      }
    } else {
      _wrongSlices++;
      _secs = (_secs - 3).clamp(0, _gameSecs);
      if (_wrongSlices >= _maxWrongSlices) {
        setState(() {});
        unawaited(_endGame());
        return;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _secTimer?.cancel();
    _frameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF88FFC0);
    return Scaffold(
      appBar: AppBar(title: const Text('Number Ninja')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_secs s',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                Text('Score $_score',
                    style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Wrong slices: $_wrongSlices/$_maxWrongSlices',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('MATCH',
                style: TextStyle(
                    letterSpacing: 3,
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 11)),
            Text('$_target',
                style: const TextStyle(
                    fontSize: 56, fontWeight: FontWeight.w800, color: accent)),
            const SizedBox(height: 32),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _arenaSize = constraints.biggest;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) {
                        _slashTrail
                          ..clear()
                          ..add(details.localPosition);
                        setState(() {});
                      },
                      onPanUpdate: (details) {
                        _slashTrail.add(details.localPosition);
                        if (_slashTrail.length > 20) _slashTrail.removeAt(0);
                        if (_slashTrail.length >= 2) {
                          final a = _slashTrail[_slashTrail.length - 2];
                          final b = _slashTrail[_slashTrail.length - 1];
                          _slashBySegment(a, b);
                        }
                        setState(() {});
                      },
                      onPanEnd: (_) {
                        _slashTrail.clear();
                        setState(() {});
                      },
                      onPanCancel: () {
                        _slashTrail.clear();
                        setState(() {});
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D0D0D),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                          for (final orb in _orbs)
                            Positioned(
                              left: orb.position.dx - orb.radius,
                              top: orb.position.dy - orb.radius,
                              width: orb.radius * 2,
                              height: orb.radius * 2,
                              child: Transform.rotate(
                                angle: orb.rotation,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.05),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    orb.expr,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: orb.expr.length > 4 ? 12 : 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(painter: _SlashTrailPainter(_slashTrail)),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: Text(
                              'Swipe to slice',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NinjaOrb {
  _NinjaOrb({
    required this.id,
    required this.expr,
    required this.correct,
    required this.position,
    required this.velocity,
    required this.radius,
    required this.rotation,
    required this.rotationSpeed,
  });

  final String id;
  final String expr;
  final bool correct;
  Offset position;
  Offset velocity;
  final double radius;
  double rotation;
  final double rotationSpeed;
}

class _SlashTrailPainter extends CustomPainter {
  const _SlashTrailPainter(this.trail);

  final List<Offset> trail;

  @override
  void paint(Canvas canvas, Size size) {
    if (trail.length < 2) return;
    for (var i = 1; i < trail.length; i++) {
      final alpha = i / trail.length;
      final paint = Paint()
        ..color = const Color(0xFF88FFC0).withValues(alpha: alpha * 0.9)
        ..strokeWidth = 2 + alpha * 8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(trail[i - 1], trail[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SlashTrailPainter oldDelegate) {
    return oldDelegate.trail != trail;
  }
}
