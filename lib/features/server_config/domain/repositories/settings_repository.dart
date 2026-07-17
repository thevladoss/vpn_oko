abstract interface class SettingsRepository {
  Stream<bool> watchAutoSwitch();

  Future<bool> autoSwitchEnabled();

  Future<void> setAutoSwitch({required bool enabled});
}
