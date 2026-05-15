import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';
import '../services/plant_service.dart';
import '../storage/game_prefs.dart';

class MathTetrisScreen extends StatefulWidget {
  const MathTetrisScreen({super.key});

  @override
  State<MathTetrisScreen> createState() => _MathTetrisScreenState();
}

class _MathTetrisScreenState extends State<MathTetrisScreen> {
  final _rng = math.Random();
  static const _cols = 5;
  static const _rows = 8;
  static const _spawnCol = _cols ~/ 2;
  static const _rowsPerLevel = 6;
  static const _maxLevel = 7;
  static const _speedMs = [900, 740, 600, 490, 400, 330, 270];

  int _score = 0;
  int _secs = 45;
  int _level = 1;
  int _clearedRows = 0;
  late List<List<int?>> _grid;
  late List<int> _targets;
  _FallingBlock? _current;
  int _nextValue = 1;
  Timer? _secTick;
  Timer? _dropTick;
  bool _done = false;
  Offset? _swipeStart;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    _grid = List.generate(_rows, (_) => List<int?>.filled(_cols, null));
    _targets = _makeTargets(_level);
    _nextValue = _randVal(_level);
    _spawnBlock();

    _secTick?.cancel();
    _dropTick?.cancel();

    _secTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _done) return;
      if (_secs <= 1) {
        _finish();
        return;
      }
      setState(() => _secs--);
    });

    _restartDropTimer();
  }

  int _randVal(int level) {
    final max = math.min(9, 2 + level * 2);
    return 1 + _rng.nextInt(max);
  }

  int _randTarget(int level) {
    final base = 9 + level * 2;
    return (base + _rng.nextInt(6) - 2).clamp(8, 28);
  }

  List<int> _makeTargets(int level) {
    return List.generate(_rows, (_) => _randTarget(level));
  }

  void _restartDropTimer() {
    _dropTick?.cancel();
    final ms = _speedMs[(_level - 1).clamp(0, _speedMs.length - 1)];
    _dropTick = Timer.periodic(Duration(milliseconds: ms), (_) => _tickDown());
  }

  int _landRow(int col) {
    for (var r = _rows - 1; r >= 0; r--) {
      if (_grid[r][col] == null) return r;
    }
    return -1;
  }

  int _findSpawnCol() {
    if (_grid[0][_spawnCol] == null) return _spawnCol;
    for (var d = 1; d < _cols; d++) {
      final l = _spawnCol - d;
      final r = _spawnCol + d;
      if (l >= 0 && _grid[0][l] == null) return l;
      if (r < _cols && _grid[0][r] == null) return r;
    }
    return -1;
  }

  void _spawnBlock() {
    final col = _findSpawnCol();
    if (col == -1) {
      _finish();
      return;
    }
    _current = _FallingBlock(value: _nextValue, col: col, row: 0);
    _nextValue = _randVal(_level);
  }

  void _tickDown() {
    if (!mounted || _done) return;
    final b = _current;
    if (b == null) return;
    final nr = b.row + 1;
    if (nr < _rows && _grid[nr][b.col] == null) {
      setState(() {
        _current = b.copyWith(row: nr);
      });
    } else {
      _lockCurrent();
    }
  }

  int _rowSum(int row) {
    var sum = 0;
    for (final v in _grid[row]) {
      if (v != null) sum += v;
    }
    final b = _current;
    if (b != null && b.row == row) sum += b.value;
    return sum;
  }

  void _lockCurrent() {
    final b = _current;
    if (b == null || _done) return;
    if (_grid[b.row][b.col] != null) {
      _finish();
      return;
    }

    setState(() {
      _grid[b.row][b.col] = b.value;
      _current = null;

      final row = b.row;
      final sum = _rowSum(row);
      final target = _targets[row];

      if (sum == target) {
        _score += 20 + (_level - 1) * 5;
        _clearedRows++;
        _grid.removeAt(row);
        _grid.insert(0, List<int?>.filled(_cols, null));
        _targets.removeAt(row);
        _targets.insert(0, _randTarget(_level));

        final nextLevel = (_clearedRows ~/ _rowsPerLevel) + 1;
        if (nextLevel > _level && _level < _maxLevel) {
          _level = nextLevel.clamp(1, _maxLevel);
          _restartDropTimer();
        }
      } else if (sum > target) {
        _score = (_score - 2).clamp(0, 999999);
      }

      _spawnBlock();
    });
  }

  Future<void> _finish() async {
    if (_done) return;
    _done = true;
    _secTick?.cancel();
    _dropTick?.cancel();
    await GamePrefs.instance.saveTetrisBestIfHigher(_score);
    await PlantService.markActivityDone();
    if (!mounted) return;
    context.goNamed(GameRouteNames.home);
  }

  void _moveLeft() {
    final b = _current;
    if (_done || b == null) return;
    final c = b.col - 1;
    if (c >= 0 && _grid[b.row][c] == null) {
      setState(() => _current = b.copyWith(col: c));
    }
  }

  void _moveRight() {
    final b = _current;
    if (_done || b == null) return;
    final c = b.col + 1;
    if (c < _cols && _grid[b.row][c] == null) {
      setState(() => _current = b.copyWith(col: c));
    }
  }

  void _hardDrop() {
    final b = _current;
    if (_done || b == null) return;
    final lr = _landRow(b.col);
    if (lr >= b.row) {
      setState(() => _current = b.copyWith(row: lr));
      _lockCurrent();
    }
  }

  void _onSwipeStart(DragStartDetails details) {
    _swipeStart = details.localPosition;
  }

  void _onSwipeEnd(DragEndDetails details) {
    // no-op, gesture is resolved from update delta
    _swipeStart = null;
  }

  void _onSwipeUpdate(DragUpdateDetails details) {
    if (_swipeStart == null) return;
    final dx = details.localPosition.dx - _swipeStart!.dx;
    final dy = details.localPosition.dy - _swipeStart!.dy;

    // Resolve one action per swipe gesture, similar to web touch controls.
    if (dx.abs() > dy.abs() && dx.abs() > 22) {
      if (dx < 0) {
        _moveLeft();
      } else {
        _moveRight();
      }
      _swipeStart = null;
      return;
    }
    if (dy > 26) {
      _hardDrop();
      _swipeStart = null;
    }
  }

  @override
  void dispose() {
    _secTick?.cancel();
    _dropTick?.cancel();
    super.dispose();
  }

  Color _blockColor(int v) {
    if (v <= 3) return const Color(0xFF88FFC0);
    if (v <= 6) return const Color(0xFF60D4FF);
    return const Color(0xFFFF9F40);
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF88FFC0);
    final displayGrid = List.generate(_rows, (r) => List<int?>.from(_grid[r]));
    final b = _current;
    if (b != null &&
        b.row >= 0 &&
        b.row < _rows &&
        b.col >= 0 &&
        b.col < _cols &&
        displayGrid[b.row][b.col] == null) {
      displayGrid[b.row][b.col] = b.value;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Math Tetris')),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _moveLeft,
          const SingleActivator(LogicalKeyboardKey.arrowRight): _moveRight,
          const SingleActivator(LogicalKeyboardKey.arrowDown): _hardDrop,
        },
        child: Focus(
          autofocus: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_secs s',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'L$_level',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Score $_score',
                      style: const TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Best ${GamePrefs.instance.tetrisBest}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Next: $_nextValue',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Down arrow = instant set',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: _onSwipeStart,
                    onHorizontalDragUpdate: _onSwipeUpdate,
                    onHorizontalDragEnd: _onSwipeEnd,
                    onVerticalDragStart: _onSwipeStart,
                    onVerticalDragUpdate: _onSwipeUpdate,
                    onVerticalDragEnd: _onSwipeEnd,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 4.0;
                        final boardW = constraints.maxWidth - 70;
                        final cell = math.min(
                          (boardW - gap * (_cols - 1)) / _cols,
                          (constraints.maxHeight - gap * (_rows - 1)) / _rows,
                        );
                        final boardWidth = cell * _cols + gap * (_cols - 1);
                        final boardHeight = cell * _rows + gap * (_rows - 1);

                        return Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: boardWidth,
                                height: boardHeight,
                                child: Column(
                                  children: List.generate(_rows, (r) {
                                    final sum = _rowSum(r);
                                    final target = _targets[r];
                                    final isMatch = sum == target;
                                    final isOver = sum > target;
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: r == _rows - 1 ? 0 : gap),
                                      child: Row(
                                        children: List.generate(_cols, (c) {
                                          final v = displayGrid[r][c];
                                          return Padding(
                                            padding:
                                                EdgeInsets.only(right: c == _cols - 1 ? 0 : gap),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 120),
                                              width: cell,
                                              height: cell,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: v == null
                                                    ? const Color(0xFF111111)
                                                    : _blockColor(v).withValues(alpha: 0.14),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isMatch
                                                      ? accent.withValues(alpha: 0.7)
                                                      : isOver
                                                          ? const Color(0xFFFF6B6B)
                                                              .withValues(alpha: 0.6)
                                                          : v == null
                                                              ? Colors.white
                                                                  .withValues(alpha: 0.12)
                                                              : _blockColor(v)
                                                                  .withValues(alpha: 0.8),
                                                  width: isMatch || isOver ? 2 : 1.3,
                                                ),
                                              ),
                                              child: Text(
                                                v?.toString() ?? '',
                                                style: TextStyle(
                                                  color: v == null
                                                      ? Colors.transparent
                                                      : Colors.white.withValues(alpha: 0.95),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: cell * 0.34,
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 56,
                                height: boardHeight,
                                child: Column(
                                  children: List.generate(_rows, (r) {
                                    final sum = _rowSum(r);
                                    final target = _targets[r];
                                    final c = sum == target
                                        ? accent
                                        : sum > target
                                            ? const Color(0xFFFF6B6B)
                                            : Colors.white.withValues(alpha: 0.35);
                                    return Expanded(
                                      child: Center(
                                        child: Text(
                                          '=$target',
                                          style: TextStyle(
                                            color: c,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ControlButton(
                      icon: Icons.arrow_left,
                      label: 'Left',
                      onTap: _moveLeft,
                    ),
                    const SizedBox(width: 12),
                    _ControlButton(
                      icon: Icons.arrow_downward,
                      label: 'Drop',
                      onTap: _hardDrop,
                      accent: true,
                    ),
                    const SizedBox(width: 12),
                    _ControlButton(
                      icon: Icons.arrow_right,
                      label: 'Right',
                      onTap: _moveRight,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FallingBlock {
  _FallingBlock({
    required this.value,
    required this.col,
    required this.row,
  });

  final int value;
  final int col;
  final int row;

  _FallingBlock copyWith({
    int? value,
    int? col,
    int? row,
  }) {
    return _FallingBlock(
      value: value ?? this.value,
      col: col ?? this.col,
      row: row ?? this.row,
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF88FFC0);
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: accent
            ? green.withValues(alpha: 0.15)
            : const Color(0xFF1A1A1A),
        foregroundColor: accent ? green : Colors.white.withValues(alpha: 0.85),
        side: BorderSide(
          color: accent
              ? green.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
