import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:audio_service/audio_service.dart';
import 'features/player/data/audio_handler.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:auris_core/auris_core.dart';
import 'package:path_provider/path_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/pip_service.dart';
import 'features/sports/sports_channel_launcher.dart';
import 'features/player/presentation/mobile_video_surface.dart';
import 'shared/widgets/min_width_wrapper.dart';
// import 'features/windows/presentation/windows_web_wrapper.dart';
import 'features/remote_control/presentation/providers/remote_control_provider.dart';
import 'features/remote_control/data/models/remote_device.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Render nativo solo en Móvil Android. TV/Web no tocan esta bandera y
  // conservan la textura de media_kit (mini player, PiP, cast y subtítulos).
  VideoSurfaceConfig.nativeAndroidSurface =
      const bool.fromEnvironment('NATIVE_VIDEO_SURFACE', defaultValue: false);
  debugPrint(
      '[VideoSurface] native=${VideoSurfaceConfig.nativeAndroidSurface}');

  // HCPP (Flutter 3.44+, Android 14+ / Vulkan) compone la PlatformView a nivel
  // del sistema. Sin él, Hybrid Composition puede dejar un snapshot congelado
  // de la UI encima del SurfaceView hasta que cambie el layout.
  if (VideoSurfaceConfig.nativeAndroidSurface && !kIsWeb) {
    try {
      VideoSurfaceConfig.useHybridAndroidView =
          await HybridAndroidViewController.checkIfSupported();
    } catch (e) {
      debugPrint('[VideoSurface] HCPP check failed: $e');
    }
    debugPrint(
        '[VideoSurface] hcpp=${VideoSurfaceConfig.useHybridAndroidView}');
  }

  // Senior Mobile Tuning: 160MB de caché para móviles (evita desalojo al navegar entre pantallas)
  AurisImageConfig.configureForMobile();

  // Configuración de la interfaz del sistema (Edge-to-Edge)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
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

  // Inicializa Supabase
  await Supabase.initialize(
    url: ApiEndpoints.supabaseUrl,
    publishableKey: ApiEndpoints.supabaseAnonKey,
  );

  // Senior Fix: Asegurar que el directorio de soporte de la app exista antes de media_kit (evita PathNotFoundException en fresh installs)
  try {
    final appSupportDir = await getApplicationSupportDirectory();
    if (!appSupportDir.existsSync()) {
      appSupportDir.createSync(recursive: true);
    }
  } catch (e) {
    debugPrint('[MediaKit] Error creating app support dir: $e');
  }

  // Inicializa el motor de video (media_kit) — necesario antes de correr la app
  MediaKit.ensureInitialized();
  PipService.initialize();

  // Senior Fix: El isolate de segundo plano de AudioService no tiene Activity/vistas.
  // Llamar AudioService.init() desde ese isolate con FlutterFragmentActivity causa
  // PlatformException → pantalla negra. Verificamos ANTES de inicializar.
  if (PlatformDispatcher.instance.views.isEmpty) {
    // Estamos en el isolate de background de audio_service: solo inicializamos
    // el handler sin UI y retornamos inmediatamente.
    audioHandler = await AudioService.init(
      builder: () => AurisAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.auristv.oficial.audio',
        androidNotificationChannelName: 'Reproducción',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
        androidStopForegroundOnPause: true,
      ),
    );
    return;
  }

  // Inicialización normal de AudioService en el isolate principal (con UI/Activity).
  // Senior Fix: Wrapped en try-catch — si AudioServicePlugin.setActivity() en
  // MainActivity.kt falla por incompatibilidad con FlutterFragmentActivity, la app
  // sigue arrancando en modo degradado (sin controles en lock screen / shade).
  try {
    audioHandler = await AudioService.init(
      builder: () => AurisAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.auristv.oficial.audio',
        androidNotificationChannelName: 'Reproducción',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    debugPrint('[AudioService] init falló (FlutterFragmentActivity incompatibility): $e');
    // Fallback: handler sin notificaciones del sistema. La reproducción funciona normal.
    audioHandler = AurisAudioHandler();
  }

  runApp(
    ProviderScope(
      overrides: [
        // Senior Fix: Sincronizamos el navigatorKey del Core con el de GoRouter
        navigatorKeyProvider.overrideWithValue(rootNavigatorKey),
        // Reproducción de eventos deportivos (lacancha): resuelve el m3u8 con
        // un WebView oculto y lo abre en media_kit con Referer del embed.
        sportsChannelLauncherProvider.overrideWithValue(launchSportsChannel),
      ],
      child: const AurisApp(),
    ),
  );
}

class AurisApp extends StatelessWidget {
  const AurisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AurisTV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        
        return ValueListenableBuilder<bool>(
          valueListenable: PipService.isPipMode,
          builder: (context, inPip, _) {
            if (inPip) {
              return const PipVideoContainer();
            }

            return NotificationInitializer(
              child: RemoteCommandListener(
                child: DeepLinkHandler(
                  child: MinWidthWrapper(
                    minWidth: 360, // Sincronizado con Web para evitar inconsistencias en tablets
                    child: Stack(
                      fit: StackFit.expand, // Senior Fix: Garantiza que el contenido principal llene la pantalla
                      children: [
                        child,
                        // Senior: Floating MiniPlayer (Global y Persistente)
                        const GlobalMiniPlayerOverlay(),
                        // Barra global de descarga de actualización (background)
                        const UpdateDownloadBanner(flavor: 'mobile'),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class PipVideoContainer extends ConsumerWidget {
  const PipVideoContainer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activePlayerProvider);
    final controller = state.controller;
    final player = state.player;
    final posterUrl = state.currentItem?.posterUrl;
    final bool useNative = VideoSurfaceConfig.nativeAndroidSurface &&
        player != null &&
        controller == null;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: useNative
              ? ColoredBox(
                  color: Colors.black,
                  child: FittedMobileVideoSurface(
                    player: player!,
                    onSurface: (viewId, wid, width, height) {
                      unawaited(NativeVideoSurfaceBinder.attach(
                        player: player!,
                        viewId: viewId,
                        wid: wid,
                        width: width,
                        height: height,
                      ));
                    },
                    onSurfaceDestroyed: (viewId, wid) {
                      unawaited(NativeVideoSurfaceBinder.detach(
                        player,
                        viewId: viewId,
                        wid: wid,
                      ));
                    },
                  ),
                )
              : controller != null
                  ? Video(
                      key: state.videoKey,
                      controller: controller,
                      fill: Colors.black,
                      controls: NoVideoControls,
                    )
                  : (posterUrl != null
                      ? Image.network(
                          posterUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 640,
                        )
                      : const SizedBox.shrink()),
        ),
      ),
    );
  }
}

class GlobalMiniPlayerOverlay extends ConsumerStatefulWidget {
  const GlobalMiniPlayerOverlay({super.key});

  @override
  ConsumerState<GlobalMiniPlayerOverlay> createState() => _GlobalMiniPlayerOverlayState();
}

class _GlobalMiniPlayerOverlayState extends ConsumerState<GlobalMiniPlayerOverlay>
    with WidgetsBindingObserver {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Tracking continuo de la forma de la ventana para el retorno de PiP
    // (adaptativo vertical/horizontal). En PiP se ignora (congelado).
    PipService.noteWindowMetrics();
  }

  @override
  Widget build(BuildContext context) {
    // PiP solo con sesión activa (mini/full + item + url): sin esto el PiP
    // nativo se armaba también sin nada reproduciendo (p. ej. tras stop/X,
    // donde uiState vuelve a none pero el flag nativo seguía en true).
    // La condición vive en _syncPipState.
    ref.listen(activePlayerProvider, (previous, next) {
      _syncPipState(next);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(activePlayerProvider);
      _syncPipState(state);
      PipService.noteWindowMetrics();
    });

    return KeyedSubtree(
      key: _key,
      child: MiniPlayerBar(
        nativeSurfaceBuilder: VideoSurfaceConfig.nativeAndroidSurface
            ? (context, player, onSurface, onSurfaceDestroyed) {
                return FittedMobileVideoSurface(
                  player: player,
                  onSurface: onSurface,
                  onSurfaceDestroyed: onSurfaceDestroyed,
                );
              }
            : null,
        onExpand: () {          final state = ref.read(activePlayerProvider);
          if (state.currentItem != null) {
            // Senior: Sincroniza uiState antes del push para que PlayerScreen vea isFull=true y no oculte extract
            ref.read(activePlayerProvider.notifier).setUiState(PlayerUIState.full);
            final posterParam = '&posterUrl=${Uri.encodeComponent(state.currentItem!.posterUrl)}&bannerUrl=${Uri.encodeComponent(state.currentItem!.bannerUrl ?? '')}&logoUrl=${Uri.encodeComponent(state.currentItem!.logoUrl ?? '')}';
            final serverParam = state.source != null ? '&serverName=${Uri.encodeComponent(simplifySourceName(state.source!))}' : '';
            // kind/year viajan para que el player reabierto guarde historial fiel
            // aunque tenga que re-ejecutar play() (p. ej. motor muerto en background).
            final kindYearParam = '${state.currentItem!.kind != null && state.currentItem!.kind!.isNotEmpty ? '&kind=${Uri.encodeComponent(state.currentItem!.kind!)}' : ''}${state.currentItem!.year != null ? '&year=${state.currentItem!.year}' : ''}';
            final uri = '/player/${Uri.encodeComponent(state.currentItem!.title)}'
                '?source=${Uri.encodeComponent(state.source ?? '')}'
                '&url=${Uri.encodeComponent(state.url ?? '')}'
                '&episode=${Uri.encodeComponent(state.episode ?? '')}'
                '&season=${state.season ?? ''}'
                '&category=${state.currentItem!.type.name}'
                '$posterParam$serverParam$kindYearParam';
            
            appRouter.push(uri).catchError((_) {
              // Si el push falla, revertir a mini: si no, queda audio sin UI.
              try {
                ref
                    .read(activePlayerProvider.notifier)
                    .setUiState(PlayerUIState.mini);
              } catch (_) {}
              return null;
            });
          }
        },
        onEnterPip: () async {
          // Guard: sin sesión activa no hay nada que mandar a PiP nativo.
          final s = ref.read(activePlayerProvider);
          final hasSession = (s.uiState == PlayerUIState.mini ||
                  s.uiState == PlayerUIState.full) &&
              s.currentItem != null &&
              (s.url ?? '').isNotEmpty;
          if (!hasSession) return;
          // Entrada manual a PiP + verificación del permiso del SO: si el
          // sistema lo revocó, enterPictureInPictureMode falla en silencio.
          final permitted = await PipService.isPipPermitted();
          if (!context.mounted) return;
          if (permitted) {
            final ok = await PipService.enterPip();
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PiP no disponible ahora mismo, reintenta'),
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Permite Picture-in-picture en la ficha de AurisTV'),
                action: SnackBarAction(
                  label: 'Abrir',
                  onPressed: () => PipService.openPipSettings(),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _syncPipState(ActivePlayerState s) {
    PipService.setPipAllowed(
      (s.uiState == PlayerUIState.mini ||
              s.uiState == PlayerUIState.full) &&
          s.currentItem != null &&
          (s.url ?? '').isNotEmpty,
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
            final contentId = p['contentId'];
            final query = Map<String, String>.from(p);
            query.remove('contentId');
            
            final uri = Uri(
              path: '/player/${Uri.encodeComponent(contentId)}',
              queryParameters: query,
            );
            
            appRouter.push(uri.toString());
          }
        }
      }
    });
    
    return child;
  }
}

class DeepLinkHandler extends ConsumerStatefulWidget {
  final Widget child;
  const DeepLinkHandler({super.key, required this.child});

  @override
  ConsumerState<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends ConsumerState<DeepLinkHandler> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleUri(uri);
      },
      onError: (err) {
        debugPrint('Error in uriLinkStream: $err');
      },
    );
  }

  void _handleUri(Uri uri) {
    debugPrint('Deep link received: $uri');
    // Callback de Google OAuth (Supabase PKCE): el navegador vuelve con
    // `io.supabase.flutter://callback?code=...`. Hay que intercambiar el code
    // por la sesión; navegar esa URI por el router sería un no-op.
    if (uri.scheme == 'io.supabase.flutter' &&
        (uri.host == 'callback' || uri.path == 'callback' || uri.path == '/callback')) {
      _completeOauthSignIn(uri);
      return;
    }
    if (uri.path.contains('activate') || uri.host == 'activate') {
      final code = uri.queryParameters['code'] ?? '';
      if (code.isNotEmpty) {
        appRouter.go('/activate?code=$code');
      } else {
        final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
        final query = uri.hasQuery ? '?${uri.query}' : '';
        appRouter.go('$path$query');
      }
    } else {
      final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
      final query = uri.hasQuery ? '?${uri.query}' : '';
      if (path.isNotEmpty && path != '/') {
        appRouter.go('$path$query');
      }
    }
  }

  /// Intercambia el `?code` del callback OAuth por la sesión de Supabase
  /// (PKCE: el verificador quedó guardado cuando signInWithOAuth lanzó el
  /// navegador). Al terminar, la app vuelve donde correspondía: si el login
  /// se abrió desde el flujo de activación (`/login?redirect=...`), retoma
  /// esa ruta (p. ej. `/#/activate?code=XYZ` para vincular la TV); si no, va
  /// al home `/` ya logeado.
  Future<void> _completeOauthSignIn(Uri uri) async {
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      debugPrint('[AurisAuth] OAuth callback: sesión establecida');
      if (!mounted) return;
      final pending = appRouter
          .routerDelegate.currentConfiguration.uri.queryParameters['redirect'];
      if (pending != null && pending.startsWith('/')) {
        appRouter.go(pending);
      } else {
        appRouter.go('/');
      }
    } catch (e) {
      debugPrint('[AurisAuth] OAuth callback falló: $e');
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

