import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';
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

/// Clave global para el Navigator Raíz (Senior Fix: Necesario para pre-fetching)
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  observers: [routeObserver],
  routes: [
    // Intro / Splash
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    // Rutas con Navegación Inferior Persistente (Shell)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainNavigationWrapper(navigationShell: navigationShell);
      },
      branches: [
        // Rama 0: Inicio
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        // Rama 1: Búsqueda
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
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
        // Rama 3: Ajustes (Perfil)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'library', // Esto será /settings/library
                  builder: (context, state) => const LibraryScreen(),
                ),
                GoRoute(
                  path: 'avatar', // Esto será /settings/avatar
                  builder: (context, state) => const AvatarSelectorScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // Rutas fuera del Shell (Full screen)
    GoRoute(
      path: '/select-profile',
      builder: (context, state) => const ProfileSelectionScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/connections',
      builder: (context, state) => const ConnectionsScreen(),
    ),
    GoRoute(
      path: '/schedule',
      builder: (context, state) => const ScheduleScreen(),
    ),
    GoRoute(
      path: '/content/:title',
      builder: (context, state) {
        final title = state.pathParameters['title']!;
        final source = state.uri.queryParameters['source'] ?? '';
        final url = state.uri.queryParameters['url'] ?? '';
        final quality = state.uri.queryParameters['quality'];
        final type = state.uri.queryParameters['type'];
        final metadataTitle = state.uri.queryParameters['metadataTitle'];
        final banner = state.uri.queryParameters['banner'];
        final category = state.uri.queryParameters['category'] ?? 'all';
        final year = int.tryParse(state.uri.queryParameters['year'] ?? '');
        final totalSeasons =
            int.tryParse(state.uri.queryParameters['totalSeasons'] ?? '');
        final extraResult =
            state.extra is SearchResult ? state.extra as SearchResult : null;
        return ContentScreen(
          title: title,
          source: source,
          url: url,
          quality: quality,
          type: type,
          metadataTitle: metadataTitle,
          banner: banner,
          category: category,
          year: year,
          totalSeasons: totalSeasons,
          result: extraResult,
        );
      },
    ),
    GoRoute(
      path: '/player/:contentId',
      builder: (context, state) {
        final contentId = state.pathParameters['contentId']!;
        final sourceUrl = state.uri.queryParameters['url'] ?? '';
        final source = state.uri.queryParameters['source'] ?? '';
        final episode = state.uri.queryParameters['episode'];
        final seasonStr = state.uri.queryParameters['season'];
        final season = (seasonStr != null && seasonStr.isNotEmpty) ? int.tryParse(seasonStr) : null;
        final serverName = state.uri.queryParameters['serverName'];
        final language = state.uri.queryParameters['language'];
        final startPosition = int.tryParse(state.uri.queryParameters['startPosition'] ?? '');
        final category = state.uri.queryParameters['category'];
        final totalEpisodes = int.tryParse(state.uri.queryParameters['totalEpisodes'] ?? '');
        
        // Metadata para "Continuar Viendo"
        final title = state.uri.queryParameters['title'];
        final metadataTitle = state.uri.queryParameters['metadataTitle'];
        final episodeTitle = state.uri.queryParameters['episodeTitle'];
        final posterUrl = state.uri.queryParameters['posterUrl'];
        final bannerUrl = state.uri.queryParameters['bannerUrl'];
        
        final video720 = state.uri.queryParameters['video720'];
        final video1080 = state.uri.queryParameters['video1080'];
        final skipResume = state.uri.queryParameters['skipResume'] == '1';
        
        return PlayerScreen(
          contentId: contentId,
          sourceUrl: sourceUrl,
          source: source,
          episode: episode,
          season: season,
          serverName: serverName,
          language: language,
          startPosition: startPosition,
          category: category,
          totalEpisodes: totalEpisodes,
          title: title,
          metadataTitle: metadataTitle,
          episodeTitle: episodeTitle,
          posterUrl: posterUrl,
          bannerUrl: bannerUrl,
          video720: video720,
          video1080: video1080,
          skipResume: skipResume,
        );
      },
    ),
  ],
);
