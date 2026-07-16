import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_osin/core/theme/osin_theme.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';
import 'package:vpn_osin/core/theme/vpn_status.dart';

void main() {
  group('OsinTones.accentFor', () {
    const dark = OsinTones.dark;

    test('maps connected to accentConnected', () {
      expect(dark.accentFor(VpnStatus.connected), dark.accentConnected);
    });

    test('maps connecting and disconnecting to accentTransitional', () {
      expect(dark.accentFor(VpnStatus.connecting), dark.accentTransitional);
      expect(dark.accentFor(VpnStatus.disconnecting), dark.accentTransitional);
    });

    test('maps error to accentError', () {
      expect(dark.accentFor(VpnStatus.error), dark.accentError);
    });

    test('maps disconnected to accentIdle', () {
      expect(dark.accentFor(VpnStatus.disconnected), dark.accentIdle);
    });
  });

  group('OsinTones.lerp', () {
    const dark = OsinTones.dark;
    const light = OsinTones.light;

    test('returns dark fields at t = 0.0', () {
      final lerped = dark.lerp(light, 0);
      expect(lerped.accentConnected, dark.accentConnected);
      expect(lerped.accentTransitional, dark.accentTransitional);
      expect(lerped.accentError, dark.accentError);
      expect(lerped.accentIdle, dark.accentIdle);
      expect(lerped.glow, dark.glow);
      expect(lerped.surfaceCard, dark.surfaceCard);
      expect(lerped.surfaceElevated, dark.surfaceElevated);
      expect(lerped.textPrimary, dark.textPrimary);
      expect(lerped.textSecondary, dark.textSecondary);
    });

    test('returns light fields at t = 1.0', () {
      final lerped = dark.lerp(light, 1);
      expect(lerped.accentConnected, light.accentConnected);
      expect(lerped.accentTransitional, light.accentTransitional);
      expect(lerped.accentError, light.accentError);
      expect(lerped.accentIdle, light.accentIdle);
      expect(lerped.glow, light.glow);
      expect(lerped.surfaceCard, light.surfaceCard);
      expect(lerped.surfaceElevated, light.surfaceElevated);
      expect(lerped.textPrimary, light.textPrimary);
      expect(lerped.textSecondary, light.textSecondary);
    });

    test('returns this when other is not OsinTones', () {
      expect(dark.lerp(null, 0.5), same(dark));
    });
  });

  group('BuildContext.osinTones', () {
    testWidgets('returns the OsinTones extension from the active theme',
        (tester) async {
      OsinTones? captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: OsinTheme.dark,
          home: Builder(
            builder: (context) {
              captured = context.osinTones;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(captured, same(OsinTones.dark));
    });
  });
}
