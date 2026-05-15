import 'package:go_router/go_router.dart';

import 'route_names.dart';
import '../screens/equation_balance_screen.dart';
import '../screens/flip_quest_screen.dart';
import '../screens/home_screen.dart';
import '../screens/math_golf_screen.dart';
import '../screens/math_tetris_screen.dart';
import '../screens/number_crush_screen.dart';
import '../screens/number_merge_screen.dart';
import '../screens/number_ninja_screen.dart';

String _normalizeBasePath(String basePath) {
  if (basePath.isEmpty || basePath == '/') return '';
  final trimmed = basePath.endsWith('/') ? basePath.substring(0, basePath.length - 1) : basePath;
  return trimmed.startsWith('/') ? trimmed : '/$trimmed';
}

String _routePath(String basePath, String childPath) {
  final base = _normalizeBasePath(basePath);
  if (childPath == '/') return base.isEmpty ? '/' : base;
  final child = childPath.startsWith('/') ? childPath : '/$childPath';
  return '$base$child';
}

List<RouteBase> createMathGamesRoutes({String basePath = ''}) {
  return [
    GoRoute(
      name: GameRouteNames.home,
      path: _routePath(basePath, '/'),
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      name: GameRouteNames.equationBalance,
      path: _routePath(basePath, '/equation-balance'),
      builder: (context, state) => const EquationBalanceScreen(),
    ),
    GoRoute(
      name: GameRouteNames.numberNinja,
      path: _routePath(basePath, '/number-ninja'),
      builder: (context, state) => const NumberNinjaScreen(),
    ),
    GoRoute(
      name: GameRouteNames.flipQuest,
      path: _routePath(basePath, '/flip-quest'),
      builder: (context, state) => const FlipQuestScreen(),
    ),
    GoRoute(
      name: GameRouteNames.mathTetris,
      path: _routePath(basePath, '/math-tetris'),
      builder: (context, state) => const MathTetrisScreen(),
    ),
    GoRoute(
      name: GameRouteNames.numberMerge,
      path: _routePath(basePath, '/number-merge'),
      builder: (context, state) => const NumberMergeScreen(),
    ),
    GoRoute(
      name: GameRouteNames.mathGolf,
      path: _routePath(basePath, '/math-golf'),
      builder: (context, state) => const MathGolfScreen(),
    ),
    GoRoute(
      name: GameRouteNames.numberCrush,
      path: _routePath(basePath, '/number-crush'),
      builder: (context, state) => const NumberCrushScreen(),
    ),
  ];
}

GoRouter createAppRouter({String basePath = ''}) {
  return GoRouter(
    initialLocation: _routePath(basePath, '/'),
    routes: createMathGamesRoutes(basePath: basePath),
  );
}
