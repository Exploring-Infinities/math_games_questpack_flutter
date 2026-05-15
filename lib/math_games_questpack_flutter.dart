library math_games_questpack_flutter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'storage/game_prefs.dart';
import 'theme/app_theme.dart';

export 'router/app_router.dart' show createAppRouter, createMathGamesRoutes;
export 'router/route_names.dart';

class MathGamesQuestpack {
  const MathGamesQuestpack._();

  static Future<void> init() => GamePrefs.init();

  static List<RouteBase> routes({String basePath = ''}) =>
      createMathGamesRoutes(basePath: basePath);
}

class MathGamesQuestpackApp extends StatelessWidget {
  const MathGamesQuestpackApp({
    super.key,
    this.title = 'Math Games',
    this.basePath = '',
  });

  final String title;
  final String basePath;

  @override
  Widget build(BuildContext context) {
    final router = createAppRouter(basePath: basePath);
    return MaterialApp.router(
      title: title,
      theme: buildAppTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
