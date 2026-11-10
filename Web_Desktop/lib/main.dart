import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; 
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/services.dart'; // Para SystemChrome
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:auris_core/auris_core.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/min_width_wrapper.dart';
import 'features/windows/presentation/windows_web_wrapper.dart';
import 'core/utils/url_utils.dart';
import 'features/sports/sports_channel_launcher.dart';
import 'package:auris_web_desktop/features/player/presentation/player_screen.dart';
import 'features/remote_control/presentation/providers/remote_control_provider.dart';
import 'features/remote_control/data/models/remote_device.dart';

Future<void> main() async {
  usePathUrlStrategy(); // Usa URLs limpias sin # para web
  // Senior Web Fix: Hace que context.push() sincronice y actualice la URL en el navegador
  GoRouter.optionURLReflectsImperativeAPIs = true;
  WidgetsFlutterBinding.ensureInitialized();

  // Senior Web/Desktop Tuning: 384MB de caché para fluidez total en navegación de catálogo
  AurisImageConfig.configureForDesktopWeb();

  // Configuración de la interfaz del sistema (Edge-to-Edge)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Iconos blancos
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Inicializa Hive para persistencia (ajustes, historial, etc.)
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('playback_history');
  await Hive.openBox('search_history'); // Senior: Historial de búsquedas recientes
  await Hive.openBox('user_data'); // Senior: Nuevo box para persistir perfiles y conexiones
  await Hive.openBox('favorites'); // Senior: Biblioteca personalizada por perfil
  await Hive.openBox('home_cache'); // Senior: Cache para el inicio instantáneo
  await Hive.openBox('media_slug_cache'); // Senior: Mapeo de Slugs -> Metadata para URLs limpias

  // ============================================
  // VERIFICACIÓN DE SEGURIDAD - Supabase Credentials
  // ============================================
  if (!ApiEndpoints.isSupabaseConfigured) {
    const fallbackKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZyeHV6cXVkZGZlZ3B4amNmZnZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1MjkwNTcsImV4cCI6MjEwMTEwNTA1N30.YiJVKqtNM1D4aZbgBaVSGkMczNIHGpxj0tzDVj95MY8';
    debugPrint('🔴 SECURITY WARNING: SUPABASE_ANON_KEY not set in environment!');
    debugPrint('📝 Using FALLBACK key with known credentials.');
    debugPrint('⚠️  This is a security risk for production deployments.');
    debugPrint('🔧 Set SUPABASE_ANON_KEY environment variable for secure configuration.');
  }

  // Inicializa Supabase
  await Supabase.initialize(
    url: ApiEndpoints.supabaseUrl,
    publishableKey: ApiEndpoints.supabaseAnonKey,
  );

  // Inicializa el motor de video (media_kit) — necesario antes de correr la app
  MediaKit.ensureInitialized();

  runApp(
    ProviderScope(
      overrides: [
        // Senior Fix: Sincronizamos el navigatorKey del Core con el de GoRouter
        navigatorKeyProvider.overrideWithValue(rootNavigatorKey),
        // Reproducción de eventos deportivos (lacancha): en Web/Desktop el
        // embed se abre en el navegador del sistema (mismo comportamiento
        // embed que PlayerScreen en estas plataformas).
        sportsChannelLauncherProvider.overrideWithValue(launchSportsChannel),
        // Ficha del evento deportivo: en Web vive en la ruta limpia
        // `/sports/<id>` (compartible y refrescable). Fuera de GoRouter
        // (escritorio nativo, que usa un MaterialApp sin router) caemos al
        // `MaterialPageRoute` de siempre.
        sportsDetailOpenerProvider.overrideWithValue(
          (context, event, onChannelSelected) {
            if (onChannelSelected == null) {
              try {
                context.push(UrlUtils.buildSportsUri(event), extra: event);
                return;
              } catch (_) {
                // Sin GoRouter por encima → camino antiguo.
              }
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ContentSportScreen(
                  event: event,
                  onChannelSelected: onChannelSelected,
                ),
              ),
            );
          },
        ),
      ],
      child: const AurisApp(),
    ),
  );
}

class AurisApp extends StatelessWidget {
  const AurisApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Si estamos en Windows (y no es Web), usamos el Wrapper de Alto Rendimiento
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return MaterialApp(
        title: 'AurisTV Desktop',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const WindowsWebWrapper(),
      );
    }

    return MaterialApp.router(
      title: 'AurisTV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        
        return NotificationInitializer(
          child: RemoteCommandListener(
            child: MinWidthWrapper(
              minWidth: 360, 
              child: Stack(
                fit: StackFit.expand, // Senior Fix: Garantiza que el contenido principal llene la pantalla
                children: [
                  child,
                  // Senior: Floating MiniPlayer (Global y Persistente)
                  const GlobalMiniPlayerOverlay(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class GlobalMiniPlayerOverlay extends ConsumerStatefulWidget {
  const GlobalMiniPlayerOverlay({super.key});

  @override
  ConsumerState<GlobalMiniPlayerOverlay> createState() => _GlobalMiniPlayerOverlayState();
}

class _GlobalMiniPlayerOverlayState extends ConsumerState<GlobalMiniPlayerOverlay> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyI) {
      if (WidgetsBinding.instance.focusManager.primaryFocus?.context?.widget is EditableText) {
        return false;
      }

      final state = ref.read(activePlayerProvider);
      if (state.uiState == PlayerUIState.mini) {
        _expandMiniPlayer();
        return true;
      }
    }
    return false;
  }

  void _expandMiniPlayer() {
    final state = ref.read(activePlayerProvider);
    if (state.currentItem != null) {
      final player = PlayerScreen(
        contentId: state.currentItem!.id,
        sourceUrl: state.url ?? '',
        source: state.source ?? '',
        episode: state.episode,
        season: state.season,
        title: state.currentItem!.title,
        posterUrl: state.currentItem!.posterUrl,
        bannerUrl: state.currentItem!.bannerUrl,
        logoUrl: state.currentItem!.logoUrl,
        category: state.currentItem!.type.name,
        serverName: state.source != null ? simplifySourceName(state.source!) : null,
        totalEpisodes: state.availableEpisodes.isNotEmpty ? state.availableEpisodes.length : null,
      );
      
      final navContext = rootNavigatorKey.currentContext;
      if (navContext != null) {
        ref.read(activePlayerProvider.notifier).setUiState(PlayerUIState.full);
        UrlUtils.openPlayer(navContext, player);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MiniPlayerBar(
      onExpand: _expandMiniPlayer,
    );
  }
}

class NotificationInitializer extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationInitializer({super.key, required this.child});

  @override
  ConsumerState<NotificationInitializer> createState() => _NotificationInitializerState();
}

class _NotificationInitializerState extends ConsumerState<NotificationInitializer> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    // Senior Fix: Diferimos la inicialización para no bloquear el arranque
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      ref.read(notificationServiceProvider).init();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class RemoteCommandListener extends ConsumerWidget {
  final Widget child;
  const RemoteCommandListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(remoteControlProvider.select((s) => s.lastReceivedCommand), (prev, next) {
      if (next != null && next != prev) {
        if (next['action'] == RemoteAction.openMedia) {
          final p = next['params'] as Map<String, dynamic>?;
          if (p != null) {
            final player = PlayerScreen(
              contentId: p['contentId'] ?? '',
              sourceUrl: p['url'] ?? '',
              source: p['source'] ?? '',
              episode: p['episode'] ?? '1',
              category: p['category'],
              title: p['title'],
              posterUrl: p['posterUrl'],
              bannerUrl: p['bannerUrl'],
            );
            
            UrlUtils.openPlayer(context, player);
          }
        }
      }
    });
    
    return child;
  }
}
