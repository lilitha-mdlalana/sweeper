import 'package:flutter_riverpod/flutter_riverpod.dart';

// NOTE: This is a deliberately minimal, temporary stub. Task 20 replaces this
// entire file with a fully-persisted AsyncNotifier<AppSettings> backed by
// shared_preferences, and updates ReviewScreen's call site accordingly.
class AppSettings {
  final bool confirmBeforeDelete;
  const AppSettings({this.confirmBeforeDelete = true});
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
