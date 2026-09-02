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

/// Claves globales para controlar el Navigator de forma precisa
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

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
        // Rama 1: Catálogo (Búsqueda)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/catalogo',
              builder: (context, state) {
                final query = state.uri.queryParameters['q'] ?? '';
                final category = state.uri.queryParameters['cat'] ?? 'all';
                return SearchScreen(
                  initialQuery: query,
                  initialCategory: category,
                );
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
      parentNavigatorKey: rootNavigatorKey,
      path: '/select-profile',
      builder: (context, state) => const ProfileSelectionScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/login',
      builder: (context, state) => const LoginScreen(),
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
      path: '/media/:slug/:token',
      builder: (context, state) {
        final slug = state.pathParameters['slug']!;
        final token = state.pathParameters['token']!;
        final data = UrlUtils.decodeShareableToken(token, slug);
        
        if (data == null) return const HomeScreen(); 

        final extraResult = state.extra is SearchResult ? state.extra as SearchResult : null;

        return ContentScreen(
          title: data['title'],
          source: data['source'],
          url: data['url'],
          category: data['category'] ?? 'all',
          year: data['year'],
          result: extraResult,
        );
      },
    ),
  ],
);
