import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auris_core/auris_core.dart';
import 'package:hive_ce/hive_ce.dart';

class AppSettings {
  final String serverAddress;
  
  AppSettings({required this.serverAddress});

  AppSettings copyWith({String? serverAddress}) {
    return AppSettings(
      serverAddress: serverAddress ?? this.serverAddress,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final Box _box;

  AppSettingsNotifier(this._box) : super(AppSettings(
    serverAddress: _box.get('server_address', defaultValue: ApiEndpoints.serverAddress),
  )) {
    // Inicializar la clase estática con el valor guardado
    ApiEndpoints.setServerAddress(state.serverAddress);
  }

  void updateServerAddress(String address) {
    _box.put('server_address', address);
    ApiEndpoints.setServerAddress(address);
    state = state.copyWith(serverAddress: address);
  }
}

final settingsBoxProvider = Provider<Box>((ref) {
  return Hive.box('settings');
});

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final box = ref.watch(settingsBoxProvider);
  return AppSettingsNotifier(box);
});

final settingsRepositoryProvider = Provider<AurisRepository>((ref) {
  return ref.watch(aurisRepositoryProvider);
});

final sourcesProvider = FutureProvider<List<SourceInfo>>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getSources();
});
