import '../../features/auth/presentation/activate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';
import '../../features/watch/presentation/watch_screen.dart' as web_watch;
import 'package:auris_core/presentation/watch/widgets/clean_embedded_player.dart';
import '../utils/url_utils.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/content/presentation/content_screen.dart';
import '../../features/explore/presentation/explore_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/playlists_screen.dart';
import '../../features/settings/presentation/playlist_channels_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/connections_screen.dart';
import '../../features/avatar/presentation/avatar_selector_screen.dart';
import '../../features/avatar/presentation/profile_selection_screen.dart';
import '../../features/legal/presentation/legal_screen.dart';
import '../../features/intro/presentation/splash_screen.dart';
import '../../shared/widgets/main_navigation_wrapper.dart';

/// Observador global para detectar cambios de ruta y gestionar estados de widgets (ej: trailers)
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

/// Clave global para el Navigator Raíz
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Constructor centralizado de ContentScreen con soporte para tokens encriptados estilo Crunchyroll
/// y fallback a query parameters tradicionales.
Widget _buildContentScreen(BuildContext context, GoRouterState state) {
  final token = state.pathParameters['token'];
  final slug = state.pathParameters['slug'];
  Map<String, dynamic> params = {};

  if (token != null && token.isNotEmpty) {
    final decoded = UrlUtils.decodeShareableToken(token, slug: slug);
    if (decoded != null) {
      params = decoded;
    }
  }

  // Fallback a queryParameters si no vino token o si venía por la ruta legacy /detalles
  if (params.isEmpty) {
    params = Map<String, dynamic>.from(state.uri.queryParameters);
  }

  final title = (params['title'] as String?) ?? 'Contenido';
  final source = (params['source'] as String?) ?? '';
  final url = (params['url'] as String?) ?? '';

  if (url.isEmpty) {
    if (title.isNotEmpty && title != 'Contenido') {
      return SearchScreen(
        initialQuery: title,
        initialCategory: (params['category'] as String?) ?? 'all',
      );
    }
    return const HomeScreen();
  }

  final extraResult = state.extra is SearchResult ? state.extra as SearchResult : null;

  final yearVal = params['year'];
  final int? year = yearVal is int ? yearVal : int.tryParse(yearVal?.toString() ?? '');

  final seasonVal = params['season'];
  final int? season = seasonVal is int ? seasonVal : int.tryParse(seasonVal?.toString() ?? '');

  return ContentScreen(
    title: title,
    source: source,
    url: url,
    category: (params['category'] as String?) ?? 'all',
    year: year,
    season: season,
    kind: params['kind'] as String?,
    quality: params['quality'] as String?,
    type: params['type'] as String?,
    metadataTitle: params['metadataTitle'] as String?,
    sectionId: params['sectionId'] as String?,
    result: extraResult,
    from: params['from'] as String?,
  );
}

/// Página del reproductor: fondo negro opaco desde el primer frame y fade
/// corto, para que la pantalla anterior no se vea (ni parpadee) mientras el
/// player monta. Mismo trato que la ruta de player en Móvil.
CustomTransitionPage<void> _playerPage(
  GoRouterState state,
  PlayerScreen player,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return ColoredBox(
        color: Colors.black,
        child: FadeTransition(opacity: animation, child: child),
      );
    },
    child: player,
  );
}

/// Reconstruye un evento deportivo desde los query params de un enlace
/// copiado de la barra (`/sports/<id>?title=…&poster=…`).
ContentSports _eventFromQuery(String id, Map<String, String> query) {
  final teams = (query['teams'] ?? '')
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  return ContentSports(
    id: id,
    title: query['title'] ?? 'Evento deportivo',
    sport: query['sport'],
    sportLabel: query['sportLabel'],
    league: query['league'],
    teams: teams,
    posterUrl: query['poster'] ?? '',
    bannerUrl: query['banner'] ?? '',
    synopsis: query['synopsis'],
    startsAt: query['startsAt'],
    isLive: query['live'] == '1',
    status: query['status'],
    source: 'ppv',
  );
}

/// Ficha del evento para `/sports/:id` cuando llegamos "en frío" (F5 o enlace
/// compartido sin `extra`): resuelve el evento contra el catálogo de eventos
/// (backend de deportes) y, si no está, contra el detalle de lacancha.
class _SportsEventResolver extends ConsumerStatefulWidget {
  final String id;

  const _SportsEventResolver({required this.id});

  @override
  ConsumerState<_SportsEventResolver> createState() =>
      _SportsEventResolverState();
}

class _SportsEventResolverState extends ConsumerState<_SportsEventResolver> {
  ContentSports? _event;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ContentSports? found;

    // 1. Catálogo del backend (eventos en vivo y próximos).
    try {
      final repo = ref.read(aurisRepositoryProvider);
      final lists = await Future.wait([
        repo.getSportsEvents(live: true),
        repo.getSportsEvents(live: false),
      ]);
      outer:
      for (final list in lists) {
        for (final event in list) {
          if (event.id == widget.id) {
            found = event;
            break outer;
          }
        }
      }
    } catch (_) {
      // El repositorio ya traga sus errores; aquí solo evitamos tumbar la ruta.
    }

    // 2. Fallback lacancha: el detalle aporta los servidores reales.
    if (found == null && mounted) {
      try {
        final detail = await ref
            .read(lacanchaEventsSourceProvider)
            .fetchEventDetail(widget.id);
        if (detail != null && detail.title.isNotEmpty) found = detail;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _event = found;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    if (event != null) return ContentSportScreen(event: event);

    if (!_done) {
      return const Scaffold(
        backgroundColor: Color(0xFF121216),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFEF7A1E)),
        ),
      );
    }

    // Sin datos: la propia pantalla muestra "No hay canales disponibles".
    return ContentSportScreen(
      event: ContentSports(
        id: widget.id,
        title: 'Evento deportivo',
        posterUrl: '',
        bannerUrl: '',
        source: 'ppv',
      ),
    );
  }
}

/// Constructor de `/sports` y `/sports/:id`.
///
/// 1. `extra` (tap en la app): el evento completo, sin fetch.
/// 2. Query params (enlace copiado de la barra): se reconstruye y la propia
///    pantalla completa el detalle por su fetch interno.
/// 3. Solo el id (F5 / enlace limpio): se resuelve contra el catálogo.
Widget _buildSportsScreen(BuildContext context, GoRouterState state) {
  final extra = state.extra;
  if (extra is ContentSports) {
    return ContentSportScreen(event: extra);
  }

  final query = state.uri.queryParameters;
  final id = state.pathParameters['id'] ?? query['id'] ?? '';

  if ((query['title'] ?? '').isNotEmpty) {
    return ContentSportScreen(event: _eventFromQuery(id, query));
  }

  return _SportsEventResolver(id: id);
}

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/inicio',
  observers: [routeObserver],
  routes: [
    // Redirección por defecto
    GoRoute(
      path: '/',
      redirect: (context, state) => '/inicio',
    ),

    // Intro / Splash
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    
    // Rutas con Shell persistente (Navegación principal)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainNavigationWrapper(navigationShell: navigationShell);
      },
      branches: [
        // Rama 0: Inicio y sus Secciones (URLs de primer nivel)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inicio',
              builder: (context, state) => const HomeScreen(categoryPath: 'inicio'),
            ),
          ],
        ),
        // Rama 1: Catálogo (Búsqueda)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/catalogo',
              builder: (context, state) {
                final query = state.uri.queryParameters['q'] ?? '';
                final category = state.uri.queryParameters['cat'] ?? 'all';
                return SearchScreen(initialQuery: query, initialCategory: category);
              },
            ),
          ],
        ),
        // Rama 2: Explorar
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explore',
              builder: (context, state) => const ExploreScreen(),
            ),
          ],
        ),
        // Rama 3: Ajustes / Perfil
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),

    // Anime (/anime/:token/:slug)
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/anime/:token/:slug',
      builder: _buildContentScreen,
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/anime/:token',
      builder: _buildContentScreen,
    ),

    // Series y Kdramas (/serie/:token/:slug y /series/ por compatibilidad)
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/serie/:token/:slug',
      builder: _buildContentScreen,
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/serie/:token',
      builder: _buildContentScreen,
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/series/:token/:slug',
      builder: _buildContentScreen,
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/series/:token',
      builder: _buildContentScreen,
    ),

    // Películas (movie, movie_anime, movie_kdrama: /movie/:token/:slug)
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/movie/:token/:slug',
      builder: _buildContentScreen,
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/movie/:token',
      builder: _buildContentScreen,
    ),

    // Rutas legacy /detalles (soporta con token y con query params para 100% retrocompatibilidad)
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/detalles/:token/:slug',
      builder: _buildContentScreen,
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/detalles/:token',
      builder: _buildContentScreen,
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/detalles',
      builder: _buildContentScreen,
    ),

    // Reproductor (/watch/:token/:slug) — ahora con token y slug para URLs compartibles.
    // El token identifica el contenido, el slug es para SEO/visibilidad.
    // /reproductor sigue como alias legacy para retrocompatibilidad.
    // 
    // SEGURIDAD: Los tokens ahora usan firma HMAC-SHA256 con expiración de 24h.
    // Los tokens antiguos (sin firma) aún son compatibles pero se deben migrar.
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/watch/:token/:slug',
      name: 'watch',
      builder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        final slug = state.pathParameters['slug'] ?? '';
        final params = state.uri.queryParameters;
        final extra = state.extra;

        // ============================================
        // VERIFICACIÓN DE TOKEN (HMAC o Legacy)
        // ============================================
        // Primero intentar verificar con HMAC (token nuevo)
        final verifiedPayload = SignedTokenManager.verifyToken(token);
        Map<String, dynamic>? payload = verifiedPayload;
        
        // Si no es token firmado, intentar con el sistema legacy
        if (payload == null && token.isNotEmpty) {
          final legacyPayload = UrlUtils.decodeShareableToken(token, slug: slug.isNotEmpty ? slug : null);
          if (legacyPayload != null) {
            payload = legacyPayload;
            // Advertencia de que se usa el sistema legacy
            debugPrint('[SECURITY] Token de watch usando formato legacy (no HMAC)');
          }
        }

        final PlayerScreen player = (extra is PlayerScreen)
            ? extra
            : PlayerScreen(
                contentId: params['contentId'] ?? token,
                sourceUrl: params['url'] ?? payload?['url'] ?? '',
                source: params['source'] ?? payload?['source'] ?? '',
                episode: params['episode'] ?? (payload?['episode']?.toString() ?? '1'),
                season: int.tryParse(params['season'] ?? payload?['season']?.toString() ?? ''),
                serverName: params['serverName'],
                category: params['category'] ?? payload?['category'],
                totalEpisodes: int.tryParse(params['totalEpisodes'] ?? ''),
                title: params['title'] ?? (slug.isNotEmpty ? slug.replaceAll('-', ' ') : payload?['title']),
                metadataTitle: params['title'] ?? slug.replaceAll('-', ' '),
                episodeTitle: params['episodeTitle'] ?? payload?['episodeTitle'],
                posterUrl: params['posterUrl'] ?? payload?['posterUrl'],
                bannerUrl: params['bannerUrl'] ?? payload?['bannerUrl'],
                logoUrl: params['logoUrl'] ?? payload?['logoUrl'],
                year: int.tryParse(params['year'] ?? payload?['year']?.toString() ?? ''),
                certification: params['certification'] ?? payload?['certification'],
                skipResume: params['skipResume'] == '1' || payload?['skipResume'] == true,
                isLive: params['isLive'] == '1' || payload?['isLive'] == true,
              );

        // Si el token es válido pero faltan datos críticos, rechazar
        if (player.sourceUrl.isEmpty || player.source.isEmpty) {
          debugPrint('[SECURITY] WatchScreen: URL o source vacíos, token inválido');
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Enlace inválido o expirado',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }

        return web_watch.WatchScreen(
          contentId: player.contentId,
          sourceUrl: player.sourceUrl,
          source: player.source,
          episode: player.episode,
          season: player.season,
          serverName: player.serverName,
          category: player.category,
          title: player.title,
          metadataTitle: player.title,
          episodeTitle: player.episodeTitle,
          posterUrl: player.posterUrl,
          bannerUrl: player.bannerUrl,
          logoUrl: player.logoUrl,
          year: player.year,
          certification: player.certification,
          totalEpisodes: player.totalEpisodes,
          skipResume: player.skipResume,
          isLive: player.isLive,
          onEpisodeSelected: (ep) {
            final uri = UrlUtils.buildPlayerUri(
              title: player.title ?? '',
              contentId: player.contentId,
              episode: ep.number.toString(),
              source: player.source,
              url: ep.url.isNotEmpty ? ep.url : player.sourceUrl,
              season: player.season,
              serverName: player.serverName,
              category: player.category,
              totalEpisodes: player.totalEpisodes,
              posterUrl: ep.thumbnail ?? player.posterUrl,
              bannerUrl: player.bannerUrl,
            );
            context.pushReplacement(uri);
          },
        );
      },
    ),
    // /watch sin token/slug (fallback legacy)
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/watch',
      builder: (context, state) {
        final params = state.uri.queryParameters;
        final extra = state.extra;

        final PlayerScreen player = (extra is PlayerScreen)
            ? extra
            : PlayerScreen(
                contentId: params['contentId'] ?? '',
                sourceUrl: params['url'] ?? '',
                source: params['source'] ?? '',
                episode: params['episode'] ?? '1',
                season: int.tryParse(params['season'] ?? ''),
                serverName: params['serverName'],
                category: params['category'],
                totalEpisodes: int.tryParse(params['totalEpisodes'] ?? ''),
                title: params['title'],
                metadataTitle: params['title'],
                episodeTitle: params['episodeTitle'],
                posterUrl: params['posterUrl'],
                bannerUrl: params['bannerUrl'],
                logoUrl: params['logoUrl'],
                year: int.tryParse(params['year'] ?? ''),
                certification: params['certification'],
                skipResume: params['skipResume'] == '1',
                isLive: params['isLive'] == '1',
              );

        return web_watch.WatchScreen(
          contentId: player.contentId,
          sourceUrl: player.sourceUrl,
          source: player.source,
          episode: player.episode,
          season: player.season,
          serverName: player.serverName,
          category: player.category,
          title: player.title,
          metadataTitle: player.title,
          episodeTitle: player.episodeTitle,
          posterUrl: player.posterUrl,
          bannerUrl: player.bannerUrl,
          logoUrl: player.logoUrl,
          year: player.year,
          certification: player.certification,
          totalEpisodes: player.totalEpisodes,
          skipResume: player.skipResume,
          isLive: player.isLive,
          onEpisodeSelected: (ep) {
            final uri = UrlUtils.buildPlayerUri(
              title: player.title ?? '',
              contentId: player.contentId,
              episode: ep.number.toString(),
              source: player.source,
              url: ep.url.isNotEmpty ? ep.url : player.sourceUrl,
              season: player.season,
              serverName: player.serverName,
              category: player.category,
              totalEpisodes: player.totalEpisodes,
              posterUrl: ep.thumbnail ?? player.posterUrl,
              bannerUrl: player.bannerUrl,
            );
            context.pushReplacement(uri);
          },
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/reproductor',
      redirect: (context, state) => Uri(
        path: '/watch',
        queryParameters: state.uri.queryParameters,
      ).toString(),
    ),

    // Deportes: ficha del evento / canal en vivo (/sports/:id)
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/sports/:id',
      builder: _buildSportsScreen,
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/sports',
      redirect: (context, state) {
        final query = state.uri.queryParameters;
        final hasId = (state.pathParameters['id'] ?? query['id'] ?? '').isNotEmpty;
        final hasExtra = state.extra is ContentSports;
        if (!hasId && !hasExtra && (query['title'] ?? '').isEmpty) {
          return '/inicio';
        }
        return null;
      },
      builder: _buildSportsScreen,
    ),

    // Rutas Globales
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/settings/avatar',
      builder: (context, state) => const AvatarSelectorScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/settings/library',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/settings/listas',
      builder: (context, state) => const PlaylistsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/settings/listas/:playlistId',
      builder: (context, state) => PlaylistChannelsScreen(
        playlistId: state.pathParameters['playlistId']!,
      ),
    ),
        GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/activate',
      builder: (context, state) {
        final code = state.uri.queryParameters['code'] ?? '';
        return ActivateScreen(initialCode: code);
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/select-profile',
      builder: (context, state) => const ProfileSelectionScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/connections',
      builder: (context, state) => const ConnectionsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/horario',
      builder: (context, state) => const ScheduleScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/terms',
      builder: (context, state) => const LegalScreen(isTerms: true),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/privacy',
      builder: (context, state) => const LegalScreen(isTerms: false),
    ),
  ],
);
