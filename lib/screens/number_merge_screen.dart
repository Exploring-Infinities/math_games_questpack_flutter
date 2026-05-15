import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';
import '../services/plant_service.dart';

const _size = 4;
const _slideMs = 180;
const _cleanupMs = 440;

enum _Dir { left, right, up, down }
enum _Screen { game, win, gameOver }
enum _TileKind { add, mul }

class _TileData {
  const _TileData({
    required this.id,
    required this.value,
    required this.kind,
    required this.row,
    required this.col,
  });

  final int id;
  final int value;
  final _TileKind kind;
  final int row;
  final int col;

  _TileData copyWith({
    int? id,
    int? value,
    _TileKind? kind,
    int? row,
    int? col,
  }) {
    return _TileData(
      id: id ?? this.id,
      value: value ?? this.value,
      kind: kind ?? this.kind,
      row: row ?? this.row,
      col: col ?? this.col,
    );
  }
}

class _AbsorbedTile extends _TileData {
  const _AbsorbedTile({
    required super.id,
    required super.value,
    required super.kind,
    required super.row,
    required super.col,
    required this.toRow,
    required this.toCol,
  });

  final int toRow;
  final int toCol;
}

class _LevelCfg {
  const _LevelCfg({
    required this.target,
    required this.tiles,
    required this.optimal,
    required this.chain,
  });

  final int target;
  final List<(int, _TileKind?)> tiles;
  final int optimal;
  final String chain;
}

const _levels = <_LevelCfg>[
  _LevelCfg(target: 10, optimal: 1, tiles: [(7, null), (3, null)], chain: '7 + 3 = 10'),
  _LevelCfg(target: 15, optimal: 2, tiles: [(8, null), (4, null), (3, null)], chain: '8 + 4 + 3 = 15'),
  _LevelCfg(target: 20, optimal: 2, tiles: [(12, null), (5, null), (3, null)], chain: '12 + 5 + 3 = 20'),
  _LevelCfg(target: 25, optimal: 2, tiles: [(14, null), (7, null), (4, null)], chain: '14 + 7 + 4 = 25'),
  _LevelCfg(target: 30, optimal: 2, tiles: [(18, null), (8, null), (4, null)], chain: '18 + 8 + 4 = 30'),
  _LevelCfg(target: 24, optimal: 2, tiles: [(10, null), (3, _TileKind.mul), (-1, null), (-1, null)], chain: '(10 - 1 - 1) × 3 = 24'),
  _LevelCfg(target: 30, optimal: 2, tiles: [(11, null), (5, _TileKind.mul), (-4, null), (-1, null)], chain: '(11 - 4 - 1) × 5 = 30'),
  _LevelCfg(target: 36, optimal: 2, tiles: [(14, null), (3, _TileKind.mul), (-1, null), (-1, null)], chain: '(14 - 1 - 1) × 3 = 36'),
  _LevelCfg(target: 40, optimal: 2, tiles: [(14, null), (4, _TileKind.mul), (-2, null), (-2, null)], chain: '(14 - 2 - 2) × 4 = 40'),
  _LevelCfg(target: 48, optimal: 2, tiles: [(16, null), (4, _TileKind.mul), (-2, null), (-2, null)], chain: '(16 - 2 - 2) × 4 = 48'),
];

class _SlideResult {
  const _SlideResult({
    required this.tiles,
    required this.absorbed,
    required this.mergedIds,
    required this.changed,
  });

  final List<_TileData> tiles;
  final List<_AbsorbedTile> absorbed;
  final Set<int> mergedIds;
  final bool changed;
}

class NumberMergeScreen extends StatefulWidget {
  const NumberMergeScreen({super.key});

  @override
  State<NumberMergeScreen> createState() => _NumberMergeScreenState();
}

class _NumberMergeScreenState extends State<NumberMergeScreen> {
  final _rng = math.Random();

  int _tileId = 0;
  int _level = 0;
  int _moves = 0;
  int _undos = 3;

  _Screen _screen = _Screen.game;
  bool _busy = false;
  bool _shake = false;

  List<_TileData> _tiles = [];
  List<_AbsorbedTile> _absorbed = [];
  Set<int> _mergedIds = {};
  Set<int> _newIds = {};

  List<_TileData>? _prevTiles;
  int _prevMoves = 0;

  int? _winTileId;
  int? _failTileId;
  Offset? _swipeStart;

  _LevelCfg get _cfg => _levels[math.min(_level, _levels.length - 1)];

  @override
  void initState() {
    super.initState();
    _startLevel(0);
  }

  int _nextId() => ++_tileId;

  List<(int, int)> _randomPositions(int n) {
    final pool = <(int, int)>[];
    for (var r = 0; r < _size; r++) {
      for (var c = 0; c < _size; c++) {
        pool.add((r, c));
      }
    }
    for (var i = pool.length - 1; i > 0; i--) {
      final j = _rng.nextInt(i + 1);
      final tmp = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
    }
    return pool.take(n).toList();
  }

  _TileData _tileById(List<_TileData> list, int id) => list.firstWhere((t) => t.id == id);

  bool _isSolvable(List<_TileData> tiles, int target, [int depth = 14]) {
    if (tiles.length == 1) return tiles[0].kind == _TileKind.add && tiles[0].value == target;
    if (depth == 0) return false;
    for (final dir in _Dir.values) {
      final res = _applyMoveWithTiles(tiles, dir);
      if (res.changed && _isSolvable(res.tiles, target, depth - 1)) return true;
    }
    return false;
  }

  _SlideResult _applyMoveWithTiles(List<_TileData> input, _Dir dir) {
    final resultTiles = <_TileData>[];
    final absorbed = <_AbsorbedTile>[];
    final mergedIds = <int>{};

    final isHoriz = dir == _Dir.left || dir == _Dir.right;
    final isReverse = dir == _Dir.right || dir == _Dir.down;

    for (var lineIdx = 0; lineIdx < _size; lineIdx++) {
      final lineTiles = input
          .where((t) => (isHoriz ? t.row : t.col) == lineIdx)
          .toList()
        ..sort((a, b) {
          final pa = isHoriz ? a.col : a.row;
          final pb = isHoriz ? b.col : b.row;
          return isReverse ? pb - pa : pa - pb;
        });

      if (lineTiles.isEmpty) continue;

      final out = <_TileData>[];
      final mergeRecs = <({int absorbedId, int outIdx})>[];

      for (final tile in lineTiles) {
        final last = out.length - 1;
        if (last >= 0) {
          final prev = out[last];
          final mergedValue = (prev.kind == _TileKind.mul || tile.kind == _TileKind.mul)
              ? prev.value * tile.value
              : prev.value + tile.value;
          out[last] = prev.copyWith(value: mergedValue, kind: _TileKind.add);
          mergeRecs.add((absorbedId: tile.id, outIdx: last));
          mergedIds.add(prev.id);
        } else {
          out.add(tile.copyWith());
        }
      }

      for (var idx = 0; idx < out.length; idx++) {
        final pos = isReverse ? (_size - 1 - idx) : idx;
        final row = isHoriz ? lineIdx : pos;
        final col = isHoriz ? pos : lineIdx;
        resultTiles.add(out[idx].copyWith(row: row, col: col));
      }

      for (final rec in mergeRecs) {
        final finalPos = isReverse ? (_size - 1 - rec.outIdx) : rec.outIdx;
        final toRow = isHoriz ? lineIdx : finalPos;
        final toCol = isHoriz ? finalPos : lineIdx;
        final orig = _tileById(input, rec.absorbedId);
        absorbed.add(_AbsorbedTile(
          id: orig.id,
          value: orig.value,
          kind: orig.kind,
          row: orig.row,
          col: orig.col,
          toRow: toRow,
          toCol: toCol,
        ));
      }
    }

    String fp(List<_TileData> list) {
      final s = [...list]..sort((a, b) => (a.row * _size + a.col) - (b.row * _size + b.col));
      return s.map((t) => '${t.row},${t.col},${t.value},${t.kind.name}').join('|');
    }

    return _SlideResult(
      tiles: resultTiles,
      absorbed: absorbed,
      mergedIds: mergedIds,
      changed: fp(input) != fp(resultTiles),
    );
  }

  bool _hasMovesLeft(List<_TileData> tiles) {
    for (final dir in _Dir.values) {
      if (_applyMoveWithTiles(tiles, dir).changed) return true;
    }
    return false;
  }

  void _startLevel(int lvl) {
    final cfg = _levels[math.min(lvl, _levels.length - 1)];
    List<_TileData> initTiles = [];
    var attempts = 0;
    do {
      final positions = _randomPositions(cfg.tiles.length);
      initTiles = List.generate(cfg.tiles.length, (i) {
        final (val, kindMaybe) = cfg.tiles[i];
        return _TileData(
          id: _nextId(),
          value: val,
          kind: kindMaybe ?? _TileKind.add,
          row: positions[i].$1,
          col: positions[i].$2,
        );
      });
      attempts++;
    } while (!_isSolvable(initTiles, cfg.target) && attempts < 100);

    setState(() {
      _tiles = initTiles;
      _newIds = initTiles.map((t) => t.id).toSet();
      _absorbed = [];
      _mergedIds = {};
      _prevTiles = null;
      _prevMoves = 0;
      _undos = 3;
      _level = lvl;
      _moves = 0;
      _busy = false;
      _screen = _Screen.game;
      _winTileId = null;
      _failTileId = null;
      _shake = false;
    });

    Future.delayed(const Duration(milliseconds: 380), () {
      if (mounted) setState(() => _newIds = {});
    });
  }

  void _handleMove(_Dir dir) {
    if (_busy || _screen != _Screen.game) return;
    final result = _applyMoveWithTiles(_tiles, dir);
    if (!result.changed) {
      setState(() => _shake = true);
      Future.delayed(const Duration(milliseconds: 380), () {
        if (mounted) setState(() => _shake = false);
      });
      return;
    }

    setState(() {
      _busy = true;
      _prevTiles = _tiles.map((t) => t.copyWith()).toList();
      _prevMoves = _moves;
      _moves += 1;
      _tiles = result.tiles;
      _absorbed = result.absorbed;
    });

    Future.delayed(const Duration(milliseconds: _slideMs), () {
      if (!mounted) return;
      setState(() {
        _mergedIds = result.mergedIds;
      });
    });

    Future.delayed(const Duration(milliseconds: _cleanupMs), () {
      if (!mounted) return;
      setState(() {
        _absorbed = [];
        _mergedIds = {};
      });

      final after = result.tiles;
      if (after.length == 1) {
        final sole = after.first;
        if (sole.kind == _TileKind.add && sole.value == _cfg.target) {
          setState(() {
            _busy = true;
            _winTileId = sole.id;
          });
          Future.delayed(const Duration(milliseconds: 420), () async {
            if (!mounted) return;
            await PlantService.markActivityDone();
            setState(() {
              _screen = _Screen.win;
            });
          });
          return;
        } else {
          setState(() {
            _busy = true;
            _failTileId = sole.id;
          });
          Future.delayed(const Duration(milliseconds: 420), () {
            if (mounted) setState(() => _screen = _Screen.gameOver);
          });
          return;
        }
      }

      if (!_hasMovesLeft(after)) {
        setState(() {
          _busy = true;
        });
        Future.delayed(const Duration(milliseconds: 420), () {
          if (mounted) setState(() => _screen = _Screen.gameOver);
        });
        return;
      }

      if (mounted) setState(() => _busy = false);
    });
  }

  void _undo({bool fromFail = false}) {
    if (_prevTiles == null || _undos <= 0) return;
    if (!fromFail && _busy) return;
    setState(() {
      _tiles = _prevTiles!.map((t) => t.copyWith()).toList();
      _moves = _prevMoves;
      _prevTiles = null;
      _undos -= 1;
      _absorbed = [];
      _mergedIds = {};
      _screen = _Screen.game;
      _winTileId = null;
      _failTileId = null;
      _busy = false;
    });
  }

  void _showHint() {
    if (_busy) return;
    // Minimal hint: highlight first tile from intended chain is not parsed,
    // so we highlight first movable tile.
    if (_tiles.isEmpty) return;
    setState(() => _newIds = {_tiles.first.id});
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _newIds = {});
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('💡 ${_cfg.chain}'), duration: const Duration(milliseconds: 1600)),
    );
  }

  void _onPanStart(DragStartDetails d) => _swipeStart = d.localPosition;

  void _onPanEnd(DragEndDetails d) {
    final s = _swipeStart;
    _swipeStart = null;
    if (s == null) return;
    final v = d.velocity.pixelsPerSecond;
    final dx = v.dx;
    final dy = v.dy;
    if (dx.abs() < 200 && dy.abs() < 200) return;
    if (dx.abs() > dy.abs()) {
      _handleMove(dx < 0 ? _Dir.left : _Dir.right);
    } else {
      _handleMove(dy < 0 ? _Dir.up : _Dir.down);
    }
  }

  ({Color bg, Color border, Color text, double fs}) _tileStyle(_TileData t) {
    if (t.kind == _TileKind.mul) {
      return (
        bg: const Color(0x2EFFB900),
        border: const Color(0xA6FFB900),
        text: const Color(0xFFFFBA00),
        fs: t.value >= 10 ? 14 : 20,
      );
    }
    final v = t.value;
    final disp = v > 0 ? '+$v' : '$v';
    final fs = disp.length >= 5 ? 13.0 : disp.length == 4 ? 16.0 : disp.length == 3 ? 19.0 : 23.0;
    if (v < 0) {
      final a = v.abs();
      if (a <= 5) {
        return (bg: const Color(0x21FF5A5A), border: const Color(0x80FF5A5A), text: const Color(0xFFFF6060), fs: fs);
      }
      if (a <= 15) {
        return (bg: const Color(0x21DC46B4), border: const Color(0x80DC46B4), text: const Color(0xFFDC46B4), fs: fs);
      }
      return (bg: const Color(0x21A032FF), border: const Color(0x80A032FF), text: const Color(0xFFA032FF), fs: fs);
    }
    if (v == 0) {
      return (bg: const Color(0x12B4B4B4), border: const Color(0x38B4B4B4), text: Colors.white54, fs: fs);
    }
    if (v <= 3) {
      return (bg: const Color(0x1F88FFC0), border: const Color(0x7388FFC0), text: const Color(0xFF88FFC0), fs: fs);
    }
    if (v <= 6) {
      return (bg: const Color(0x1F60D4FF), border: const Color(0x7360D4FF), text: const Color(0xFF60D4FF), fs: fs);
    }
    if (v <= 12) {
      return (bg: const Color(0x26FF9F40), border: const Color(0x80FF9F40), text: const Color(0xFFFF9F40), fs: fs);
    }
    return (bg: const Color(0x26FF6B8A), border: const Color(0x80FF6B8A), text: const Color(0xFFFF6B8A), fs: fs);
  }

  String _fmtVal(_TileData t) => t.kind == _TileKind.mul ? '×${t.value}' : (t.value > 0 ? '+${t.value}' : '${t.value}');

  Widget _buildBoard() {
    const gap = 10.0;
    const pad = 10.0;
    const cell = 72.0;
    const gridPx = pad * 2 + _size * cell + (_size - 1) * gap;
    double leftOf(int c) => pad + c * (cell + gap);
    double topOf(int r) => pad + r * (cell + gap);

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _shake ? 1 : 0),
        duration: const Duration(milliseconds: 380),
        builder: (context, v, child) {
          final wobble = _shake ? math.sin(v * math.pi * 6) * 7 : 0.0;
          return Transform.translate(offset: Offset(wobble, 0), child: child);
        },
        child: Container(
          width: gridPx,
          height: gridPx,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Stack(
            children: [
              for (var i = 0; i < _size * _size; i++)
                Positioned(
                  left: pad + (i % _size) * (cell + gap),
                  top: pad + (i ~/ _size) * (cell + gap),
                  child: Container(
                    width: cell,
                    height: cell,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: 0.03),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                  ),
                ),
              ..._tiles.map((tile) {
                final ts = _tileStyle(tile);
                final isMerge = _mergedIds.contains(tile.id);
                final isHintGlow = _newIds.contains(tile.id);
                final isWin = tile.id == _winTileId;
                final isFail = tile.id == _failTileId;
                return AnimatedPositioned(
                  key: ValueKey('tile_${tile.id}'),
                  duration: const Duration(milliseconds: _slideMs),
                  curve: Curves.easeOutCubic,
                  left: leftOf(tile.col),
                  top: topOf(tile.row),
                  child: AnimatedScale(
                    duration: Duration(milliseconds: isMerge || isWin || isFail ? 300 : 180),
                    scale: isWin ? 1.18 : isFail ? 1.08 : isMerge ? 1.2 : 1,
                    child: Container(
                      width: cell,
                      height: cell,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isWin
                            ? const Color(0x3840C86E)
                            : isFail
                                ? const Color(0x30FF5050)
                                : ts.bg,
                        border: Border.all(
                          color: isWin
                              ? const Color(0xFF80FFB8)
                              : isFail
                                  ? const Color(0xFFFF8080)
                                  : ts.border,
                          width: isWin || isFail ? 2.5 : 2,
                        ),
                        boxShadow: [
                          if (isMerge || isHintGlow) BoxShadow(color: ts.text.withValues(alpha: 0.55), blurRadius: 18),
                          if (isWin) const BoxShadow(color: Color(0xAA50FFA0), blurRadius: 28),
                          if (isFail) const BoxShadow(color: Color(0xAAFF5050), blurRadius: 24),
                        ],
                      ),
                      child: Text(
                        _fmtVal(tile),
                        style: TextStyle(
                          color: isWin
                              ? const Color(0xFF80FFB8)
                              : isFail
                                  ? const Color(0xFFFF8080)
                                  : ts.text,
                          fontSize: ts.fs,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              ..._absorbed.map((tile) {
                final ts = _tileStyle(tile);
                return TweenAnimationBuilder<double>(
                  key: ValueKey('abs_${tile.id}_${tile.toRow}_${tile.toCol}'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: _slideMs),
                  builder: (context, t, _) {
                    final x = leftOf(tile.col) + (leftOf(tile.toCol) - leftOf(tile.col)) * t;
                    final y = topOf(tile.row) + (topOf(tile.toRow) - topOf(tile.row)) * t;
                    return Positioned(
                      left: x,
                      top: y,
                      child: Opacity(
                        opacity: (1 - t).clamp(0, 1),
                        child: Transform.scale(
                          scale: 1 - t * 0.65,
                          child: Container(
                            width: cell,
                            height: cell,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: ts.bg,
                              border: Border.all(color: ts.text, width: 2),
                              boxShadow: [BoxShadow(color: ts.text.withValues(alpha: 0.55), blurRadius: 12)],
                            ),
                            child: Text(
                              _fmtVal(tile),
                              style: TextStyle(color: ts.text, fontSize: ts.fs, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomControls() {
    final canUndo = _prevTiles != null && _undos > 0;
    if (_screen == _Screen.game) {
      return Row(
        children: [
          _btn('↺ Restart', () => _startLevel(_level)),
          _btn('💡 Hint', _showHint, disabled: _busy),
          _btn('↩ Undo ×$_undos', () => _undo(), disabled: !canUndo || _busy),
        ],
      );
    }
    if (_screen == _Screen.win) {
      return Row(
        children: [
          _btn('Next Level', () => _startLevel(math.min(_level + 1, _levels.length - 1)), accent: true),
          _btn('Replay', () => _startLevel(_level)),
        ],
      );
    }
    return Row(
      children: [
        _btn('Try Again', () => _startLevel(_level), danger: true),
        _btn('↩ Undo ×$_undos', () => _undo(fromFail: true), disabled: !canUndo),
      ],
    );
  }

  Widget _btn(String label, VoidCallback onTap, {bool disabled = false, bool accent = false, bool danger = false}) {
    final fg = disabled
        ? Colors.white.withValues(alpha: 0.25)
        : accent
            ? Colors.black
            : danger
                ? const Color(0xFFFF8080)
                : Colors.white.withValues(alpha: 0.7);
    final bg = disabled
        ? Colors.white.withValues(alpha: 0.03)
        : accent
            ? const Color(0xFF88FFC0)
            : danger
                ? const Color(0x2FFF5050)
                : Colors.white.withValues(alpha: 0.05);
    final bd = disabled
        ? Colors.white.withValues(alpha: 0.06)
        : accent
            ? const Color(0xFF88FFC0)
            : danger
                ? const Color(0x73FF6464)
                : Colors.white.withValues(alpha: 0.12);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          onPressed: disabled ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            side: BorderSide(color: bd),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = _cfg.target;
    final vals = _tiles.where((t) => t.kind == _TileKind.add).map((t) => t.value).toList();
    final closest = vals.isEmpty ? 0 : vals.reduce((a, b) => (b - target).abs() < (a - target).abs() ? b : a);
    final dist = vals.isEmpty ? 999 : (closest - target).abs();
    final isClose = dist <= math.max(2, (target * 0.12).floor());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Math Roblox · Puzzle',
                              style: TextStyle(fontSize: 8, color: Colors.white30, letterSpacing: 2),
                            ),
                            Text(
                              'Target Merge Rush',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      _miniStat('Moves', '$_moves', const Color(0xFF88FFC0)),
                      const SizedBox(width: 10),
                      _miniStat('Level', '${_level + 1}/${_levels.length}', Colors.white70),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () => context.goNamed(GameRouteNames.home),
                        icon: const Icon(Icons.close),
                        color: Colors.white54,
                      ),
                    ],
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.only(top: 8),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _screen == _Screen.win
                            ? const Color(0xFF80FFB8)
                            : _screen == _Screen.gameOver
                                ? const Color(0xFFFF8080)
                                : isClose
                                    ? const Color(0xB3FFCC00)
                                    : Colors.white.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _screen == _Screen.win
                              ? '✓ TARGET HIT!'
                              : _screen == _Screen.gameOver
                                  ? '✗ TARGET MISSED'
                                  : 'Target',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 2,
                            color: _screen == _Screen.win
                                ? const Color(0x9980FFB8)
                                : _screen == _Screen.gameOver
                                    ? const Color(0x99FF8080)
                                    : Colors.white38,
                          ),
                        ),
                        Text(
                          '$target',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: _screen == _Screen.win
                                ? const Color(0xFF80FFB8)
                                : _screen == _Screen.gameOver
                                    ? const Color(0xFFFF8080)
                                    : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: Center(child: FittedBox(fit: BoxFit.contain, child: _buildBoard()))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Merge all tiles into one · final tile must equal $target',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.22), fontSize: 11),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  _btn('←', () => _handleMove(_Dir.left), disabled: _busy || _screen != _Screen.game),
                  _btn('→', () => _handleMove(_Dir.right), disabled: _busy || _screen != _Screen.game),
                  _btn('↑', () => _handleMove(_Dir.up), disabled: _busy || _screen != _Screen.game),
                  _btn('↓', () => _handleMove(_Dir.down), disabled: _busy || _screen != _Screen.game),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _bottomControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 7, color: Colors.white30, letterSpacing: 1.5)),
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
