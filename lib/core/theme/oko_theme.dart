import 'package:flutter/material.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/core/theme/oko_typography.dart';

class OkoTheme {
  const OkoTheme._();

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        tones: OkoTones.dark,
        colorScheme: _darkScheme,
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        tones: OkoTones.light,
        colorScheme: _lightScheme,
      );

  static ThemeData _build({
    required Brightness brightness,
    required OkoTones tones,
    required ColorScheme colorScheme,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: OkoTypography.textTheme(brightness),
      extensions: <OkoTones>[tones],
    );
  }

  static const Color _voidBackground = Color(0xFF0B0F14);
  static const Color _lightBackground = Color(0xFFF4F6F9);
  static const Color _onLight = Color(0xFFFFFFFF);

  static final ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: OkoTones.dark.accentConnected,
    onPrimary: _voidBackground,
    secondary: OkoTones.dark.accentIdle,
    onSecondary: OkoTones.dark.textPrimary,
    error: OkoTones.dark.accentError,
    onError: _voidBackground,
    surface: _voidBackground,
    onSurface: OkoTones.dark.textPrimary,
  );

  static final ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: OkoTones.light.accentConnected,
    onPrimary: _onLight,
    secondary: OkoTones.light.accentIdle,
    onSecondary: _onLight,
    error: OkoTones.light.accentError,
    onError: _onLight,
    surface: _lightBackground,
    onSurface: OkoTones.light.textPrimary,
  );
}
