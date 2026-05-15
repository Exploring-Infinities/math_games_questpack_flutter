import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAppTheme() {
  const accent = Color(0xFF88FFC0);
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: accent,
      surface: const Color(0xFF0A0A0A),
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.black,
  );
  return base.copyWith(
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme),
    primaryTextTheme: GoogleFonts.nunitoTextTheme(base.primaryTextTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}
