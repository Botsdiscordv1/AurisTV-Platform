import '../../features/auth/presentation/activate_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';
import '../utils/url_utils.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/content/presentation/content_screen.dart';
import '../../features/explore/presentation/explore_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
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

  if (url.isEmpty) return const HomeScreen();

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

    // Series / Anime / Kdramas (Estilo Crunchyroll: /series/:token/:slug)
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

    // Reproductor
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/reproductor',
      builder: (context, state) {
        final params = state.uri.queryParameters;
        return PlayerScreen(
          contentId: params['contentId'] ?? '',
          sourceUrl: params['url'] ?? '',
          source: params['source'] ?? '',
          episode: params['episode'] ?? '1',
          season: int.tryParse(params['season'] ?? ''),
          serverName: params['serverName'],
          category: params['category'],
          totalEpisodes: int.tryParse(params['totalEpisodes'] ?? ''),
          title: params['title'],
          posterUrl: params['posterUrl'],
          bannerUrl: params['bannerUrl'],
          logoUrl: params['logoUrl'],
        );
      },
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
