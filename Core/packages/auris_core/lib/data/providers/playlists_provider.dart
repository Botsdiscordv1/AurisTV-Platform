import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/m3u_parser.dart';
import '../models/builtin_playlists.dart';
import '../models/playlist_channel.dart';
import '../models/user_playlist.dart';

/// Box y clave donde se persisten las listas añadidas por el usuario.
/// Se abre de forma perezosa para no tocar los `main.dart` de las 3 apps.
const String kPlaylistBoxName = 'user_playlists';
const String kPlaylistListKey = 'lists';

@immutable
class PlaylistsState {
  /// Solo las listas del usuario; las integradas viven en [BuiltinPlaylists.all].
  final List<UserPlaylist> userLists;
  final bool loading;
  final String? error;

  const PlaylistsState({
    this.userLists = const [],
    this.loading = true,
    this.error,
  });

  PlaylistsState copyWith({
    List<UserPlaylist>? userLists,
    bool? loading,
    String? error,
  }) {
    return PlaylistsState(
      userLists: userLists ?? this.userLists,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, PlaylistsState>((ref) {
  return PlaylistsNotifier();
});

/// Lista con id conocido (integrada o del usuario); null si no existe.
final playlistByIdProvider = Provider.family<UserPlaylist?, String>((ref, id) {
  final state = ref.watch(playlistsProvider);
  final all = <UserPlaylist>[...BuiltinPlaylists.all, ...state.userLists];
  return all.firstWhereOrNull((p) => p.id == id);
});

class PlaylistsNotifier extends StateNotifier<PlaylistsState> {
  PlaylistsNotifier() : super(const PlaylistsState()) {
    _load();
  }

  Future<Box> _openBox() async {
    return Hive.isBoxOpen(kPlaylistBoxName)
        ? Hive.box(kPlaylistBoxName)
        : await Hive.openBox(kPlaylistBoxName);
  }

  Future<void> _load() async {
    try {
      final box = await _openBox();
      final raw = box.get(kPlaylistListKey);
      if (raw is List) {
        final items = raw
            .whereType<Map>()
            .map(UserPlaylist.fromJson)
            .where((p) => p.url.isNotEmpty)
            .toList();
        state = state.copyWith(userLists: items, loading: false);
      } else {
        state = state.copyWith(loading: false);
      }
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> _persist() async {
    try {
      final box = await _openBox();
      await box.put(
        kPlaylistListKey,
        state.userLists.map((p) => p.toJson()).toList(),
      );
    } catch (_) {
      // La persistencia nunca debe romper la UI; en memoria sigue correcto.
    }
  }

  /// Añade una lista del usuario.
  ///
  /// Devuelve `null` si todo fue bien o un mensaje de error en español.
  Future<String?> addList({required String name, required String url}) async {
    final cleanName = name.trim();
    final cleanUrl = url.trim();

    if (cleanName.isEmpty) return 'Escribe un nombre para la lista';
    if (cleanName.length > 60) {
      return 'El nombre no puede superar 60 caracteres';
    }

    final parsed = Uri.tryParse(cleanUrl);
    final validUrl = parsed != null &&
        parsed.hasScheme &&
        parsed.host.isNotEmpty &&
        (parsed.isScheme('http') || parsed.isScheme('https'));
    if (!validUrl) return 'La URL debe empezar por http:// o https://';

    final duplicates = <UserPlaylist>[
      ...BuiltinPlaylists.all,
      ...state.userLists,
    ].any((p) => p.url.toLowerCase() == cleanUrl.toLowerCase());
    if (duplicates) return 'Esa lista ya está añadida';

    final playlist = UserPlaylist(
      id: 'usr_${const Uuid().v4().replaceAll('-', '').substring(0, 10)}',
      name: cleanName,
      url: cleanUrl,
      isBuiltIn: false,
      source: 'custom',
      addedAt: DateTime.now(),
    );

    state = state.copyWith(userLists: [playlist, ...state.userLists]);
    await _persist();
    return null;
  }

  Future<void> removeList(String id) async {
    state =
        state.copyWith(userLists: state.userLists.where((p) => p.id != id).toList());
    await PlaylistRepository.instance.invalidate(id);
    await _persist();
  }
}

/// Error de carga de canales con mensaje ya traducido para el usuario.
class PlaylistChannelsFailure implements Exception {
  final String message;
  const PlaylistChannelsFailure(this.message);

  @override
  String toString() => message;
}

/// Descarga, parsea y cachea los canales de una lista M3U.
///
/// Caché en memoria por sesión + caché persistente en Hive (`playlist_cache`)
/// con TTL de 12 horas. Toda la persistencia va en `try/catch`: si Hive falla,
/// la lista se sigue sirviendo desde red/memoria.
class PlaylistRepository {
  PlaylistRepository._();

  static final PlaylistRepository instance = PlaylistRepository._();

  static const String boxName = 'playlist_cache';
  static const Duration ttl = Duration(hours: 12);

  final Map<String, List<PlaylistChannel>> _memory = {};

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
    responseType: ResponseType.plain,
    followRedirects: true,
  ));

  Future<List<PlaylistChannel>> load(
    UserPlaylist playlist, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _memory[playlist.id];
      if (cached != null) return cached;
      final persisted = await _readCache(playlist.id);
      if (persisted != null) {
        _memory[playlist.id] = persisted;
        return persisted;
      }
    }

    String body;
    try {
      final response = await _dio.get<String>(playlist.url);
      body = response.data ?? '';
    } on DioException catch (e) {
      throw PlaylistChannelsFailure(_messageFor(e));
    }

    final channels = M3uParser.parse(body);
    if (channels.isEmpty) {
      throw PlaylistChannelsFailure(
        'La URL no contiene una lista M3U válida (no se encontraron canales)',
      );
    }

    _memory[playlist.id] = channels;
    await _writeCache(playlist.id, channels);
    return channels;
  }

  /// Invalida la caché en memoria y la persistente de una lista.
  Future<void> invalidate(String id) async {
    _memory.remove(id);
    try {
      if (Hive.isBoxOpen(boxName)) await Hive.box(boxName).delete(id);
    } catch (_) {}
  }

  String _messageFor(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tiempo de espera agotado al descargar la lista';
      case DioExceptionType.badResponse:
        return 'El servidor respondió con un error (${e.response?.statusCode})';
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        if (kIsWeb) {
          return 'No se pudo descargar la lista. En web, el servidor debe '
              'permitir CORS (las listas integradas de iptv-org sí lo hacen)';
        }
        return 'No se pudo conectar con la URL de la lista';
      default:
        return 'No se pudo descargar la lista';
    }
  }

  Future<List<PlaylistChannel>?> _readCache(String id) async {
    try {
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box(boxName)
          : await Hive.openBox(boxName);
      final raw = box.get(id);
      if (raw is! Map || raw['fetchedAt'] is! String) return null;
      final fetchedAt = DateTime.tryParse(raw['fetchedAt'] as String);
      if (fetchedAt == null || DateTime.now().difference(fetchedAt) > ttl) {
        return null;
      }
      final list = raw['channels'];
      if (list is! List) return null;
      final channels = list
          .whereType<Map>()
          .map(PlaylistChannel.fromJson)
          .where((c) => c.url.isNotEmpty)
          .toList();
      return channels.isEmpty ? null : channels;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String id, List<PlaylistChannel> channels) async {
    try {
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box(boxName)
          : await Hive.openBox(boxName);
      await box.put(id, {
        'fetchedAt': DateTime.now().toIso8601String(),
        'channels': channels.map((c) => c.toJson()).toList(),
      });
    } catch (_) {}
  }
}

/// Canales de una lista; se reutiliza en caché hasta que [refreshPlaylist]
/// invalida la entrada (pull-to-refresh / botón actualizar).
final playlistChannelsProvider =
    FutureProvider.autoDispose.family<List<PlaylistChannel>, String>(
  (ref, playlistId) async {
    final playlist = ref.watch(playlistByIdProvider(playlistId));
    if (playlist == null) {
      throw const PlaylistChannelsFailure('Lista no encontrada');
    }
    return PlaylistRepository.instance.load(playlist);
  },
);

/// Fuerza la recarga de canales de [playlistId] ignorando ambas cachés.
Future<void> refreshPlaylist(WidgetRef ref, String playlistId) async {
  await PlaylistRepository.instance.invalidate(playlistId);
  ref.invalidate(playlistChannelsProvider(playlistId));
}
