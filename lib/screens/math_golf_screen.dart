import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';
import '../services/plant_service.dart';

class MathGolfScreen extends StatefulWidget {
  const MathGolfScreen({super.key});

  @override
  State<MathGolfScreen> createState() => _MathGolfScreenState();
}

enum _Phase { playing, animating, success, miss, gameOver }

class _Obstacle {
  const _Obstacle(this.x, this.y, this.w, this.h);
  final double x;
  final double y;
  final double w;
  final double h;
}

class _LevelCfg {
  const _LevelCfg({
    required this.eq1,
    required this.eq2,
    required this.powerAns,
    required this.angleAns,
    required this.ball,
    required this.hole,
    required this.obstacles,
    required this.par,
    required this.strokeMax,
  });

  final String eq1;
  final String eq2;
  final int powerAns;
  final int angleAns;
  final Offset ball; // normalized 0..1
  final Offset hole; // normalized 0..1
  final List<_Obstacle> obstacles;
  final int par;
  final int strokeMax;
}

const _courseW = 340.0;
const _courseH = 220.0;
const _ballR = 7.0;
const _holeR = 9.0;

const _levels = <_LevelCfg>[
  _LevelCfg(
    eq1: 'x + y = 40',
    eq2: 'y - x = 20',
    powerAns: 10,
    angleAns: 30,
    ball: Offset(0.15, 0.5),
    hole: Offset(0.82, 0.5),
    obstacles: [],
    par: 1,
    strokeMax: 4,
  ),
  _LevelCfg(
    eq1: 'x + y = 52',
    eq2: '2x + y = 64',
    powerAns: 12,
    angleAns: 40,
    ball: Offset(0.15, 0.65),
    hole: Offset(0.82, 0.35),
    obstacles: [],
    par: 1,
    strokeMax: 4,
  ),
  _LevelCfg(
    eq1: 'x + y = 60',
    eq2: 'y - x = 30',
    powerAns: 15,
    angleAns: 45,
    ball: Offset(0.12, 0.7),
    hole: Offset(0.82, 0.28),
    obstacles: [_Obstacle(0.4, 0.35, 0.06, 0.28)],
    par: 2,
    strokeMax: 5,
  ),
  _LevelCfg(
    eq1: '2x + y = 108',
    eq2: 'x + y = 84',
    powerAns: 24,
    angleAns: 60,
    ball: Offset(0.12, 0.78),
    hole: Offset(0.82, 0.22),
    obstacles: [_Obstacle(0.35, 0.2, 0.28, 0.06)],
    par: 2,
    strokeMax: 5,
  ),
];

class _MathGolfScreenState extends State<MathGolfScreen> {
  int _level = 0;
  int _strokes = 0;
  final Map<int, int> _bestMap = {};

  int _power = 25;
  int _angle = 45;

  late Offset _ballPos;
  Offset? _animBall;
  List<Offset> _previewPath = [];
  _Phase _phase = _Phase.playing;
  String _diagText = '';
  Timer? _animTimer;

  _LevelCfg get _cfg => _levels[math.min(_level, _levels.length - 1)];

  @override
  void initState() {
    super.initState();
    _resetForLevel(0);
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  void _resetForLevel(int level) {
    _animTimer?.cancel();
    _level = level;
    _power = 25;
    _angle = 45;
    _ballPos = Offset(_cfg.ball.dx * _courseW, _cfg.ball.dy * _courseH);
    _animBall = null;
    _phase = _Phase.playing;
    _diagText = '';
    _rebuildPreview();
    setState(() {});
  }

  void _rebuildPreview() {
    if (_phase != _Phase.playing) {
      _previewPath = [];
      return;
    }
    final path = _simulate(
      _ballPos,
      _power.toDouble(),
      _angle.toDouble(),
      _cfg.obstacles,
      maxSteps: 120,
    );
    _previewPath = [
      for (var i = 0; i < path.length; i += 3) path[i],
    ];
  }

  List<Offset> _simulate(
    Offset start,
    double power,
    double angleDeg,
    List<_Obstacle> obstacles, {
    int maxSteps = 600,
  }) {
    final speed = power * 4;
    final rad = angleDeg * math.pi / 180;
    double vx = math.cos(rad) * speed;
    double vy = -math.sin(rad) * speed;
    double x = start.dx;
    double y = start.dy;
    final pts = <Offset>[Offset(x, y)];
    const friction = 0.985;

    for (var i = 0; i < maxSteps; i++) {
      x += vx * 0.016;
      y += vy * 0.016;
      vx *= friction;
      vy *= friction;

      if (x - _ballR < 0) {
        x = _ballR;
        vx = vx.abs() * 0.8;
      }
      if (x + _ballR > _courseW) {
        x = _courseW - _ballR;
        vx = -vx.abs() * 0.8;
      }
      if (y - _ballR < 0) {
        y = _ballR;
        vy = vy.abs() * 0.8;
      }
      if (y + _ballR > _courseH) {
        y = _courseH - _ballR;
        vy = -vy.abs() * 0.8;
      }

      for (final o in obstacles) {
        final ox = o.x * _courseW;
        final oy = o.y * _courseH;
        final ow = o.w * _courseW;
        final oh = o.h * _courseH;
        final hit = x + _ballR > ox &&
            x - _ballR < ox + ow &&
            y + _ballR > oy &&
            y - _ballR < oy + oh;
        if (!hit) continue;

        final dLeft = (x + _ballR - ox).abs();
        final dRight = (x - _ballR - (ox + ow)).abs();
        final dTop = (y + _ballR - oy).abs();
        final dBot = (y - _ballR - (oy + oh)).abs();
        final minD = [dLeft, dRight, dTop, dBot].reduce(math.min);

        if (minD == dLeft) {
          x = ox - _ballR;
          vx = -vx.abs() * 0.7;
        } else if (minD == dRight) {
          x = ox + ow + _ballR;
          vx = vx.abs() * 0.7;
        } else if (minD == dTop) {
          y = oy - _ballR;
          vy = -vy.abs() * 0.7;
        } else {
          y = oy + oh + _ballR;
          vy = vy.abs() * 0.7;
        }
      }

      pts.add(Offset(x, y));
      if (vx.abs() < 0.3 && vy.abs() < 0.3) break;
    }
    return pts;
  }

  String _diagnoseMiss() {
    final pd = _power - _cfg.powerAns;
    final ad = (_angle - _cfg.angleAns).abs();
    if (ad > 5 && pd.abs() > 2) return 'Both x and y were incorrect';
    if (ad > 5) return 'y (angle) was incorrect';
    if (pd < -2) return 'x (power) was too low';
    if (pd > 2) return 'x (power) was too high';
    return 'Almost - recheck your solution';
  }

  void _shoot() {
    if (_phase != _Phase.playing) return;
    final newStrokes = _strokes + 1;
    setState(() {
      _strokes = newStrokes;
      _phase = _Phase.animating;
    });

    final powerCorrect = _power == _cfg.powerAns;
    final angleCorrect = _angle == _cfg.angleAns;
    final isHole = powerCorrect && angleCorrect;
    final hole = Offset(_cfg.hole.dx * _courseW, _cfg.hole.dy * _courseH);

    late final List<Offset> path;
    if (isHole) {
      const steps = 80;
      final sx = _ballPos.dx;
      final sy = _ballPos.dy;
      path = List.generate(steps, (k) {
        final t = k / (steps - 1);
        final ease = t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
        final arcY = -math.sin(t * math.pi) * 18;
        return Offset(
          sx + (hole.dx - sx) * ease,
          sy + (hole.dy - sy) * ease + arcY,
        );
      });
    } else {
      path = _simulate(
        _ballPos,
        _power.toDouble(),
        _angle.toDouble(),
        _cfg.obstacles,
      );
    }

    var i = 0;
    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (i >= path.length) {
        timer.cancel();
        _animBall = null;
        if (isHole) {
          _ballPos = hole;
          final prevBest = _bestMap[_level] ?? (1 << 30);
          _bestMap[_level] = math.min(prevBest, newStrokes);
          setState(() => _phase = _Phase.success);
        } else {
          _ballPos = path.last;
          if (newStrokes >= _cfg.strokeMax) {
            setState(() => _phase = _Phase.gameOver);
          } else {
            setState(() {
              _diagText = _diagnoseMiss();
              _phase = _Phase.miss;
            });
          }
        }
        return;
      }
      setState(() {
        _animBall = path[i];
      });
      i += 2;
    });
  }

  Future<void> _onDoneAllLevels() async {
    await PlantService.markActivityDone();
    if (!mounted) return;
    context.goNamed(GameRouteNames.home);
  }

  InlineSpan _equationSpan(String eq) {
    final spans = <InlineSpan>[];
    for (final ch in eq.split('')) {
      if (ch == 'x') {
        spans.add(
          const TextSpan(
            text: 'x',
            style: TextStyle(
              color: Color(0xFFFF64A0),
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      } else if (ch == 'y') {
        spans.add(
          const TextSpan(
            text: 'y',
            style: TextStyle(
              color: Color(0xFF64A0FF),
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: ch));
      }
    }
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF88FFC0);
    final ball = _animBall ?? _ballPos;

    return Scaffold(
      appBar: AppBar(title: const Text('Math Golf')),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    _StatChip(label: 'Strokes', value: '$_strokes', color: accent),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Best',
                      value: _bestMap[_level]?.toString() ?? '-',
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    const Spacer(),
                    _StatChip(
                      label: 'Level',
                      value: '${_level + 1}/${_levels.length}',
                      color: const Color(0xFFFFE066),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _Badge(label: 'PAR ${_cfg.par}', color: const Color(0xFFFFE066)),
                    const SizedBox(width: 8),
                    _Badge(
                      label: 'MAX ${_cfg.strokeMax}',
                      color: const Color(0xFFFF7B7B),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AspectRatio(
                  aspectRatio: _courseW / _courseH,
                  child: CustomPaint(
                    painter: _CoursePainter(
                      cfg: _cfg,
                      ball: ball,
                      previewPath: _phase == _Phase.playing ? _previewPath : const [],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0D),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Solve for x and y',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 11,
                            letterSpacing: 1.1,
                          )),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: const Color(0xFFFF64A0).withValues(alpha: 0.12),
                              border: Border.all(
                                color: const Color(0xFFFF64A0).withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Text(
                              '1',
                              style: TextStyle(
                                color: Color(0xFFFF64A0),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                ),
                                children: [_equationSpan(_cfg.eq1)],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: const Color(0xFF64A0FF).withValues(alpha: 0.12),
                              border: Border.all(
                                color: const Color(0xFF64A0FF).withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Text(
                              '2',
                              style: TextStyle(
                                color: Color(0xFF64A0FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                ),
                                children: [_equationSpan(_cfg.eq2)],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'x = power  ·  y = angle',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.24),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _ControlCard(
                        label: 'x = power',
                        valueText: '$_power',
                        color: const Color(0xFFFF64A0),
                        min: 1,
                        max: 50,
                        value: _power.toDouble(),
                        onChanged: (v) {
                          setState(() {
                            _power = v.round();
                            _rebuildPreview();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ControlCard(
                        label: 'y = angle',
                        valueText: '$_angle°',
                        color: const Color(0xFF64A0FF),
                        min: 0,
                        max: 90,
                        value: _angle.toDouble(),
                        onChanged: (v) {
                          setState(() {
                            _angle = v.round();
                            _rebuildPreview();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _phase == _Phase.playing ? _shoot : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.04),
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: Text(
                      _phase == _Phase.animating ? 'Flying...' : 'Shoot',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_phase == _Phase.success) _buildSuccessOverlay(context),
          if (_phase == _Phase.miss) _buildMissOverlay(),
          if (_phase == _Phase.gameOver) _buildGameOverOverlay(context),
        ],
      ),
    );
  }

  Widget _buildSuccessOverlay(BuildContext context) {
    return _OverlayCard(
      icon: '🎉',
      title: 'Nice Shot!',
      subtitle:
          'Power and angle matched perfectly.\nCompleted in $_strokes stroke${_strokes == 1 ? '' : 's'}!',
      actions: [
        if (_level + 1 < _levels.length)
          _OverlayAction(
            label: 'Next Level',
            color: const Color(0xFF88FFC0),
            onTap: () {
              setState(() => _strokes = 0);
              _resetForLevel(_level + 1);
            },
          )
        else
          _OverlayAction(
            label: 'Done',
            color: const Color(0xFF88FFC0),
            onTap: _onDoneAllLevels,
          ),
        _OverlayAction(
          label: 'Replay',
          color: const Color(0xFFFFE066),
          onTap: () {
            setState(() => _strokes = 0);
            _resetForLevel(_level);
          },
        ),
      ],
    );
  }

  Widget _buildMissOverlay() {
    return _OverlayCard(
      icon: '😬',
      title: 'Missed!',
      subtitle: '$_diagText\nStrokes used: $_strokes / ${_cfg.strokeMax}',
      actions: [
        _OverlayAction(
          label: 'Adjust & Retry',
          color: const Color(0xFF88FFC0),
          onTap: () => setState(() => _phase = _Phase.playing),
        ),
      ],
    );
  }

  Widget _buildGameOverOverlay(BuildContext context) {
    return _OverlayCard(
      icon: '💀',
      title: 'Out of Strokes',
      subtitle: 'Try matching both values more carefully.',
      actions: [
        _OverlayAction(
          label: 'Try Again',
          color: const Color(0xFF88FFC0),
          onTap: () {
            setState(() => _strokes = 0);
            _resetForLevel(_level);
          },
        ),
        _OverlayAction(
          label: 'Home',
          color: const Color(0xFFFFE066),
          onTap: () => context.goNamed(GameRouteNames.home),
        ),
      ],
    );
  }
}

class _CoursePainter extends CustomPainter {
  const _CoursePainter({
    required this.cfg,
    required this.ball,
    required this.previewPath,
  });

  final _LevelCfg cfg;
  final Offset ball;
  final List<Offset> previewPath;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _courseW;
    final sy = size.height / _courseH;
    final scale = Offset(sx, sy);

    final bgRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F2A12), Color(0xFF071208)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(bgRect, bgPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    for (var i = 1; i < 8; i++) {
      final y = i * size.height / 8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var i = 1; i < 12; i++) {
      final x = i * size.width / 12;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final obsFill = Paint()..color = const Color(0xFF1A2A1A);
    final obsStroke = Paint()
      ..color = const Color(0xFF88FFC0).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final o in cfg.obstacles) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          o.x * size.width,
          o.y * size.height,
          o.w * size.width,
          o.h * size.height,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(r, obsFill);
      canvas.drawRRect(r, obsStroke);
    }

    if (previewPath.length > 1) {
      final path = Path()..moveTo(previewPath.first.dx * sx, previewPath.first.dy * sy);
      for (final p in previewPath.skip(1)) {
        path.lineTo(p.dx * sx, p.dy * sy);
      }
      final p = Paint()
        ..color = const Color(0xFF88FFC0).withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      _drawDashedPath(canvas, path, p, dash: 4, gap: 5);
    }

    final hx = cfg.hole.dx * size.width;
    final hy = cfg.hole.dy * size.height;
    canvas.drawCircle(
      Offset(hx, hy),
      (_holeR + 4) * ((sx + sy) * 0.5),
      Paint()..color = const Color(0xFF88FFC0).withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      Offset(hx, hy),
      _holeR * ((sx + sy) * 0.5),
      Paint()..color = Colors.black,
    );
    canvas.drawCircle(
      Offset(hx, hy),
      _holeR * ((sx + sy) * 0.5),
      Paint()
        ..color = const Color(0xFF88FFC0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(hx, hy - _holeR * sy),
      Offset(hx, hy - _holeR * sy - 16 * sy),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );
    final flag = Path()
      ..moveTo(hx, hy - _holeR * sy - 16 * sy)
      ..lineTo(hx + 10 * sx, hy - _holeR * sy - 11 * sy)
      ..lineTo(hx, hy - _holeR * sy - 6 * sy)
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFFFF4466));

    final bx = ball.dx * scale.dx;
    final by = ball.dy * scale.dy;
    canvas.drawCircle(
      Offset(bx, by),
      (_ballR + 3) * ((sx + sy) * 0.5),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      Offset(bx, by),
      _ballR * ((sx + sy) * 0.5),
      Paint()..color = Colors.white,
    );
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CoursePainter oldDelegate) {
    return oldDelegate.ball != ball ||
        oldDelegate.cfg != cfg ||
        oldDelegate.previewPath != previewPath;
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.label,
    required this.valueText,
    required this.color,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final Color color;
  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valueText,
            style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            'drag ↔ to set',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final trackW = c.maxWidth;
              return GestureDetector(
                onHorizontalDragStart: (d) {
                  final ratio = (d.localPosition.dx / trackW).clamp(0.0, 1.0);
                  onChanged(min + (max - min) * ratio);
                },
                onHorizontalDragUpdate: (d) {
                  final ratio = (d.localPosition.dx / trackW).clamp(0.0, 1.0);
                  onChanged(min + (max - min) * ratio);
                },
                onTapDown: (d) {
                  final ratio = (d.localPosition.dx / trackW).clamp(0.0, 1.0);
                  onChanged(min + (max - min) * ratio);
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    color: color.withValues(alpha: 0.06),
                    border: Border.all(color: color.withValues(alpha: 0.16), width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 5,
                        top: 5,
                        bottom: 5,
                        width: (trackW - 10) * pct,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: color.withValues(alpha: 0.22),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (trackW - 42) * pct,
                        top: 5,
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1A1A1A),
                            border: Border.all(color: color, width: 2),
                          ),
                          child: Text(
                            valueText,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _OverlayAction {
  const _OverlayAction({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _OverlayCard extends StatelessWidget {
  const _OverlayCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String icon;
  final String title;
  final String subtitle;
  final List<_OverlayAction> actions;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xEE080A0C),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(22),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1113),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actions
                      .map(
                        (a) => OutlinedButton(
                          onPressed: a.onTap,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: a.color),
                            foregroundColor: a.color,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          ),
                          child: Text(
                            a.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
