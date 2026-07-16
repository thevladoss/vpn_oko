import 'package:flutter/material.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';
import 'package:vpn_osin/core/theme/osin_typography.dart';

class OsinTheme {
  const OsinTheme._();

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        tones: OsinTones.dark,
        colorScheme: _darkScheme,
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        tones: OsinTones.light,
        colorScheme: _lightScheme,
      );

  static ThemeData _build({
    required Brightness brightness,
    required OsinTones tones,
    required ColorScheme colorScheme,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: OsinTypography.textTheme(brightness),
      extensions: <OsinTones>[tones],
    );
  }

  static const Color _voidBackground = Color(0xFF0B0F14);
  static const Color _lightBackground = Color(0xFFF4F6F9);
  static const Color _onLight = Color(0xFFFFFFFF);

  static final ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: OsinTones.dark.accentConnected,
    onPrimary: _voidBackground,
    secondary: OsinTones.dark.accentIdle,
    onSecondary: OsinTones.dark.textPrimary,
    error: OsinTones.dark.accentError,
    onError: _voidBackground,
    surface: _voidBackground,
    onSurface: OsinTones.dark.textPrimary,
  );

  static final ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: OsinTones.light.accentConnected,
    onPrimary: _onLight,
    secondary: OsinTones.light.accentIdle,
    onSecondary: _onLight,
    error: OsinTones.light.accentError,
    onError: _onLight,
    surface: _lightBackground,
    onSurface: OsinTones.light.textPrimary,
  );
}
