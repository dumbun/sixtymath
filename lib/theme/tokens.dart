import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Colours and type, carried over from the web prototype: graph paper, hard
/// offset shadows, one blue pen colour.
class Tokens {
  const Tokens({
    required this.paper,
    required this.grid,
    required this.ink,
    required this.inkSoft,
    required this.edge,
    required this.line,
    required this.key,
    required this.pen,
    required this.onPen,
    required this.ok,
    required this.bad,
  });

  final Color paper;
  final Color grid;
  final Color ink;
  final Color inkSoft;
  final Color edge;
  final Color line;
  final Color key;
  final Color pen;
  final Color onPen;
  final Color ok;
  final Color bad;

  static const Tokens light = Tokens(
    paper: Color(0xFFEEF2F8),
    grid: Color.fromRGBO(20, 33, 61, 0.075),
    ink: Color(0xFF14213D),
    inkSoft: Color(0xFF56627F),
    edge: Color(0xFF14213D),
    line: Color.fromRGBO(20, 33, 61, 0.2),
    key: Color(0xFFFFFFFF),
    pen: Color(0xFF2748D8),
    onPen: Color(0xFFFFFFFF),
    ok: Color(0xFF15803D),
    bad: Color(0xFFD0343B),
  );

  static const Tokens dark = Tokens(
    paper: Color(0xFF0D1426),
    grid: Color.fromRGBO(214, 226, 255, 0.065),
    ink: Color(0xFFE8EEFC),
    inkSoft: Color(0xFF97A4C4),
    edge: Color(0xFF8E9FCB),
    line: Color.fromRGBO(232, 238, 252, 0.24),
    key: Color(0xFF17213A),
    pen: Color(0xFF8AA0FF),
    onPen: Color(0xFF0D1426),
    ok: Color(0xFF4ADE80),
    bad: Color(0xFFFF7479),
  );

  static Tokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Display face. Bundle Bricolage Grotesque under `fonts:` in pubspec.yaml
  /// and set [displayFamily]; until then the system font is used.
  static const String? displayFamily = null;

  static const String monoFamily = 'Menlo';
  static const List<String> monoFallback = <String>[
    'Roboto Mono',
    'Courier New',
    'monospace',
  ];

  TextStyle display(double size,
      {FontWeight weight = FontWeight.w800, Color? color, double? spacing}) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      fontWeight: weight,
      color: color ?? ink,
      letterSpacing: spacing ?? -size * 0.03,
      height: 1.05,
    );
  }

  TextStyle mono(double size,
      {FontWeight weight = FontWeight.w600,
      Color? color,
      double spacing = 0,
      double? height}) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: monoFallback,
      fontSize: size,
      fontWeight: weight,
      color: color ?? ink,
      letterSpacing: spacing,
      height: height,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  /// Small uppercase label.
  TextStyle label({Color? color}) =>
      mono(11, weight: FontWeight.w500, color: color ?? inkSoft, spacing: 1.3);

  ThemeData toTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: pen,
        brightness: brightness,
      ).copyWith(surface: paper, primary: pen, onPrimary: onPen),
      splashFactory: NoSplash.splashFactory,
    );
  }
}
