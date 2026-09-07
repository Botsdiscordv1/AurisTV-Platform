import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../models/user_settings.dart';
import 'auth_provider.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, UserSettings>((ref) {
  return SettingsNotifier(ref);
});

class SettingsNotifier extends StateNotifier<UserSettings> {
  final Ref ref;
  late Box _box;

  SettingsNotifier(this.ref) : super(const UserSettings()) {
    _init();
  }

  Future<void> _init() async {
    _box = Hive.box('settings');
    final String? stored = _box.get('user_settings');
    
    if (stored != null) {
      try {
        state = UserSettings.fromJson(jsonDecode(stored));
      } catch (e) {
        // Fallback al default si el JSON es corrupto
      }
    }
    
    // Si estamos logueados, podríamos intentar sincronizar desde la nube (Supabase)
    // ref.listen(authProvider, (prev, next) { ... });
  }

  Future<void> updateSettings(UserSettings newSettings) async {
    state = newSettings;
    await _box.put('user_settings', jsonEncode(state.toJson()));
    
    // TODO: Sincronizar con Supabase si el usuario está logueado
  }

  Future<void> setPreferredQuality(String quality) => updateSettings(state.copyWith(preferredQuality: quality));
  Future<void> setPreferredLanguage(String lang) => updateSettings(state.copyWith(preferredLanguage: lang));
  Future<void> setAutoPlayTrailers(bool value) => updateSettings(state.copyWith(autoPlayTrailers: value));
  Future<void> setAutoPlayNextEpisode(bool value) => updateSettings(state.copyWith(autoPlayNextEpisode: value));
  Future<void> setShowAiringCountdown(bool value) => updateSettings(state.copyWith(showAiringCountdown: value));
  Future<void> setSubtitleSize(double size) => updateSettings(state.copyWith(subtitleSize: size));
  Future<void> setSubtitleColor(int color) => updateSettings(state.copyWith(subtitleColor: color));
  Future<void> setExternalSyncEnabled(bool value) => updateSettings(state.copyWith(externalSyncEnabled: value));
}
