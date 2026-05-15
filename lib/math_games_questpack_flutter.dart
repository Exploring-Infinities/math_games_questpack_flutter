library math_games_questpack_flutter;

import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'router/route_names.dart';
import 'storage/game_prefs.dart';
import 'theme/app_theme.dart';

export 'router/app_router.dart'
    show
        createMathGamesOnGenerateRoute,
        createMathGamesRoutes,
        goToMathGamesHome,
        pushMathGamesRoute;
export 'router/route_names.dart';

class MathGamesQuestpack {
  const MathGamesQuestpack._();

  static Future<void> init() => GamePrefs.init();

  static Map<String, WidgetBuilder> routes() => createMathGamesRoutes();
}

class MathGamesQuestpackApp extends StatelessWidget {
  const MathGamesQuestpackApp({
    super.key,
    this.title = 'Math Games',
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: buildAppTheme(),
      initialRoute: GameRouteNames.home,
      routes: createMathGamesRoutes(),
      debugShowCheckedModeBanner: false,
    );
  }
}
