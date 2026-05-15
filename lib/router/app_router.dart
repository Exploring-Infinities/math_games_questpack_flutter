import 'package:flutter/material.dart';

import 'route_names.dart';
import '../screens/equation_balance_screen.dart';
import '../screens/flip_quest_screen.dart';
import '../screens/home_screen.dart';
import '../screens/math_golf_screen.dart';
import '../screens/math_tetris_screen.dart';
import '../screens/number_crush_screen.dart';
import '../screens/number_merge_screen.dart';
import '../screens/number_ninja_screen.dart';

Map<String, WidgetBuilder> createMathGamesRoutes() {
  return {
    GameRouteNames.home: (_) => const HomeScreen(),
    GameRouteNames.equationBalance: (_) => const EquationBalanceScreen(),
    GameRouteNames.numberNinja: (_) => const NumberNinjaScreen(),
    GameRouteNames.flipQuest: (_) => const FlipQuestScreen(),
    GameRouteNames.mathTetris: (_) => const MathTetrisScreen(),
    GameRouteNames.numberMerge: (_) => const NumberMergeScreen(),
    GameRouteNames.mathGolf: (_) => const MathGolfScreen(),
    GameRouteNames.numberCrush: (_) => const NumberCrushScreen(),
  };
}

WidgetBuilder? mathGamesRouteBuilder(String? routeName) {
  if (routeName == null) return null;
  return createMathGamesRoutes()[routeName];
}

Route<dynamic>? createMathGamesOnGenerateRoute(RouteSettings settings) {
  final builder = mathGamesRouteBuilder(settings.name);
  if (builder == null) return null;
  return MaterialPageRoute<void>(
    settings: settings,
    builder: builder,
  );
}

Future<void> pushMathGamesRoute(
  BuildContext context,
  String routeName,
) async {
  final navigator = Navigator.of(context);
  try {
    await navigator.pushNamed(routeName);
    return;
  } catch (_) {
    final builder = mathGamesRouteBuilder(routeName);
    if (builder == null) rethrow;
    await navigator.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: routeName),
        builder: builder,
      ),
    );
  }
}

Future<void> goToMathGamesHome(BuildContext context) async {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  const home = GameRouteNames.home;
  try {
    await navigator.pushReplacementNamed(home);
    return;
  } catch (_) {
    final builder = mathGamesRouteBuilder(home);
    if (builder == null) return;
    await navigator.pushReplacement(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: home),
        builder: builder,
      ),
    );
  }
}
