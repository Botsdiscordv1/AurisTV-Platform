import 'dart:async';

import 'package:auris_core/auris_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';

/// Sincroniza el "Continuar Viendo" de la app con el launcher de
/// Android/Google TV (Watch Next) y abre el contenido cuando el usuario pulsa
/// una tarjeta del launcher.
///
/// El lado nativo vive en `WatchNextHelper.kt` + el MethodChannel
/// `auristv/watchnext`. Aquí solo se envía el historial ya transformado y se
/// escucha el deep link `auristv://watchnext?route=...`.
class WatchNextInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const WatchNextInitializer({super.key, required this.child});

  @override
  ConsumerState<WatchNextInitializer> createState() =>
      _WatchNextInitializerState();
}

class _WatchNextInitializerState extends ConsumerState<WatchNextInitializer>
    with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('auristv/watchnext');
  static const int _maxEntries = 10;
  static const Duration _syncDebounce = Duration(milliseconds: 800);

  ProviderSubscription<AsyncValue<List<PlaybackHistory>>>? _subscription;
  Timer? _debounce;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;

    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_onNativeCall);
    _subscription = ref.listenManual<AsyncValue<List<PlaybackHistory>>>(
      continueWatchingProvider,
      (previous, next) {
        final items = next.valueOrNull;
        if (items != null) _scheduleSync(items);
      },
      fireImmediately: true,
    );
    unawaited(_loadInitialRoute());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.close();
    _debounce?.cancel();
    if (!kIsWeb) _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a primer plano puede haber una ruta pendiente (p. ej. la
    // actividad se recreó y el canal no llegó a entregarla por onNewIntent).
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadInitialRoute());
    }
  }

  Future<void> _loadInitialRoute() async {
    try {
      final route = await _channel.invokeMethod<String>('getInitialRoute');
      if (route != null && route.isNotEmpty) {
        unawaited(_openRoute(route));
      }
    } catch (e) {
      debugPrint('[WatchNext] getInitialRoute: $e');
    }
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'onDeepLink') {
      final route = call.arguments as String?;
      if (route != null && route.isNotEmpty) {
        unawaited(_openRoute(route));
      }
    }
    return null;
  }

  /// Espera a que termine el splash en arranque en frío y navega al contenido.
  ///
  /// Siempre navega con `push` (nunca `go`) para que el botón Atrás vuelva al
  /// Home de la app. Si el flujo de arranque/login pisa la ruta justo después
  /// de recibir el deep link, se re-apila el contenido sobre el Home, pero con
  /// un número acotado de intentos: nunca abre la pantalla varias veces seguidas.
  Future<void> _openRoute(String route) async {
    if (!route.startsWith('/')) return;
    if (_opening) return;

    // OJO: `currentConfiguration.uri` IGNORA las rutas imperativas (las
    // empujadas con `push`), así que tras abrir el content seguiría devolviendo
    // '/'. El `matchedLocation` del último match sí refleja la ruta empujada.
    String currentPath() {
      final config = appRouter.routerDelegate.currentConfiguration;
      final matches = config.matches;
      if (matches.isNotEmpty) return matches.last.matchedLocation;
      return config.uri.path;
    }
    final String target = Uri.parse(route).path;

    // Ya estamos mostrando ese contenido (o llegó una entrega repetida del deep
    // link): no duplicar la pantalla.
    if (currentPath() == target) return;

    _opening = true;
    try {
      const Set<String> bootRoutes = {
        '/splash',
        '/',
        '/login',
        '/select-profile',
        '/add-profile',
        '/profile-setup',
      };

      // 1) Arranque en frío: esperar a que el splash termine.
      final DateTime splashDeadline =
          DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(splashDeadline) &&
          currentPath() == '/splash') {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      // 2) Un único push sobre el Home.
      appRouter.push(route);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // 3) Re-apilar SOLO si el arranque/login pisó la ruta con una ruta de
      //    arranque (máx. 4 intentos), no uno por ciclo de 300 ms.
      for (int attempt = 0; attempt < 4; attempt++) {
        if (!mounted) return;
        final String current = currentPath();
        if (current == target) return; // contenido visible: listo
        if (!bootRoutes.contains(current)) return; // el usuario navegó: no interferir
        appRouter.push(route);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    } finally {
      _opening = false;
    }
  }

  void _scheduleSync(List<PlaybackHistory> items) {
    _debounce?.cancel();
    final List<Map<String, Object?>> entries = _buildEntries(items);
    _debounce = Timer(_syncDebounce, () => _sync(entries));
  }

  Future<void> _sync(List<Map<String, Object?>> entries) async {
    try {
      await _channel.invokeMethod<void>('sync', entries);
    } on MissingPluginException {
      // Plataforma sin implementación nativa (p. ej. iOS/desktop).
    } catch (e) {
      debugPrint('[WatchNext] sync: $e');
    }
  }

  List<Map<String, Object?>> _buildEntries(List<PlaybackHistory> items) {
    return items.take(_maxEntries).map((h) {
      final bool isEpisode =
          !libraryIsMovieish(h) && (h.episode?.isNotEmpty ?? false);
      final String subtitle = continueCardSubtitle(h).line1;
      // El launcher de TV pinta la tarjeta con `poster_art_uri`: para que se vea
      // como backdrop horizontal usamos banner/backdrop (fallback al póster).
      final String backdrop =
          (h.bannerUrl ?? '').isNotEmpty ? h.bannerUrl! : (h.posterUrl ?? '');
      return <String, Object?>{
        'key': PlaybackHistory.generateKey(h.contentId, h.season, h.episode),
        'contentId': h.contentId,
        'title': _resolveTitle(h),
        'description': subtitle,
        'posterUrl': ApiEndpoints.proxyImage(backdrop, width: 1280),
        'thumbnailUrl': ApiEndpoints.proxyImage(backdrop, width: 1280),
        'logoUrl': h.logoUrl != null
            ? ApiEndpoints.proxyImage(h.logoUrl)
            : '',
        'durationMs': h.durationInMilliseconds,
        'positionMs': h.positionInMilliseconds,
        'lastEngagement': h.updatedAt.millisecondsSinceEpoch,
        'isEpisode': isEpisode,
        'season': h.season,
        'episodeNumber': isEpisode ? _episodeNumber(h.episode) : null,
        'episodeTitle': h.episodeTitle,
        'route': _contentRoute(h),
      };
    }).toList();
  }

  /// Título a mostrar en el launcher. `libraryDisplayTitle` cae a "Contenido"
  /// cuando la entrada no tiene `title`; en ese caso probamos `metadataTitle`,
  /// el título del episodio y, por último, el id.
  String _resolveTitle(PlaybackHistory h) {
    final String display = libraryDisplayTitle(h).trim();
    if (display.isNotEmpty && display != 'Contenido') return display;
    final String meta = (h.metadataTitle ?? '').trim();
    if (meta.isNotEmpty) return meta;
    final String episode = (h.episodeTitle ?? '').trim();
    if (episode.isNotEmpty) return episode;
    return h.title?.trim().isNotEmpty == true ? h.title!.trim() : h.contentId;
  }

  /// Construye la ruta interna de detalle (misma que usa la tarjeta de
  /// Continuar Viendo) para que el launcher pueda abrir el contenido.
  String _contentRoute(PlaybackHistory h) {
    final detailParams = h.toUnifiedDetailParams();
    return '/content/${Uri.encodeComponent(detailParams.title)}'
        '?source=${Uri.encodeComponent(detailParams.source)}'
        '&category=${Uri.encodeComponent(detailParams.category)}'
        '&url=${Uri.encodeComponent(detailParams.url ?? h.contentId)}'
        '${detailParams.season != null ? '&season=${detailParams.season}' : ''}'
        '${detailParams.sectionId != null ? '&sectionId=${Uri.encodeComponent(detailParams.sectionId!)}' : ''}'
        '&year=${detailParams.year ?? ''}'
        '${detailParams.kind != null && detailParams.kind!.isNotEmpty ? '&kind=${Uri.encodeComponent(detailParams.kind!)}' : ''}'
        '${detailParams.type != null && detailParams.type!.isNotEmpty ? '&type=${Uri.encodeComponent(detailParams.type!)}' : ''}'
        '${detailParams.metadataTitle != null && detailParams.metadataTitle!.isNotEmpty ? '&metadataTitle=${Uri.encodeComponent(detailParams.metadataTitle!)}' : ''}';
  }

  int? _episodeNumber(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final direct = int.tryParse(raw.trim());
    if (direct != null) return direct;
    final matches = RegExp(r'\d+').allMatches(raw).toList();
    if (matches.isEmpty) return null;
    return int.tryParse(matches.last.group(0)!);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
