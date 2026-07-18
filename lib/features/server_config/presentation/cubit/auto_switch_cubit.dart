import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn_osin/features/server_config/domain/repositories/settings_repository.dart';
import 'package:vpn_osin/features/server_config/presentation/cubit/auto_switch_state.dart';

class AutoSwitchCubit extends Cubit<AutoSwitchState> {
  AutoSwitchCubit(this._settings) : super(const AutoSwitchState()) {
    _subscription = _settings.watchAutoSwitch().listen(_onEnabled);
  }

  final SettingsRepository _settings;

  late final StreamSubscription<bool> _subscription;

  void setAvailable({required bool available}) {
    if (isClosed) return;
    emit(state.copyWith(available: available));
  }

  Future<void> toggle({required bool enabled}) async {
    if (!state.available) return;
    await _settings.setAutoSwitch(enabled: enabled);
  }

  void _onEnabled(bool enabled) {
    if (isClosed) return;
    emit(state.copyWith(enabled: enabled));
  }

  @override
  Future<void> close() {
    unawaited(_subscription.cancel());
    return super.close();
  }
}
