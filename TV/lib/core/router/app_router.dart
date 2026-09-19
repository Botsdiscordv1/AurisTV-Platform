import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Root navigator key. Se usa para mostrar el diálogo de confirmación de salida
/// cuando el usuario pulsa "atrás" del sistema y no queda nada que popear (raíz),
/// en lugar de permitir que el sistema cierre la app en TV.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Dispatcher de "atrás" personalizado para TV.
///
/// - Si hay una ruta por encima de la raíz (detalle, reproductor, etc.),
///   delegamos en [GoRouterDelegate.popRoute] para hacer pop normal.
/// - Si estamos en la raíz (cualquier pestaña principal) y no hay nada que
///   popear, NO dejamos que el sistema cierre la app: mostramos un diálogo de
///   confirmación de salida. Así el botón "atrás" del mando nunca cierra la app
///   por accidente.
class AppBackButtonDispatcher extends RootBackButtonDispatcher {
  final GoRouter router;
  AppBackButtonDispatcher(this.router);

  @override
  Future<bool> invokeCallback(Future<bool> defaultValue) async {
    // Si hay algo que popear (sub-pantalla, reproductor o sub-ruta de una
    // pestaña del shell), delegamos en go_router / PopScope y NUNCA cerramos
    // la app desde aquí. Esto cubre también el caso en que una ruta "trague"
    // el back (p.ej. el reproductor cierra un panel antes de popear).
    if (router.canPop()) {
      await router.routerDelegate.popRoute();
      return true;
    }

    // En la raíz (pestaña principal). Si no estamos en Inicio, el "atrás"
    // nos devuelve a Inicio en lugar de cerrar la app.
    final String top = router.routerDelegate.currentConfiguration.uri.path;
    if (top != '/') {
      router.go('/');
      return true;
    }

    // Estamos en Inicio: en lugar de dejar que el sistema cierre la app,
    // pedimos confirmación.
    final BuildContext? context = rootNavigatorKey.currentContext;
    if (context == null) return false;

    final bool? shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _ExitConfirmationDialog(),
    );

    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
    // En cualquier caso, ya gestionamos el "atrás" (sin cierre accidental).
    return true;
  }
}

class _ExitConfirmationDialog extends StatelessWidget {
  const _ExitConfirmationDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '¿Salir de AurisTV?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: const Text(
        'Pulsa atrás o CANCELAR para volver. Elige SALIR para cerrar la aplicación.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCELAR', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'SALIR',
            style: TextStyle(color: Color(0xFFEF7A1E), fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  observers: [routeObserver],
  navigatorKey: rootNavigatorKey,
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
        final sectionId = state.uri.queryParameters['sectionId'];
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
          sectionId: sectionId,
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
        final startPosition = int.tryParse(state.uri.queryParameters['startPosition'] ?? '');
        final category = state.uri.queryParameters['category'];
        final totalEpisodes = int.tryParse(state.uri.queryParameters['totalEpisodes'] ?? '');
        
        // Metadata para "Continuar Viendo"
        final title = state.uri.queryParameters['title'];
        final metadataTitle = state.uri.queryParameters['metadataTitle'];
        final episodeTitle = state.uri.queryParameters['episodeTitle'];
        final posterUrl = state.uri.queryParameters['posterUrl'];
        final bannerUrl = state.uri.queryParameters['bannerUrl'];
        final logoUrl = state.uri.queryParameters['logoUrl'];
        
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
          startPosition: startPosition,
          category: category,
          totalEpisodes: totalEpisodes,
          title: title,
          metadataTitle: metadataTitle,
          episodeTitle: episodeTitle,
          posterUrl: posterUrl,
          bannerUrl: bannerUrl,
          logoUrl: logoUrl,
          video720: video720,
          video1080: video1080,
          skipResume: skipResume,
        );
      },
    ),
  ],
);
