import 'package:flutter/material.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';

@immutable
class OsinTones extends ThemeExtension<OsinTones> {
  const OsinTones({
    required this.accentConnected,
    required this.accentTransitional,
    required this.accentError,
    required this.accentIdle,
    required this.glow,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color accentConnected;
  final Color accentTransitional;
  final Color accentError;
  final Color accentIdle;
  final Color glow;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;

  Color accentFor(VpnStatus status) => switch (status) {
        VpnStatus.connected => accentConnected,
        VpnStatus.connecting || VpnStatus.disconnecting => accentTransitional,
        VpnStatus.error => accentError,
        VpnStatus.disconnected => accentIdle,
      };

  @override
  OsinTones copyWith({
    Color? accentConnected,
    Color? accentTransitional,
    Color? accentError,
    Color? accentIdle,
    Color? glow,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return OsinTones(
      accentConnected: accentConnected ?? this.accentConnected,
      accentTransitional: accentTransitional ?? this.accentTransitional,
      accentError: accentError ?? this.accentError,
      accentIdle: accentIdle ?? this.accentIdle,
      glow: glow ?? this.glow,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  OsinTones lerp(ThemeExtension<OsinTones>? other, double t) {
    if (other is! OsinTones) {
      return this;
    }
    return OsinTones(
      accentConnected: Color.lerp(accentConnected, other.accentConnected, t)!,
      accentTransitional:
          Color.lerp(accentTransitional, other.accentTransitional, t)!,
      accentError: Color.lerp(accentError, other.accentError, t)!,
      accentIdle: Color.lerp(accentIdle, other.accentIdle, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }

  static const OsinTones dark = OsinTones(
    accentConnected: Color(0xFF2CE5A7),
    accentTransitional: Color(0xFFFFB454),
    accentError: Color(0xFFFF5C5C),
    accentIdle: Color(0xFF5A6472),
    glow: Color(0x1AFFFFFF),
    surfaceCard: Color(0xFF121821),
    surfaceElevated: Color(0xFF1A2230),
    textPrimary: Color(0xFFF2F5F9),
    textSecondary: Color(0xFF8B95A5),
  );

  static const OsinTones light = OsinTones(
    accentConnected: Color(0xFF0E9E75),
    accentTransitional: Color(0xFFB26A00),
    accentError: Color(0xFFC62828),
    accentIdle: Color(0xFF5A6472),
    glow: Color(0x140B0F14),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEEF1F5),
    textPrimary: Color(0xFF0B0F14),
    textSecondary: Color(0xFF5A6472),
  );
}

extension OsinTonesContext on BuildContext {
  OsinTones get osinTones {
    final tones = Theme.of(this).extension<OsinTones>();
    assert(tones != null, 'OsinTones is missing; wrap the tree in OsinTheme.');
    return tones!;
  }
}
