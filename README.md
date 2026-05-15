# math_games_questpack_flutter

Reusable Flutter package that contains the Math Games module (home + mini-games) for embedding inside a parent app.

## What this package exposes

- `MathGamesQuestpack.init()` to initialize local prefs used by games
- `MathGamesQuestpack.routes()` to plug module routes into a host app using named routes
- `MathGamesQuestpackApp` for standalone local/dev run

## Host app integration

```dart
import 'package:math_games_questpack_flutter/math_games_questpack_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MathGamesQuestpack.init();
}
```

```dart
MaterialApp(
  initialRoute: GameRouteNames.home,
  routes: {
    // host routes...
    ...MathGamesQuestpack.routes(),
  },
);
```

If your app already uses only `onGenerateRoute`, delegate unknown routes:

```dart
Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  // host switch/cases...
  final moduleRoute = createMathGamesOnGenerateRoute(settings);
  if (moduleRoute != null) return moduleRoute;
  return null;
}
```

## Run standalone package app

This repo still includes `lib/main.dart` for direct local testing:

```bash
flutter run
```
