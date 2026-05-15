import 'package:flutter/material.dart';

import 'math_games_questpack_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MathGamesQuestpack.init();
  runApp(const MathGamesQuestpackApp());
}
