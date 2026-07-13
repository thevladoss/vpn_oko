import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OkoTypography {
  const OkoTypography._();

  static TextTheme textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;
    return base.copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        textStyle: base.displayLarge,
        fontSize: 48,
        height: 1,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        textStyle: base.titleMedium,
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      bodyMedium: GoogleFonts.inter(
        textStyle: base.bodyMedium,
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w400,
      ),
      labelSmall: GoogleFonts.inter(
        textStyle: base.labelSmall,
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      bodySmall: GoogleFonts.inter(
        textStyle: base.bodySmall,
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  static TextStyle mono(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;
    return GoogleFonts.jetBrainsMono(
      textStyle: base.bodySmall,
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w400,
    );
  }
}
