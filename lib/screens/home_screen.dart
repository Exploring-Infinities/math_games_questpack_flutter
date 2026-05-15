import 'dart:async';

import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../router/route_names.dart';
import '../storage/game_prefs.dart';
import '../services/plant_service.dart';
import '../games/equation/equation_math.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.bottomPadding = 96,
  });

  /// Extra bottom spacing for host apps that render persistent bottom bars.
  final double bottomPadding;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _gameLevelFor(String title) {
    final prefs = GamePrefs.instance;
    switch (title) {
      case 'Number Ninja':
        return (prefs.ninjaCorrect ~/ 20) + 1;
      case 'Flip Quest':
        return prefs.flipQuestLevel;
      case 'Number Crush':
        return prefs.numberCrushLevel + 1;
      default:
        return 1;
    }
  }

  Future<void> _showHowToDialog(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<String> tips,
  }) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0C0C0C),
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title · How to Play',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
              const SizedBox(height: 12),
              ...tips.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Text('• ', style: TextStyle(color: Color(0xFF88FFC0))),
                        Expanded(
                          child: Text(
                            t,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF88FFC0),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGameLaunchPopup(
    BuildContext context, {
    required String title,
    required String routeName,
    required String category,
    required String subtitle,
    required String description,
    required String rightStatLabel,
    required String rightStatValue,
    required List<String> howToTips,
  }) async {
    final level = _gameLevelFor(title);
    final accent = const Color(0xFF88FFC0);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0A0A0A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Text(
                  '← Back',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                category.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.22),
                  letterSpacing: 1.3,
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  color: Colors.white.withValues(alpha: 0.02),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR LEVEL',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 8,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '$level',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                level <= 2 ? 'SEEKER' : level <= 4 ? 'STRIKER' : 'MASTER',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          rightStatLabel.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 8,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          rightStatValue,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    unawaited(pushMathGamesRoute(context, routeName));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'START QUEST  →',
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await _showHowToDialog(
                      context,
                      title: title,
                      subtitle: subtitle,
                      tips: howToTips,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                    foregroundColor: Colors.white.withValues(alpha: 0.65),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'How to Play',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = GamePrefs.instance;
    final plant = PlantService.getPlantData();
    final level = calcLevelFromTotal(prefs.totalCorrect);
    final accent = const Color(0xFF88FFC0);
    final resolvedBottomPadding =
        widget.bottomPadding < 24 ? 24.0 : widget.bottomPadding;

    final games = <({
      String title,
      String routeName,
      String subtitle,
      String category,
      String description,
      String rightStatLabel,
      String Function(int level) rightStatValue,
      List<String> howToTips,
      IconData icon
    })>[
      (
        title: 'Equation Balance',
        routeName: GameRouteNames.equationBalance,
        subtitle: 'Balance the scale',
        category: 'Arithmetic',
        description: 'Balance both sides, answer quickly, and keep your streak alive.',
        rightStatLabel: 'QUEST',
        rightStatValue: (_) => '10',
        howToTips: const [
          'Read both sides before typing.',
          'Use check and retry to keep streaks alive.',
          'Accuracy matters more than speed spikes.',
        ],
        icon: Icons.balance
      ),
      (
        title: 'Number Ninja',
        routeName: GameRouteNames.numberNinja,
        subtitle: 'Speed & slicing',
        category: 'Arcade',
        description: 'Slice only expressions that match the target. Wrong cuts cost time.',
        rightStatLabel: 'TIME',
        rightStatValue: (_) => '60',
        howToTips: const [
          'Match expressions to the shown target.',
          'Avoid wrong slices to protect your timer.',
          'Build clean streaks before chasing speed.',
        ],
        icon: Icons.flash_on
      ),
      (
        title: 'Flip Quest',
        routeName: GameRouteNames.flipQuest,
        subtitle: 'Memory + math',
        category: 'Memory · Math',
        description: 'Memorize cards, solve the equation, then tap the hidden answer.',
        rightStatLabel: 'CARDS',
        rightStatValue: (gameLevel) => '${(4 + (gameLevel ~/ 3)).clamp(4, 8)}',
        howToTips: const [
          'Memorize numbers during reveal time.',
          'Solve first, then tap confidently.',
          'Chain correct picks to boost score.',
        ],
        icon: Icons.flip
      ),
      (
        title: 'Math Tetris',
        routeName: GameRouteNames.mathTetris,
        subtitle: 'Stack & solve',
        category: 'Numbers · Puzzle',
        description: 'Drop blocks to match each row target exactly and clear lines.',
        rightStatLabel: 'ROWS',
        rightStatValue: (_) => '8',
        howToTips: const [
          'Aim for exact row totals, not near misses.',
          'Use side movement before hard drop.',
          'Watch target labels every turn.',
        ],
        icon: Icons.grid_view
      ),
      (
        title: 'Number Merge',
        routeName: GameRouteNames.numberMerge,
        subtitle: 'Reach the target',
        category: 'Merge · Math',
        description: 'Swipe to merge tiles with +, −, and × to hit the target exactly.',
        rightStatLabel: 'GRID',
        rightStatValue: (_) => '4×4',
        howToTips: const [
          'Plan merges before committing a swipe.',
          'Operation signs matter as much as values.',
          'Use retries to discover optimal paths.',
        ],
        icon: Icons.merge_type
      ),
      (
        title: 'Math Golf',
        routeName: GameRouteNames.mathGolf,
        subtitle: 'Angles & power',
        category: 'Physics · Math',
        description: 'Solve x and y, then shoot with the right power and angle.',
        rightStatLabel: 'PAR',
        rightStatValue: (gameLevel) => '${(1 + (gameLevel ~/ 4)).clamp(1, 3)}',
        howToTips: const [
          'x controls power, y controls angle.',
          'Adjust both values after every miss.',
          'Stay under max strokes to clear the hole.',
        ],
        icon: Icons.sports_golf
      ),
      (
        title: 'Number Crush',
        routeName: GameRouteNames.numberCrush,
        subtitle: 'Merge to target',
        category: 'Merge · Puzzle',
        description: 'Chain smart number picks to reach the target without dead ends.',
        rightStatLabel: 'TARGET',
        rightStatValue: (_) => '10',
        howToTips: const [
          'Prioritize chains that keep future options open.',
          'Use operation color cues while planning.',
          'Reset fast when the board is trapped.',
        ],
        icon: Icons.auto_awesome
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Math Games',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Level $level · ${prefs.timePlayedSecs ~/ 60} min played',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _PlantCard(
                plant: plant,
                accent: accent,
                onWatered: () => setState(() {}),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, resolvedBottomPadding),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.88,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final g = games[i];
                    return Material(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => _showGameLaunchPopup(
                          context,
                          title: g.title,
                          routeName: g.routeName,
                          category: g.category,
                          subtitle: g.subtitle,
                          description: g.description,
                          rightStatLabel: g.rightStatLabel,
                          rightStatValue: g.rightStatValue(_gameLevelFor(g.title)),
                          howToTips: g.howToTips,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _GameThumb(
                                  title: g.title,
                                  subtitle: g.subtitle,
                                  icon: g.icon,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      g.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                g.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Play',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(Icons.arrow_forward,
                                      size: 11, color: accent),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: games.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameThumb extends StatelessWidget {
  const _GameThumb({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF88FFC0);

    return SizedBox(
      height: 94,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF161616),
                  const Color(0xFF111111),
                  const Color(0xFF0A0A0A),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _ThumbGridPainter(
                lineColor: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 8,
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 7.5,
                letterSpacing: 1.0,
                color: Colors.white.withValues(alpha: 0.25),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 8,
            child: Icon(
              icon,
              size: 13,
              color: accent.withValues(alpha: 0.6),
            ),
          ),
          Positioned.fill(
            child: _ThumbObjects(title: title),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: Row(
              children: [
                Text(
                  subtitle.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 7,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'PLAY',
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.85),
                    fontSize: 8,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 20,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbGridPainter extends CustomPainter {
  const _ThumbGridPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    const xStep = 22.0;
    const yStep = 18.0;
    for (double x = 0; x < size.width; x += xStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += yStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _ThumbGridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

class _ThumbObjects extends StatelessWidget {
  const _ThumbObjects({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF88FFC0);
    final neutral = Colors.white.withValues(alpha: 0.65);
    final light = Colors.white.withValues(alpha: 0.22);

    Widget chip({
      required String text,
      required double left,
      required double top,
      Color? border,
      Color? txt,
    }) {
      return Positioned(
        left: left,
        top: top,
        child: Container(
          width: 48,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF101010),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border ?? light),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: txt ?? neutral,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    if (title == 'Number Ninja') {
      return Stack(
        children: [
          Positioned(
            left: 24,
            top: 40,
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.08),
                border: Border.all(color: accent.withValues(alpha: 0.45), width: 2),
              ),
              child: Text('7+5',
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.95),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  )),
            ),
          ),
          Positioned(
            left: 97,
            top: 25,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: light),
              ),
              child: Text('11',
                  style: TextStyle(
                    color: neutral,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ),
          Positioned(
            right: 24,
            top: 44,
            child: Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.4), width: 2),
              ),
              child: Text('3×4',
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w800,
                  )),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _SlashHintPainter(color: accent.withValues(alpha: 0.45)),
            ),
          ),
        ],
      );
    }

    if (title == 'Equation Balance') {
      return Stack(children: [
        Positioned(
          left: 26,
          bottom: 18,
          right: 26,
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Positioned(
          left: 18,
          bottom: 40,
          child: Transform.rotate(
            angle: -0.2,
            child: Container(
              width: 80,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 46,
          child: Transform.rotate(
            angle: 0.2,
            child: Container(
              width: 80,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
        chip(text: '7+5', left: 12, top: 54, border: Colors.white),
        chip(text: '?', left: 116, top: 42),
      ]);
    }

    if (title == 'Flip Quest') {
      return Stack(children: [
        Positioned(
          left: 14,
          top: 14,
          child: Text(
            '3 + 4 = ?',
            style: TextStyle(
              color: accent.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        chip(text: '7', left: 10, top: 30, border: accent.withValues(alpha: 0.6), txt: Colors.white),
        chip(text: '12', left: 70, top: 30, border: Colors.white.withValues(alpha: 0.22), txt: Colors.white),
        chip(text: '?', left: 130, top: 30, border: Colors.white.withValues(alpha: 0.13), txt: Colors.white.withValues(alpha: 0.35)),
        chip(text: '?', left: 70, top: 66, border: Colors.white.withValues(alpha: 0.13), txt: Colors.white.withValues(alpha: 0.35)),
      ]);
    }

    if (title == 'Math Tetris') {
      final cells = [
        ('', 0, 0, light, neutral),
        ('3', 1, 0, accent.withValues(alpha: 0.7), accent),
        ('', 2, 0, light, neutral),
        ('', 3, 0, light, neutral),
        ('4', 0, 1, const Color(0xFF42A5F5).withValues(alpha: 0.7), Colors.white),
        ('3', 1, 1, accent.withValues(alpha: 0.7), accent),
        ('6', 2, 1, const Color(0xFF42A5F5).withValues(alpha: 0.7), Colors.white),
        ('', 3, 1, light, neutral),
        ('4', 0, 2, const Color(0xFF42A5F5).withValues(alpha: 0.7), Colors.white),
        ('7', 1, 2, const Color(0xFFFFB74D).withValues(alpha: 0.7), Colors.white),
        ('6', 2, 2, const Color(0xFF42A5F5).withValues(alpha: 0.7), Colors.white),
        ('2', 3, 2, const Color(0xFFFFB74D).withValues(alpha: 0.7), Colors.white),
      ];
      const left = 18.0;
      const top = 14.0;
      const cellW = 34.0;
      const cellH = 24.0;
      return Stack(
        children: [
          for (final c in cells)
            Positioned(
              left: left + (cellW + 4) * c.$2,
              top: top + (cellH + 4) * c.$3,
              child: Container(
                width: cellW,
                height: cellH,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.$4),
                  color: const Color(0xFF111111),
                ),
                child: Text(
                  c.$1,
                  style: TextStyle(
                    color: c.$5,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 164,
            top: 16,
            child: Text(
              '=10\n=13\n=19',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                height: 1.45,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    if (title == 'Number Merge') {
      final tiles = [
        ('2', 0, 0, const Color(0xFF5EEAD4)),
        ('4', 1, 0, const Color(0xFF38BDF8)),
        ('', 2, 0, Colors.white24),
        ('8', 3, 0, const Color(0xFFF59E0B)),
        ('', 0, 1, Colors.white24),
        ('4', 1, 1, const Color(0xFF38BDF8)),
        ('16', 2, 1, const Color(0xFFE879F9)),
        ('', 3, 1, Colors.white24),
        ('2', 0, 2, const Color(0xFF5EEAD4)),
        ('', 1, 2, Colors.white24),
        ('8', 2, 2, const Color(0xFFF59E0B)),
        ('16', 3, 2, const Color(0xFFE879F9)),
      ];
      return Stack(
        children: [
          for (final t in tiles)
            Positioned(
              left: 18 + 30.0 * t.$2,
              top: 16 + 25.0 * t.$3,
              child: Container(
                width: 26,
                height: 21,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: t.$4.withValues(alpha: 0.65)),
                  color: const Color(0xFF111111),
                ),
                child: Text(
                  t.$1,
                  style: TextStyle(
                    color: t.$4 == Colors.white24 ? Colors.transparent : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 108,
            top: 90,
            child: Container(
              width: 30,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.7)),
              ),
              child: const Text('32', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      );
    }

    if (title == 'Math Golf') {
      return Stack(children: [
        Positioned(
          left: 18,
          top: 16,
          child: Container(
            width: 166,
            height: 66,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
        ),
        Positioned(
          left: 24,
          top: 22,
          child: Text(
            '6 × 4 = ?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        chip(text: '16', left: 28, top: 38, border: accent.withValues(alpha: 0.22)),
        chip(text: '30', left: 78, top: 38, border: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
        chip(text: '22', left: 128, top: 38, border: const Color(0xFFE879F9).withValues(alpha: 0.35)),
        chip(text: '24', left: 28, top: 72, border: accent.withValues(alpha: 0.8), txt: accent),
        chip(text: '20', left: 78, top: 72, border: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
        chip(text: '18', left: 128, top: 72, border: const Color(0xFFE879F9).withValues(alpha: 0.35)),
      ]);
    }

    if (title == 'Number Crush') {
      final values = ['4', '6', '3', '5', '2', '8', '4', '3', '7', '5', '2', '6'];
      final ops = ['+', '-', '+', '×', '+', '-', '×', '+', '-', '+', '×', '-'];
      return Stack(
        children: [
          Positioned(
            left: 76,
            top: 10,
            child: Text(
              'TARGET: 10',
              style: TextStyle(
                color: const Color(0xFFFFE082).withValues(alpha: 0.95),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          for (var i = 0; i < 12; i++)
            Positioned(
              left: 12 + (i % 4) * 46.0,
              top: 22 + (i ~/ 4) * 25.0,
              child: Container(
                width: 42,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: i == 1
                        ? const Color(0xFFFF6B6B).withValues(alpha: 0.8)
                        : i == 2
                            ? accent.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.22),
                    width: i == 1 || i == 2 ? 2 : 1,
                  ),
                  color: const Color(0xFF111111),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ops[i],
                      style: TextStyle(
                        color: i == 2 ? accent : Colors.white.withValues(alpha: 0.55),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      values[i],
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return Stack(
      children: [
        chip(text: '4', left: 12, top: 28),
        chip(text: '6', left: 64, top: 28, border: accent.withValues(alpha: 0.7), txt: accent),
        chip(text: '3', left: 116, top: 28),
        chip(text: '8', left: 38, top: 62),
        chip(text: '5', left: 90, top: 62),
      ],
    );
  }
}

class _SlashHintPainter extends CustomPainter {
  const _SlashHintPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.72),
      Offset(size.width * 0.9, size.height * 0.3),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _SlashHintPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({
    required this.plant,
    required this.accent,
    required this.onWatered,
  });

  final PlantData plant;
  final Color accent;
  final VoidCallback onWatered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(Icons.eco, color: accent, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.stageName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    plant.waterAvailable
                        ? 'Water available today'
                        : plant.wateredToday
                            ? 'Watered today'
                            : 'Play a game to unlock water',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: plant.growthPct / 100,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            if (plant.waterAvailable)
              FilledButton(
                onPressed: () async {
                  await PlantService.performWatering();
                  onWatered();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Water'),
              ),
          ],
        ),
      ),
    );
  }
}
