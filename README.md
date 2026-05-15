# math_games_questpack_flutter

Reusable Flutter package that contains the Math Games module (home + mini-games) for embedding inside a parent app.

## What this package exposes

- `MathGamesQuestpack.init()` to initialize local prefs used by games
- `MathGamesQuestpack.routes(basePath: ...)` to plug module routes into a host `go_router`
- `MathGamesQuestpackApp` for standalone local/dev run

## Host app integration

```dart
import 'package:go_router/go_router.dart';
import 'package:math_games_questpack_flutter/math_games_questpack_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MathGamesQuestpack.init();

  final router = GoRouter(
    routes: [
      // host routes...
      ...MathGamesQuestpack.routes(basePath: '/math-games'),
    ],
  );
}
```

## Run standalone package app

This repo still includes `lib/main.dart` for direct local testing:

```bash
flutter run
```
