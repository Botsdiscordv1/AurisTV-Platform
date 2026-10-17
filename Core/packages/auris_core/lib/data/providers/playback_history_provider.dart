import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auris_core.dart';
import 'auth_provider.dart';

final playbackHistoryRepositoryProvider = Provider<PlaybackHistoryRepository>((ref) {
  final box = Hive.box('playback_history');
  final local = HivePlaybackHistoryRepository(box);
  final remote = SupabasePlaybackHistoryRepository(Supabase.instance.client);
  
  return HybridPlaybackHistoryRepository(local: local, remote: remote);
});

final playbackHistoryStateProvider = AsyncNotifierProvider<PlaybackHistoryNotifier, List<PlaybackHistory>>(() {
  return PlaybackHistoryNotifier();
});

/// Provider especializado para el carrusel de "Continuar Viendo"
/// Agrupa por obra y se queda con la entrada MÁS RECIENTE de cada una.
/// - Entrada sin completar → se muestra tal cual.
/// - Entrada completada → se muestra el SIGUIENTE episodio si sabemos que
///   existe: totalEpisodes conocido o la obra aparece en el calendario; si no
///   (series normales sin datos) la obra sale de Continuar Viendo y sigue
///   viva en el Historial de la biblioteca. Último episodio conocido → fuera.
/// - Si el calendario tiene ese episodio próximo a estrenarse, la tarjeta
///   cambia a modo "próximo estreno" con su fecha/hora ([upcomingAiringAt]).
/// - Descartada a mano (dismissed) → no se muestra.
final continueWatchingProvider = Provider<AsyncValue<List<PlaybackHistory>>>((ref) {
  final historyAsync = ref.watch(playbackHistoryStateProvider);
  final schedule = ref.watch(scheduleProvider).valueOrNull;

  return historyAsync.whenData((list) {
    final Map<String, PlaybackHistory> latestByContent = {};
    for (final h in list) {
      final prev = latestByContent[h.contentId];
      if (prev == null || h.updatedAt.isAfter(prev.updatedAt)) {
        latestByContent[h.contentId] = h;
      }
    }
    final items = <PlaybackHistory>[];
    for (final h in latestByContent.values) {
      if (h.dismissed) continue;
      if (!h.isCompleted) {
        items.add(h);
        continue;
      }
      final next = _nextEpisodeEntry(h, schedule);
      if (next != null) items.add(next);
    }
    return items..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  });
});

/// Entrada sintética del episodio siguiente para la fila de Continuar Viendo
/// (posición 0, sin título de episodio: no se conoce hasta abrir el detalle).
/// Si el calendario marca ese episodio como aún no estrenado, se adjunta su
/// fecha ([PlaybackHistory.upcomingAiringAt]) para el subtítulo de la tarjeta.
PlaybackHistory? _nextEpisodeEntry(
    PlaybackHistory h, ScheduleResponse? schedule) {
  final total = h.totalEpisodes;
  final ep = _episodeNumber(h.episode);
  if (ep == null || ep <= 0) return null;
  final int nextEp = ep + 1;
  final match = _scheduleMatch(h, schedule, nextEp);
  final int nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final int? upcoming = (match.airingAt != null && match.airingAt! > nowSec)
      ? match.airingAt
      : null;

  final bool hasMore = (total != null && total > 0)
      ? ep < total
      : match.showKnown;
  if (upcoming == null && !hasMore) {
    debugPrint('[CV] sin tarjeta "${h.title}" ep=$nextEp '
        'show=${match.showKnown} total=$total');
    return null;
  }

  return PlaybackHistory(
    contentId: h.contentId,
    season: h.season,
    episode: '$nextEp',
    positionInMilliseconds: 0,
    durationInMilliseconds: 0,
    updatedAt: h.updatedAt,
    title: h.title,
    metadataTitle: h.metadataTitle,
    posterUrl: h.posterUrl,
    bannerUrl: h.bannerUrl,
    logoUrl: h.logoUrl,
    category: h.category,
    source: h.source,
    url: h.url,
    alternativeSources: h.alternativeSources,
    kind: h.kind,
    type: h.type,
    year: h.year,
    progress: 0.0,
    isCompleted: false,
    profileId: h.profileId,
    totalEpisodes: total,
    upcomingAiringAt: upcoming,
  );
}

/// Busca la obra en el calendario (por URL/slug, o por título con `contains`
/// bidireccional como en el resto del repo). Devuelve `airingAt` del episodio
/// [nextEp] y si la obra aparece aunque sea con otro episodio.
({int? airingAt, bool showKnown}) _scheduleMatch(
    PlaybackHistory h, ScheduleResponse? schedule, int nextEp) {
  const none = (airingAt: null, showKnown: false);
  if (schedule == null) return none;
  final wanted = <String>{_normalizeTitle(h.title), _normalizeTitle(h.metadataTitle)}
    ..remove('');
  final url = _normalizeUrl(h.url);
  if (wanted.isEmpty && url.isEmpty) return none;

  int? airingAt;
  bool showKnown = false;
  for (final day in schedule.days) {
    for (final item in day.items) {
      if (!_sameShow(item, wanted, url)) continue;
      showKnown = true;
      if (item.episode == nextEp || item.nextEpisode == nextEp) {
        airingAt ??= item.airingAt;
      }
    }
  }
  return (airingAt: airingAt, showKnown: showKnown);
}

bool _sameShow(ScheduleItem item, Set<String> wanted, String url) {
  final itemUrl = _normalizeUrl(item.url);
  if (url.isNotEmpty &&
      itemUrl.isNotEmpty &&
      url.length >= 6 &&
      itemUrl.length >= 6 &&
      (itemUrl.contains(url) || url.contains(itemUrl))) {
    return true;
  }
  if (wanted.isEmpty) return false;
  final names = <String>{
    _normalizeTitle(item.title),
    _normalizeTitle(item.romaji),
    _normalizeTitle(item.english),
    _normalizeTitle(item.scrapedTitle),
    for (final s in item.synonyms) _normalizeTitle(s),
  }..remove('');
  for (final n in names) {
    for (final w in wanted) {
      if (_titleMatches(n, w)) return true;
    }
  }
  return false;
}

/// Igualdad o `contains` bidireccional (sólo si ambos son legibles).
bool _titleMatches(String a, String b) {
  if (a == b) return true;
  if (a.length < 4 || b.length < 4) return false;
  return a.contains(b) || b.contains(a);
}

String _normalizeUrl(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  var s = raw.toLowerCase().trim();
  final q = s.indexOf('?');
  if (q != -1) s = s.substring(0, q);
  s = s.replaceFirst(RegExp(r'^[a-z]+://'), '');
  final slash = s.indexOf('/');
  if (slash != -1) s = s.substring(slash + 1);
  s = s.replaceAll(RegExp(r'[^a-z0-9/]'), '');
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Extrae el número de episodio de strings tipo "9", "Ep 9", "T1:E9"
/// (se queda con la última cifra, para no confundir la temporada).
int? _episodeNumber(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final direct = int.tryParse(raw.trim());
  if (direct != null) return direct;
  final matches = RegExp(r'\d+').allMatches(raw).toList();
  if (matches.isEmpty) return null;
  return int.tryParse(matches.last.group(0)!);
}

String _normalizeTitle(String? raw) {
  var s = (raw ?? '').toLowerCase();
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuunc';
  for (var i = 0; i < from.length; i++) {
    s = s.replaceAll(from[i], to[i]);
  }
  return s.replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
}

class PlaybackHistoryNotifier extends AsyncNotifier<List<PlaybackHistory>> {
  Timer? _throttleTimer;
  PlaybackHistory? _pendingSave;
  
  final Map<String, int> _lastSavedPositionsMs = {};
  
  // Cache en memoria para actualizaciones rápidas sin recargar todo de Hive
  List<PlaybackHistory> _memoryCache = [];

  @override
  FutureOr<List<PlaybackHistory>> build() async {
    final repository = ref.watch(playbackHistoryRepositoryProvider);
    final user = ref.watch(authProvider);
    
    final profileId = user?.activeProfileId ?? 'guest_profile';
    
    if (kDebugMode) {
      print('[PlaybackHistoryNotifier] Build iniciado para profileId: $profileId (User: ${user?.id ?? 'null'})');
    }

    // Senior Fix: Ya no bloqueamos con Completer si el auth es null. 
    // Cargamos lo que tengamos en local (Hive) de inmediato para que la app sea funcional.
    final history = await repository.getHistory(profileId);
    _memoryCache = history;

    // Si hay usuario real, disparamos la sincronización en segundo plano
    if (user != null && user.email != null && user.id != 'guest_user') {
      _triggerSync(repository, profileId, user.id).ignore();
    }

    return _memoryCache;
  }

  Future<void> _triggerSync(PlaybackHistoryRepository repository, String profileId, String userId) async {
    await repository.syncWithCloud(profileId, userId);
    // Recargar memoria después de sync si algo cambió en la nube
    _memoryCache = await repository.getHistory(profileId);
    state = AsyncData(List.from(_memoryCache));
  }

  void updatePosition({
    required String contentId,
    int? season,
    String? episode,
    required int positionMs,
    required int durationMs,
    String? title,
    String? posterUrl,
    String? bannerUrl,
    String? logoUrl,
    String? category,
    String? source,
    String? url,
    List<SearchResult>? alternativeSources,
    String? kind,
    String? type,
    int? year,
    String? episodeTitle,
    int? totalEpisodes,
    bool force = false,
  }) {
    // [PlaybackHistory] Red de seguridad definitiva contra OP/ED en el historial
    if (episode == 'OP' || episode == 'ED') return;

    final user = ref.read(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';

    final double calcProgress = durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;
    final bool completed = calcProgress > 0.95;
    
    int finalPositionMs = completed ? durationMs : positionMs;
    double finalProgress = completed ? 1.0 : calcProgress;

    final key = PlaybackHistory.generateKey(contentId, season, episode, profileId: profileId);

    // Buscar en caché primero
    final existingHistory = _memoryCache.cast<PlaybackHistory?>().firstWhere(
      (h) => h?.key == key, 
      orElse: () => null
    );
    
    // Eliminamos la restricción de jumpDiff > 300000 para permitir seeks manuales
    // Pero mantenemos un pequeño throttle para no saturar si no hay cambios significativos
    if (!force) {
      final lastPersistedPos = _lastSavedPositionsMs[key] ?? -10000;
      final diff = (finalPositionMs - lastPersistedPos).abs();
      // Si el video es muy corto, bajamos el umbral a 5s, si no 10s
      final threshold = durationMs < 60000 ? 5000 : 10000;
      if (diff < threshold && !completed) return;
    }

    // Asegurar que posterUrl sea vertical y no un banner/backdrop horizontal
    String? validPoster = posterUrl;
    if (validPoster != null && (validPoster.contains('original') || validPoster.contains('backdrop') || validPoster.contains('banner'))) {
      bannerUrl ??= validPoster;
      validPoster = null;
    }

    final resolvedPoster = (validPoster != null && validPoster.isNotEmpty)
        ? validPoster
        : existingHistory?.posterUrl;

    final resolvedBanner = (bannerUrl != null && bannerUrl.isNotEmpty)
        ? bannerUrl
        : existingHistory?.bannerUrl;

    // No borrar un logo/banner ya guardado cuando el caller no aporta uno
    // ('' o null): el player a veces inicia sin el logo cargado y lo pisaba,
    // dejando la tarjeta de Continuar Viendo sin logo.
    final resolvedLogo = (logoUrl != null && logoUrl.isNotEmpty)
        ? logoUrl
        : existingHistory?.logoUrl;

    final history = PlaybackHistory(
      contentId: contentId,
      season: season,
      episode: episode,
      positionInMilliseconds: finalPositionMs,
      durationInMilliseconds: durationMs,
      updatedAt: DateTime.now(),
      progress: finalProgress,
      isCompleted: completed,
      title: title ?? existingHistory?.title,
      posterUrl: resolvedPoster,
      bannerUrl: resolvedBanner,
      logoUrl: resolvedLogo,
      category: category ?? existingHistory?.category,
      source: source ?? existingHistory?.source,
      url: url ?? existingHistory?.url,
      alternativeSources: alternativeSources ?? existingHistory?.alternativeSources,
      kind: kind ?? existingHistory?.kind,
      type: type ?? existingHistory?.type,
      year: year ?? existingHistory?.year,
      episodeTitle: episodeTitle ?? existingHistory?.episodeTitle,
      totalEpisodes: totalEpisodes ?? existingHistory?.totalEpisodes,
      profileId: profileId,
    );

    _pendingSave = history;
    
    // Actualización optimista de la memoria
    _updateMemoryCache(history);

    if (force) {
      _savePending(notify: true);
      return;
    }

    if (_throttleTimer == null || !_throttleTimer!.isActive) {
      _savePending();
      _throttleTimer = Timer(const Duration(seconds: 2), () {
        if (_pendingSave != null) _savePending();
      });
    }
  }

  void updatePosterForContent({required String contentId, required String title, required String posterUrl, String? bannerUrl, String? logoUrl}) {
    if (posterUrl.isEmpty) return;
    bool updatedAny = false;

    String normalize(String s) => s.toLowerCase()
        .replaceAll('ü', 'u').replaceAll('ä', 'a').replaceAll('ö', 'o')
        .replaceAll('é', 'e').replaceAll('á', 'a').replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ú', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    final cleanTitle = normalize(title);
    final cleanContentId = contentId.toLowerCase().trim();

    for (int i = 0; i < _memoryCache.length; i++) {
      final h = _memoryCache[i];
      final hTitle = normalize(h.title ?? '');
      final hContentId = h.contentId.toLowerCase().trim();
      final hUrl = (h.url ?? '').toLowerCase().trim();

      // Match ESTRICTO: id/url exacto o título normalizado IDÉNTICO.
      // Antes se comparaba con `contains` bidireccional, lo que aplicaba el
      // póster/logo de la obra abierta a OTRAS cuyo título lo contiene
      // (p.ej. "One Piece" → "One Piece Film Red"), mezclando logos entre
      // tarjetas de Continuar Viendo. Igual con id/url vacío.
      final bool idMatch = cleanContentId.isNotEmpty &&
          (hContentId == cleanContentId || hUrl == cleanContentId);
      final bool titleMatch = cleanTitle.isNotEmpty && hTitle == cleanTitle;

      if (idMatch || titleMatch) {
        if (h.posterUrl != posterUrl) {
          final keepBanner =
              h.bannerUrl != null && h.bannerUrl!.isNotEmpty;
          final String? newLogo =
              (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : h.logoUrl;
          _memoryCache[i] = h.copyWith(
            posterUrl: posterUrl,
            bannerUrl: keepBanner ? h.bannerUrl : bannerUrl,
            logoUrl: newLogo,
          );
          updatedAny = true;
          _pendingSave = _memoryCache[i];
        }
      }
    }
    if (updatedAny) {
      state = AsyncData(List.from(_memoryCache));
      _savePending(notify: false);
    }
  }

  void _updateMemoryCache(PlaybackHistory history) {
    final index = _memoryCache.indexWhere((h) => h.key == history.key);
    if (index != -1) {
      _memoryCache[index] = history;
    } else {
      _memoryCache.insert(0, history);
    }
    
    // Re-ordenar por fecha de actualización
    _memoryCache.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    
    // Notificar al estado (esto hará que la UI se actualice)
    state = AsyncData(List.from(_memoryCache));
  }

  Future<void> _savePending({bool notify = true}) async {
    if (_pendingSave == null) return;
    
    final history = _pendingSave!;
    _pendingSave = null;
    final key = history.key;
    _lastSavedPositionsMs[key] = history.positionInMilliseconds;

    final repository = ref.read(playbackHistoryRepositoryProvider);
    await repository.saveHistory(history);
    
    // Aplicar cleanup cada vez que guardamos para mantener la DB limpia
    final user = ref.read(authProvider);
    if (user != null) {
      await repository.cleanup(user.activeProfileId ?? 'guest_profile');
    }
  }

  PlaybackHistory? getProgress(String contentId, int? season, String? episode) {
    final user = ref.read(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';
    final key = PlaybackHistory.generateKey(contentId, season, episode, profileId: profileId);
    
    final history = _memoryCache.cast<PlaybackHistory?>().firstWhere(
      (h) => h?.key == key, 
      orElse: () => null
    );
    
    return history?.isFinished == true ? null : history;
  }

  PlaybackHistory? getLatestWatched(String contentId) {
    final entries = _memoryCache.where((h) => h.contentId == contentId).toList();
    if (entries.isEmpty) return null;
    return entries.first;
  }

  void updateSourcesForContent(String contentId, String? title, List<SearchResult> sources) {
    if (sources.isEmpty) return;
    bool updated = false;
    final repository = ref.read(playbackHistoryRepositoryProvider);
    final cleanTargetTitle = title?.toLowerCase().trim() ?? '';

    for (int i = 0; i < _memoryCache.length; i++) {
      final h = _memoryCache[i];
      final cleanHistoryTitle = h.title?.toLowerCase().trim() ?? '';
      
      final bool matches = h.contentId == contentId ||
                           h.url == contentId ||
                           contentId.contains(h.contentId) ||
                           h.contentId.contains(contentId) ||
                           (cleanTargetTitle.isNotEmpty && cleanHistoryTitle.isNotEmpty && (cleanHistoryTitle == cleanTargetTitle || cleanHistoryTitle.contains(cleanTargetTitle) || cleanTargetTitle.contains(cleanHistoryTitle)));

      if (matches) {
        if (h.alternativeSources == null || h.alternativeSources!.isEmpty || h.alternativeSources!.length < sources.length) {
          _memoryCache[i] = h.copyWith(alternativeSources: sources);
          updated = true;
          repository.saveHistory(_memoryCache[i]).ignore();
        }
      }
    }
    if (updated) {
      state = AsyncData(List.from(_memoryCache));
    }
  }

  /// Borra TODAS las entradas (episodios) de un contenido. Para la tarjeta
  /// agrupada del Historial (una por obra).
  /// Oculta una entrada de Continuar Viendo SIN borrarla del Historial.
  /// El usuario puede recuperarla desde Biblioteca → Historial; ver de nuevo
  /// la revive (updatePosition resetea dismissed). Solo el borrado en
  /// Historial (deleteContentHistory) la elimina de verdad.
  Future<void> dismissFromContinue(
      String contentId, int? season, String? episode) async {
    final user = ref.read(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';
    final key =
        PlaybackHistory.generateKey(contentId, season, episode, profileId: profileId);
    int index = _memoryCache.indexWhere((h) => h.key == key);
    if (index == -1) {
      int latest = -1;
      for (var i = 0; i < _memoryCache.length; i++) {
        final h = _memoryCache[i];
        if (h.contentId != contentId) continue;
        if (latest == -1 || h.updatedAt.isAfter(_memoryCache[latest].updatedAt)) {
          latest = i;
        }
      }
      index = latest;
    }
    if (index == -1) return;
    _memoryCache[index] = _memoryCache[index]
        .copyWith(dismissed: true, updatedAt: DateTime.now());
    state = AsyncData(List.from(_memoryCache));
    final repository = ref.read(playbackHistoryRepositoryProvider);
    await repository.saveHistory(_memoryCache[index]);
  }

  Future<void> deleteContentHistory(String contentId) async {
    final user = ref.read(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';
    final repository = ref.read(playbackHistoryRepositoryProvider);
    final targets =
        _memoryCache.where((h) => h.contentId == contentId).toList();
    for (final h in targets) {
      await repository.deleteHistory(
          h.contentId, h.season, h.episode, profileId);
    }
    _memoryCache.removeWhere((h) => h.contentId == contentId);
    state = AsyncData(List.from(_memoryCache));
  }

  Future<void> deleteProgress(String contentId, int? season, String? episode) async {
    final user = ref.read(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';
    final repository = ref.read(playbackHistoryRepositoryProvider);
    
    await repository.deleteHistory(contentId, season, episode, profileId);
    
    final key = PlaybackHistory.generateKey(contentId, season, episode, profileId: profileId);
    _memoryCache.removeWhere((h) => h.key == key);
    state = AsyncData(List.from(_memoryCache));
  }

  Future<void> clearContentHistory(String contentId) async {
    final user = ref.read(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';
    final repository = ref.read(playbackHistoryRepositoryProvider);
    
    await repository.clearHistory(contentId, profileId);
    
    _memoryCache.removeWhere((h) => h.contentId == contentId && h.profileId == profileId);
    state = AsyncData(List.from(_memoryCache));
  }

  void flush() {
    if (_pendingSave != null) {
      _savePending(notify: true);
    }
    _throttleTimer?.cancel();
  }
}
