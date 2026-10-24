import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';
import '../../features/intro/presentation/splash_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/explore/presentation/explore_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/content/presentation/content_screen.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/auth/presentation/activate_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/connections_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/avatar/presentation/profile_selection_screen.dart';
import '../../features/avatar/presentation/profile_edit_screen.dart';
import '../../features/avatar/presentation/profile_setup_screen.dart';
import '../../features/auth/presentation/screens/avatar_selector_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/settings/presentation/storage_screen.dart';
import '../../shared/widgets/main_navigation_wrapper.dart';
import '../../shared/widgets/auris_bottom_bar.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Widget _buildContentFromDeepLink(
  BuildContext context,
  GoRouterState state, {
  required bool isMovie,
}) {
  final slug = state.pathParameters['slug'] ?? '';
  String title = '';

  if (slug.isNotEmpty) {
    final unencoded = Uri.decodeComponent(slug).replaceAll('-', ' ').trim();
    title = unencoded.split(' ').map((word) {
      if (word.isEmpty) return '';
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }

  if (title.isEmpty) {
    title = state.uri.queryParameters['title'] ?? 'Contenido';
  }

  final category = isMovie ? 'movie' : (state.uri.queryParameters['category'] ?? 'anime');
  final kind = isMovie ? 'movie' : (state.uri.queryParameters['kind'] ?? 'series');

  return ContentScreen(
    title: title,
    source: state.uri.queryParameters['source'] ?? '',
    url: state.uri.queryParameters['url'] ?? '',
    quality: state.uri.queryParameters['quality'],
    type: kind,
    kind: kind,
    metadataTitle: title,
    banner: state.uri.queryParameters['banner'],
    category: category,
    year: int.tryParse(state.uri.queryParameters['year'] ?? ''),
    season: int.tryParse(state.uri.queryParameters['season'] ?? ''),
    sectionId: state.uri.queryParameters['sectionId'],
  );
}

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
        // Rama 3: Perfil
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Rutas fuera del Shell (Full screen)
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
        GoRoute(
          path: 'storage', // Esto será /settings/storage
          builder: (context, state) => const StorageScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/profile-with-nav',
      builder: (context, state) => const ProfileWithNavScreen(),
    ),
    GoRoute(
      path: '/select-profile',
      builder: (context, state) => const ProfileSelectionScreen(),
    ),
    GoRoute(
      path: '/edit-profile/:profileId',
      builder: (context, state) {
        final profileId = state.pathParameters['profileId']!;
        return ProfileEditScreen(profileId: profileId);
      },
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
      parentNavigatorKey: rootNavigatorKey,
      path: '/activate',
      builder: (context, state) {
        final code = state.uri.queryParameters['code'] ?? '';
        return ActivateScreen(initialCode: code);
      },
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
        final season = int.tryParse(state.uri.queryParameters['season'] ?? '');
        final kind = state.uri.queryParameters['kind'];
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
          season: season,
          kind: kind,
          totalSeasons: totalSeasons,
          sectionId: sectionId,
          result: extraResult,
        );
      },
    ),
    // Series / Anime / Kdramas deep links (WhatsApp / Web)
    GoRoute(
      path: '/series/:token/:slug',
      builder: (context, state) =>
          _buildContentFromDeepLink(context, state, isMovie: false),
    ),
    GoRoute(
      path: '/series/:token',
      builder: (context, state) =>
          _buildContentFromDeepLink(context, state, isMovie: false),
    ),
    // Películas deep links (WhatsApp / Web)
    GoRoute(
      path: '/movie/:token/:slug',
      builder: (context, state) =>
          _buildContentFromDeepLink(context, state, isMovie: true),
    ),
    GoRoute(
      path: '/movie/:token',
      builder: (context, state) =>
          _buildContentFromDeepLink(context, state, isMovie: true),
    ),
    // Alias /detalles
    GoRoute(
      path: '/detalles/:token/:slug',
      builder: (context, state) =>
          _buildContentFromDeepLink(context, state, isMovie: false),
    ),
    GoRoute(
      path: '/detalles/:token',
      builder: (context, state) =>
          _buildContentFromDeepLink(context, state, isMovie: false),
    ),
    GoRoute(
      path: '/player/:contentId',
      pageBuilder: (context, state) {
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
        final kind = state.uri.queryParameters['kind'];
        final year = int.tryParse(state.uri.queryParameters['year'] ?? '');

        final video720 = state.uri.queryParameters['video720'];
        final video1080 = state.uri.queryParameters['video1080'];
        final skipResume = state.uri.queryParameters['skipResume'] == '1';
        // Cast elegido en la ficha: el player lo dispara al resolver el stream.
        final castTargetId = state.uri.queryParameters['castTarget'];
        
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 150),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Fondo negro opaco desde el primer frame de la transición: la
            // pantalla anterior no queda visible ni "congelada" mientras el
            // player monta la SurfaceView nativa.
            return ColoredBox(
              color: Colors.black,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _PlayerRouteShell(
            child: PlayerScreen(
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
              kind: kind,
              year: year,
              castTargetId: castTargetId,
            ),
          ),
        );
      },
    ),
  ],
);

/// Shell mínima de la ruta del player.
///
/// Su primer frame es un fondo negro con spinner: cubre la pantalla anterior
/// de inmediato y evita que quede congelada mientras `PlayerScreen` construye
/// el player nativo. El player real se monta en el siguiente frame.
class _PlayerRouteShell extends StatefulWidget {
  const _PlayerRouteShell({required this.child});

  final Widget child;

  @override
  State<_PlayerRouteShell> createState() => _PlayerRouteShellState();
}

class _PlayerRouteShellState extends State<_PlayerRouteShell> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            color: Color(0xFFEF7A1E),
          ),
        ),
      ),
    );
  }
}

class ProfileWithNavScreen extends ConsumerWidget {
  const ProfileWithNavScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool bottomBarVisible = ref.watch(bottomNavVisibleProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: const ProfileScreen(),
      bottomNavigationBar: bottomBarVisible ? AurisBottomBar(
        currentIndex: 3,
        onTap: (index) {
          final routes = ['/', '/search', '/explore', '/profile'];
          while (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          context.go(routes[index]);
        },
      ) : null,
    );
  }
}
