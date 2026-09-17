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
import '../../features/avatar/presentation/profile_setup_screen.dart';
import '../../features/intro/presentation/splash_screen.dart';
import '../../shared/widgets/main_navigation_wrapper.dart';

/// Observador global para detectar cambios de ruta y gestionar estados de widgets (ej: trailers)
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

/// Clave global para el Navigator Raíz
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

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
      ],
    ),

    // Detalles (Media)
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/detalles',
      builder: (context, state) {
        final params = state.uri.queryParameters;
        
        final title = params['title'] ?? 'Contenido';
        final source = params['source'] ?? '';
        final url = params['url'] ?? '';

        if (url.isEmpty) return const HomeScreen(); 

        final extraResult = state.extra is SearchResult ? state.extra as SearchResult : null;

        return ContentScreen(
          title: title,
          source: source,
          url: url,
          category: params['category'] ?? 'all',
          year: int.tryParse(params['year'] ?? ''),
          quality: params['quality'],
          type: params['type'],
          sectionId: params['sectionId'],
          result: extraResult,
          from: params['from'],
        );
      },
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
          language: params['language'],
          category: params['category'],
          totalEpisodes: int.tryParse(params['totalEpisodes'] ?? ''),
          title: params['title'],
          posterUrl: params['posterUrl'],
          bannerUrl: params['bannerUrl'],
        );
      },
    ),

    // Rutas Globales
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
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
  ],
);
