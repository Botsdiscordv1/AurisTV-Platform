import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:auris_core/auris_core.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/min_width_wrapper.dart';
// import 'features/windows/presentation/windows_web_wrapper.dart';
import 'features/remote_control/presentation/providers/remote_control_provider.dart';
import 'features/remote_control/data/models/remote_device.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    /*
    if (!kIsWeb && Platform.isWindows) {
      return MaterialApp(
        title: 'AurisTV Desktop',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const WindowsWebWrapper(),
      );
    }
    */

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
              minWidth: 1024,
              child: child,
            ),
          ),
        );
      },
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
