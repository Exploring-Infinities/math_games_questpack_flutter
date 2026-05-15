import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';
import '../services/plant_service.dart';
import '../storage/game_prefs.dart';

enum _Op { add, mul }
enum _Phase { playing, win, lose }

class _Tile {
  _Tile({
    required this.id,
    required this.value,
    required this.op,
    this.isNew = false,
  });

  final int id;
  final int value;
  final _Op op;
  final bool isNew;
}

class _LevelCfg {
  const _LevelCfg({
    required this.target,
    required this.gridSize,
    required this.movesLimit,
    required this.matchesNeeded,
    required this.allowNeg,
    required this.allowMul,
    required this.valueRange,
  });

  final int target;
  final int gridSize;
  final int movesLimit;
  final int matchesNeeded;
  final bool allowNeg;
  final bool allowMul;
  final (int, int) valueRange;
}

class _MergeAnim {
  const _MergeAnim({
    required this.fromId,
    required this.toId,
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    required this.result,
    required this.nonce,
  });

  final int fromId;
  final int toId;
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final int result;
  final int nonce;
}

const _levels = <_LevelCfg>[
  _LevelCfg(target: 8, gridSize: 5, movesLimit: 20, matchesNeeded: 4, allowNeg: false, allowMul: false, valueRange: (1, 7)),
  _LevelCfg(target: 10, gridSize: 5, movesLimit: 18, matchesNeeded: 5, allowNeg: false, allowMul: false, valueRange: (1, 9)),
  _LevelCfg(target: 12, gridSize: 5, movesLimit: 18, matchesNeeded: 5, allowNeg: false, allowMul: false, valueRange: (2, 11)),
  _LevelCfg(target: 15, gridSize: 5, movesLimit: 20, matchesNeeded: 5, allowNeg: true, allowMul: false, valueRange: (3, 14)),
  _LevelCfg(target: 18, gridSize: 5, movesLimit: 20, matchesNeeded: 5, allowNeg: true, allowMul: false, valueRange: (3, 17)),
  _LevelCfg(target: 20, gridSize: 6, movesLimit: 22, matchesNeeded: 6, allowNeg: true, allowMul: false, valueRange: (4, 19)),
  _LevelCfg(target: 24, gridSize: 6, movesLimit: 22, matchesNeeded: 6, allowNeg: true, allowMul: true, valueRange: (2, 12)),
  _LevelCfg(target: 30, gridSize: 6, movesLimit: 20, matchesNeeded: 6, allowNeg: true, allowMul: true, valueRange: (2, 15)),
  _LevelCfg(target: 36, gridSize: 6, movesLimit: 20, matchesNeeded: 7, allowNeg: true, allowMul: true, valueRange: (2, 18)),
  _LevelCfg(target: 42, gridSize: 6, movesLimit: 18, matchesNeeded: 7, allowNeg: true, allowMul: true, valueRange: (2, 21)),
];

class NumberCrushScreen extends StatefulWidget {
  const NumberCrushScreen({super.key});

  @override
  State<NumberCrushScreen> createState() => _NumberCrushScreenState();
}

class _NumberCrushScreenState extends State<NumberCrushScreen> {
  final _rng = math.Random();

  int _uid = 1;
  int _level = 0;
  late _LevelCfg _cfg;
  late List<List<_Tile?>> _grid;

  _Phase _phase = _Phase.playing;
  bool _busy = false;
  int _moves = 0;
  int _matches = 0;
  int _score = 0;
  int _streak = 0;

  String _eq = '';
  bool _eqOk = false;
  Set<int> _shaking = {};
  (int, int, int, int)? _hint;

  _MergeAnim? _mergeAnim;
  int _mergeNonce = 0;
  int? _burstTileId;
  int? _burstResult;
  int _burstNonce = 0;

  @override
  void initState() {
    super.initState();
    _level = GamePrefs.instance.numberCrushLevel.clamp(0, _levels.length - 1);
    _resetLevel(_level);
  }

  bool _adj(int r1, int c1, int r2, int c2) => (r1 - r2).abs() + (c1 - c2).abs() == 1;

  int _mergeTiles(_Tile a, _Tile b) {
    if (b.op == _Op.mul) return a.value * b.value;
    if (a.op == _Op.mul) return b.value * a.value;
    return a.value + b.value;
  }

  _Tile _makeTile(_LevelCfg cfg, int target, {bool isNew = false}) {
    final (mn, mx) = cfg.valueRange;
    _Op op = _Op.add;
    int value;
    var tries = 0;
    do {
      final rand = _rng.nextDouble();
      if (cfg.allowMul && rand < 0.30) {
        op = _Op.mul;
        final maxMul = math.min(mx, 9);
        value = 2 + _rng.nextInt(math.max(1, maxMul - 1));
      } else {
        op = _Op.add;
        final raw = mn + _rng.nextInt(mx - mn + 1);
        value = (cfg.allowNeg && rand < 0.64) ? -raw : raw;
      }
      tries++;
    } while (value == target && tries < 30);
    return _Tile(id: _uid++, value: value, op: op, isNew: isNew);
  }

  (int, int, int, int)? _findHint(List<List<_Tile?>> grid, int target) {
    final n = grid.length;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final a = grid[r][c];
        if (a == null) continue;
        for (final (nr, nc) in [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]) {
          if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;
          final b = grid[nr][nc];
          if (b == null) continue;
          if (_mergeTiles(a, b) == target) return (r, c, nr, nc);
          if (_mergeTiles(b, a) == target) return (nr, nc, r, c);
        }
      }
    }
    return null;
  }

  List<List<_Tile?>> _injectPair(List<List<_Tile?>> grid, int target, _LevelCfg cfg) {
    final n = grid.length;
    final ng = [for (final row in grid) [...row]];
    final r = _rng.nextInt(n);
    final c = _rng.nextInt(n - 1);
    final strategy = _rng.nextDouble();

    if (cfg.allowMul && strategy < 0.40) {
      for (var f = 2; f <= math.min(9, target); f++) {
        if (target % f == 0 && target ~/ f >= 2 && target ~/ f != target) {
          ng[r][c] = _Tile(id: _uid++, value: target ~/ f, op: _Op.add);
          ng[r][c + 1] = _Tile(id: _uid++, value: f, op: _Op.mul);
          return ng;
        }
      }
    }

    if (cfg.allowNeg && strategy < 0.75) {
      final nAbs = 2 + _rng.nextInt(math.min(8, target.abs()));
      final big = target + nAbs;
      if (big != target && nAbs != target) {
        ng[r][c] = _Tile(id: _uid++, value: big, op: _Op.add);
        ng[r][c + 1] = _Tile(id: _uid++, value: -nAbs, op: _Op.add);
        return ng;
      }
    }

    final half = (target / 2).ceil();
    final rest = target - half;
    ng[r][c] = _Tile(id: _uid++, value: half, op: _Op.add);
    ng[r][c + 1] = _Tile(id: _uid++, value: rest, op: _Op.add);
    return ng;
  }

  List<List<_Tile?>> _makeGrid(_LevelCfg cfg) {
    final n = cfg.gridSize;
    var g = List.generate(
      n,
      (_) => List<_Tile?>.generate(n, (_) => _makeTile(cfg, cfg.target)),
    );
    if (_findHint(g, cfg.target) == null) g = _injectPair(g, cfg.target, cfg);
    return g;
  }

  List<List<_Tile?>> _gravity(List<List<_Tile?>> grid, _LevelCfg cfg) {
    final n = grid.length;
    final ng = List.generate(n, (_) => List<_Tile?>.filled(n, null));
    for (var c = 0; c < n; c++) {
      final col = <_Tile>[
        for (var r = 0; r < n; r++)
          if (grid[r][c] != null) _Tile(id: grid[r][c]!.id, value: grid[r][c]!.value, op: grid[r][c]!.op)
      ];
      final fill = List.generate(n - col.length, (_) => _makeTile(cfg, cfg.target, isNew: true));
      final full = [...fill, ...col];
      for (var r = 0; r < n; r++) {
        ng[r][c] = full[r];
      }
    }
    if (_findHint(ng, cfg.target) == null) return _injectPair(ng, cfg.target, cfg);
    return ng;
  }

  void _resetLevel(int lvl) {
    _cfg = _levels[lvl.clamp(0, _levels.length - 1)];
    _grid = _makeGrid(_cfg);
    _phase = _Phase.playing;
    _busy = false;
    _eq = '';
    _eqOk = false;
    _shaking = {};
    _hint = null;
    _mergeAnim = null;
    _burstTileId = null;
    _burstResult = null;
    _moves = _cfg.movesLimit;
    _matches = 0;
    _score = 0;
    _streak = 0;
    setState(() {});
  }

  Future<void> _advanceLevel() async {
    final next = (_level + 1).clamp(0, _levels.length - 1);
    await GamePrefs.instance.setNumberCrushLevel(next);
    await PlantService.markActivityDone();
    if (!mounted) return;
    if (_level + 1 < _levels.length) {
      setState(() => _level = next);
      _resetLevel(_level);
    } else {
      context.goNamed(GameRouteNames.home);
    }
  }

  Future<void> _collectTargetTile(int r, int c) async {
    if (_phase != _Phase.playing || _busy) return;
    final tile = _grid[r][c];
    if (tile == null || tile.value != _cfg.target) return;

    setState(() {
      _busy = true;
      _eq = '${tile.value} = ${_cfg.target}';
      _eqOk = true;
      _moves -= 1;
      _streak += 1;
      _score += 100 + (_streak == 2 ? 25 : _streak == 3 ? 50 : _streak >= 4 ? 100 : 0);
      _burstTileId = tile.id;
      _burstResult = _cfg.target;
      _burstNonce++;
      _matches += 1;
    });

    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() {
      _grid[r][c] = null;
      _burstTileId = null;
      _burstResult = null;
    });

    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    if (_matches >= _cfg.matchesNeeded) {
      setState(() {
        _phase = _Phase.win;
        _busy = false;
        _eq = '';
      });
      return;
    }
    setState(() {
      _grid = _gravity(_grid, _cfg);
      _busy = false;
      _eq = '';
    });
  }

  Future<void> _tryMerge(int sr, int sc, int r, int c) async {
    if (_phase != _Phase.playing || _busy) return;
    final a = _grid[sr][sc];
    final b = _grid[r][c];
    if (a == null || b == null) return;

    final res = _mergeTiles(a, b);
    final ok = res == _cfg.target;
    final eqLabel = (a.op == _Op.mul || b.op == _Op.mul)
        ? '${a.value} × ${b.value} = $res'
        : '${a.value} + ${b.value} = $res';

    setState(() {
      _busy = true;
      _eq = eqLabel;
      _eqOk = ok;
      _moves -= 1;
      _hint = null;
    });

    if (ok) {
      setState(() {
        _streak += 1;
        _score += 100 + (_streak == 2 ? 25 : _streak == 3 ? 50 : _streak >= 4 ? 100 : 0);
        _mergeNonce++;
        _mergeAnim = _MergeAnim(
          fromId: a.id,
          toId: b.id,
          fromRow: sr,
          fromCol: sc,
          toRow: r,
          toCol: c,
          result: res,
          nonce: _mergeNonce,
        );
        _burstTileId = b.id;
        _burstResult = res;
        _burstNonce++;
        _matches += 1;
      });

      await Future.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;
      setState(() {
        _grid[sr][sc] = null;
        _grid[r][c] = null;
        _mergeAnim = null;
        _burstTileId = null;
        _burstResult = null;
      });

      await Future.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;
      if (_matches >= _cfg.matchesNeeded) {
        setState(() {
          _phase = _Phase.win;
          _busy = false;
          _eq = '';
        });
        return;
      }
      setState(() {
        _grid = _gravity(_grid, _cfg);
        _busy = false;
        _eq = '';
      });
      return;
    }

    setState(() {
      _streak = 0;
      _shaking = {a.id, b.id};
    });
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _shaking = {};
      _busy = false;
      if (_moves <= 0) _phase = _Phase.lose;
      _eq = '';
    });
  }

  void _showHint() {
    final h = _findHint(_grid, _cfg.target);
    setState(() => _hint = h);
    if (h != null) {
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _hint = null);
      });
    }
  }

  void _shuffle() {
    if (_busy || _phase != _Phase.playing) return;
    setState(() {
      _grid = _makeGrid(_cfg);
      _hint = null;
      _mergeAnim = null;
      _burstTileId = null;
      _burstResult = null;
    });
  }

  ({Color bg, Color bd, Color text}) _tileStyle(_Tile t) {
    if (t.op == _Op.mul) {
      return (bg: const Color(0x1CA855F7), bd: const Color(0x61A855F7), text: const Color(0xFFA855F7));
    }
    if (t.value < 0) {
      return (bg: const Color(0x1CFF6444), bd: const Color(0x61FF6444), text: const Color(0xFFFF6444));
    }
    return (bg: const Color(0x1C00D4AA), bd: const Color(0x6100D4AA), text: const Color(0xFF00D4AA));
  }

  Future<void> _handleTileTap(int r, int c) async {
    if (_busy || _phase != _Phase.playing) return;
    await _collectTargetTile(r, c);
  }

  Future<void> _handleTileDrag(int sr, int sc, DragUpdateDetails d) async {
    if (_busy || _phase != _Phase.playing) return;
    final dx = d.delta.dx;
    final dy = d.delta.dy;
    if (dx.abs() < 10 && dy.abs() < 10) return;
    int tr = sr;
    int tc = sc;
    if (dx.abs() > dy.abs()) {
      tc = dx > 0 ? sc + 1 : sc - 1;
    } else {
      tr = dy > 0 ? sr + 1 : sr - 1;
    }
    final n = _cfg.gridSize;
    if (tr < 0 || tr >= n || tc < 0 || tc >= n) return;
    if (!_adj(sr, sc, tr, tc)) return;
    await _tryMerge(sr, sc, tr, tc);
  }

  @override
  Widget build(BuildContext context) {
    final hintSet = _hint == null
        ? <String>{}
        : <String>{'${_hint!.$1},${_hint!.$2}', '${_hint!.$3},${_hint!.$4}'};

    return Scaffold(
      appBar: AppBar(title: const Text('Number Crush')),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    _stat('Level', '${_level + 1}/${_levels.length}'),
                    _stat('Moves', '$_moves', color: _moves <= 4 ? const Color(0xFFFF6444) : null),
                    _stat('Match', '$_matches/${_cfg.matchesNeeded}', color: const Color(0xFF00D4AA)),
                    _stat('Score', '$_score'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x59FFE066), width: 1.5),
                        boxShadow: const [BoxShadow(color: Color(0x1AFFE066), blurRadius: 18)],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'TARGET',
                            style: TextStyle(
                              color: const Color(0xFFFFE066).withValues(alpha: 0.55),
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '${_cfg.target}',
                            style: const TextStyle(
                              color: Color(0xFFFFE066),
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_eq.isNotEmpty)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: _eqOk ? const Color(0xEA00D4AA) : const Color(0xEAFF503C),
                          ),
                          child: Center(
                            child: Text(
                              '$_eq  ${_eqOk ? '✓' : '✗'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Builder(
                    builder: (context) {
                      final tileSize = _cfg.gridSize == 5 ? 68.0 : 58.0;
                      const gap = 8.0;
                      const pad = 10.0;
                      final boardW = pad * 2 + _cfg.gridSize * tileSize + (_cfg.gridSize - 1) * gap;
                      final boardH = boardW;
                      Offset tileOffset(int r, int c) =>
                          Offset(pad + c * (tileSize + gap), pad + r * (tileSize + gap));

                      return Container(
                        width: boardW,
                        height: boardH,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1.5),
                        ),
                        child: Stack(
                          children: [
                            for (var r = 0; r < _cfg.gridSize; r++)
                              for (var c = 0; c < _cfg.gridSize; c++)
                                Positioned(
                                  left: tileOffset(r, c).dx,
                                  top: tileOffset(r, c).dy,
                                  child: () {
                                    final tile = _grid[r][c];
                                    if (tile == null) return SizedBox(width: tileSize, height: tileSize);
                                    final st = _tileStyle(tile);
                                    final key = '$r,$c';
                                    final isHint = hintSet.contains(key);
                                    final shaking = _shaking.contains(tile.id);
                                    final isFrom = _mergeAnim?.fromId == tile.id;
                                    final isTo = _mergeAnim?.toId == tile.id;
                                    final showBurst = _burstTileId == tile.id && _burstResult != null;

                                    return GestureDetector(
                                      onTap: () => _handleTileTap(r, c),
                                      onPanUpdate: (d) => _handleTileDrag(r, c, d),
                                      child: AnimatedOpacity(
                                        opacity: isFrom ? 0 : 1,
                                        duration: const Duration(milliseconds: 120),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          curve: Curves.easeOut,
                                          width: tileSize,
                                          height: tileSize,
                                          transform: shaking
                                              ? (Matrix4.identity()..translate((_rng.nextDouble() - 0.5) * 8, 0.0))
                                              : Matrix4.identity(),
                                          decoration: BoxDecoration(
                                            color: isTo && _mergeAnim != null
                                                ? const Color(0x36FFE066)
                                                : st.bg,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isTo && _mergeAnim != null
                                                  ? const Color(0xFFFFE066)
                                                  : isHint
                                                      ? const Color(0xFFFFE066)
                                                      : st.bd,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              if (isHint) const BoxShadow(color: Color(0x99FFE066), blurRadius: 14),
                                              if (isTo && _mergeAnim != null)
                                                const BoxShadow(color: Color(0x99FFE066), blurRadius: 20),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: showBurst
                                              ? TweenAnimationBuilder<double>(
                                                  key: ValueKey('burst_${tile.id}_$_burstNonce'),
                                                  tween: Tween(begin: 0, end: 1),
                                                  duration: const Duration(milliseconds: 320),
                                                  builder: (context, t, _) {
                                                    final scale = t < 0.4
                                                        ? 1 + t * 1.4
                                                        : 1.56 - (t - 0.4) * 1.2;
                                                    final op = t < 0.9
                                                        ? 1.0
                                                        : (1 - (t - 0.9) / 0.1).clamp(0.0, 1.0);
                                                    return Opacity(
                                                      opacity: op,
                                                      child: Transform.scale(
                                                        scale: scale,
                                                        child: Text(
                                                          '$_burstResult',
                                                          style: TextStyle(
                                                            color: const Color(0xFFFFE066),
                                                            fontWeight: FontWeight.w900,
                                                            fontSize: _cfg.gridSize == 5 ? 26 : 21,
                                                            shadows: const [
                                                              Shadow(color: Color(0xAAFFE066), blurRadius: 12),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Text(
                                                  tile.op == _Op.mul ? '×${tile.value}' : '${tile.value}',
                                                  style: TextStyle(
                                                    color: tile.op == _Op.mul
                                                        ? st.text
                                                        : tile.value < 0
                                                            ? st.text
                                                            : Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: _cfg.gridSize == 5 ? 22 : 18,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    );
                                  }(),
                                ),
                            if (_mergeAnim != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: TweenAnimationBuilder<double>(
                                    key: ValueKey('merge_fly_${_mergeAnim!.nonce}'),
                                    tween: Tween(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 280),
                                    builder: (context, t, _) {
                                      final from = tileOffset(_mergeAnim!.fromRow, _mergeAnim!.fromCol);
                                      final to = tileOffset(_mergeAnim!.toRow, _mergeAnim!.toCol);
                                      final x = from.dx + (to.dx - from.dx) * t;
                                      final y = from.dy + (to.dy - from.dy) * t;
                                      final scale = 1 - (t * 0.82);
                                      final op = (1 - t).clamp(0.0, 1.0);
                                      final source = _grid[_mergeAnim!.fromRow][_mergeAnim!.fromCol];
                                      final style = source != null
                                          ? _tileStyle(source)
                                          : (bg: const Color(0x1C00D4AA), bd: const Color(0x6100D4AA), text: const Color(0xFF00D4AA));
                                      return Positioned(
                                        left: x,
                                        top: y,
                                        child: Opacity(
                                          opacity: op,
                                          child: Transform.scale(
                                            scale: scale,
                                            child: Container(
                                              width: tileSize,
                                              height: tileSize,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: style.bg,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFFFE066), width: 2),
                                                boxShadow: const [BoxShadow(color: Color(0x99FFE066), blurRadius: 16)],
                                              ),
                                              child: Text(
                                                '${source?.op == _Op.mul ? '×' : ''}${source?.value ?? ''}',
                                                style: TextStyle(
                                                  color: source?.op == _Op.mul
                                                      ? style.text
                                                      : (source?.value ?? 1) < 0
                                                          ? style.text
                                                          : Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: _cfg.gridSize == 5 ? 22 : 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
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
              SizedBox(
                height: 28,
                child: _streak >= 2
                    ? Text(
                        '🔥 ${_streak}× Streak! +${_streak == 2 ? 25 : _streak == 3 ? 50 : 100} bonus',
                        style: const TextStyle(color: Color(0xFFFFE066), fontWeight: FontWeight.w800, fontSize: 13),
                      )
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  'Drag from one tile to a neighbor · result must equal ${_cfg.target}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.28), fontSize: 11),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Row(
                  children: [
                    _action(icon: '💡', label: 'Hint', onTap: _showHint),
                    _action(icon: '🔀', label: 'Shuffle', onTap: _shuffle),
                    _action(icon: '↺', label: 'Restart', onTap: () => _resetLevel(_level)),
                  ],
                ),
              ),
            ],
          ),
          if (_phase != _Phase.playing) _overlay(),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {Color? color}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 8,
                color: Colors.white.withValues(alpha: 0.3),
                letterSpacing: 0.9,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color ?? Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          onPressed: _phase == _Phase.playing ? onTap : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            foregroundColor: Colors.white.withValues(alpha: 0.65),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlay() {
    final win = _phase == _Phase.win;
    return Positioned.fill(
      child: Container(
        color: const Color(0xE6080A0C),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1113),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(win ? '🎉' : '💀', style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text(
                  win ? 'Level Complete!' : 'Out of Moves',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: win ? const Color(0xFF00D4AA) : const Color(0xFFFF6444),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  win ? 'You crushed the target.' : 'Try spotting target pairs faster.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Score: $_score',
                  style: const TextStyle(
                    color: Color(0xFFFFE066),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (win && _level + 1 < _levels.length)
                      OutlinedButton(
                        onPressed: _advanceLevel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00D4AA),
                          side: const BorderSide(color: Color(0xFF00D4AA), width: 2),
                        ),
                        child: const Text('Next Level'),
                      ),
                    OutlinedButton(
                      onPressed: () => _resetLevel(_level),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFE066),
                        side: const BorderSide(color: Color(0xFFFFE066), width: 2),
                      ),
                      child: Text(win ? 'Replay' : 'Try Again'),
                    ),
                    if (!win)
                      OutlinedButton(
                        onPressed: () => context.goNamed(GameRouteNames.home),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.45),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 2),
                        ),
                        child: const Text('Home'),
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
