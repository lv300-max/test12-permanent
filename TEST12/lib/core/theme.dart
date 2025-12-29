import 'package:flutter/material.dart';

class Try12Colors {
  static const bg = Color(0xFF03060D);
  static const panel = Color(0xFF0F141F);
  static const board = Color(0xFF141A25);
  static const border = Color(0xFF1F2937);
  static const text = Color(0xFFE8EAFF);
  static const dim = Color(0xFF8B94A1);
  static const highlight = Color(0xFFFEDB7E);
  static const accent = Color(0xFF6CE4BA);
  static const red = Color(0xFFB63C3C);
  static const green = Color(0xFF3DD37D);
  static const amber = Color(0xFFD29A27);
}

class Try12Gradients {
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF03060D),
      Color(0xFF090F1A),
      Color(0xFF05090F),
    ],
  );

  static const LinearGradient panel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF161E2A),
      Color(0xFF0E141F),
    ],
  );

  static const LinearGradient neonAccent = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF6CE4BA),
      Color(0xFFFEDB7E),
    ],
  );
}

final try12Theme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Try12Colors.bg,
  useMaterial3: true,
  colorScheme: const ColorScheme.dark().copyWith(
    primary: Try12Colors.highlight,
    secondary: Try12Colors.accent,
    surface: Try12Colors.panel,
    outline: Try12Colors.border,
  ),
  fontFamily: 'Roboto',
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
      color: Try12Colors.text,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      color: Try12Colors.text,
      height: 1.4,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      color: Try12Colors.text,
    ),
    bodySmall: TextStyle(
      fontSize: 11,
      color: Try12Colors.dim,
    ),
    labelSmall: TextStyle(
      fontFamily: 'RobotoMono',
      fontSize: 10,
      color: Try12Colors.dim,
      letterSpacing: 0.8,
    ),
  ),
);
