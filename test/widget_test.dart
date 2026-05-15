import 'package:flutter_test/flutter_test.dart';

import 'package:math_games_questpack_flutter/math_games_questpack_flutter.dart';

void main() {
  test('exports stable route names', () {
    expect(GameRouteNames.home, 'mg_home');
    expect(GameRouteNames.flipQuest, 'mg_flip_quest');
  });
}
