import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_osin/core/theme/osin_tones.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/auto_switch_cubit.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/auto_switch_state.dart';

class AutoSwitchToggle extends StatelessWidget {
  const AutoSwitchToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AutoSwitchCubit, AutoSwitchState>(
      builder: (context, state) {
        final tones = context.osinTones;
        final textTheme = Theme.of(context).textTheme;
        final active = state.available && state.enabled;
        final accent = active ? tones.accentConnected : tones.textSecondary;
        final title = state.available && state.enabled
            ? 'Автопереключение'
            : state.available
                ? 'Одиночный сервер'
                : 'Автопереключение';
        final subtitle = state.available
            ? (state.enabled
                ? 'Ядро само выбирает лучший сервер подписки'
                : 'Подключение к выбранному серверу')
            : 'Доступно для серверов из подписки';
        return Semantics(
          toggled: active,
          enabled: state.available,
          label: 'Автопереключение серверов подписки',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: tones.surfaceCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Opacity(
              opacity: state.available ? 1 : 0.6,
              child: Row(
                children: [
                  Icon(
                    active ? Icons.auto_mode_rounded : Icons.swap_horiz_rounded,
                    color: accent,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.bodyMedium?.copyWith(
                            color: tones.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: tones.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: active,
                    onChanged: state.available
                        ? (value) => context
                              .read<AutoSwitchCubit>()
                              .toggle(enabled: value)
                        : null,
                    activeTrackColor: tones.accentConnected,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
