import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vpn_oko/core/theme/oko_motion.dart';
import 'package:vpn_oko/core/theme/oko_tones.dart';
import 'package:vpn_oko/features/vpn_connection/presentation/widgets/cooldown_notice.dart';

class DemoExpiredOverlay extends StatefulWidget {
  const DemoExpiredOverlay({required this.cooldownUntil, super.key});

  final DateTime cooldownUntil;

  @override
  State<DemoExpiredOverlay> createState() => _DemoExpiredOverlayState();
}

class _DemoExpiredOverlayState extends State<DemoExpiredOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OkoMotion.enterScreen,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: OkoMotion.enterScreenCurve,
    );
    _scale = Tween<double>(begin: 0.94, end: 1).animate(_fade);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered) {
      return;
    }
    _entered = true;
    unawaited(HapticFeedback.mediumImpact());
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tones = context.okoTones;
    final textTheme = Theme.of(context).textTheme;
    return Positioned.fill(
      child: FadeTransition(
        opacity: _fade,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.72),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ScaleTransition(
                scale: _scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tones.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: tones.accentTransitional.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hourglass_disabled_rounded,
                          size: 48,
                          color: tones.accentTransitional,
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          header: true,
                          child: Text(
                            'Вы исчерпали 5 минут демо подключения',
                            textAlign: TextAlign.center,
                            style: textTheme.titleMedium?.copyWith(
                              color: tones.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Демо-сессия ограничена 5 минутами. '
                          'Между сессиями действует короткий перерыв.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: tones.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        CooldownNotice(cooldownUntil: widget.cooldownUntil),
                        const SizedBox(height: 12),
                        Text(
                          'Скоро снова можно подключиться',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: tones.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
