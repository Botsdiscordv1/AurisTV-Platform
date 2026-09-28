import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:auris_core/auris_core.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/pip_service.dart';
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
  PipService.initialize();

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
              minWidth: 360, // Sincronizado con Web para evitar inconsistencias en tablets
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

class GlobalMiniPlayerOverlay extends ConsumerWidget {
  const GlobalMiniPlayerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(activePlayerProvider, (previous, next) {
      final hasItem = next.currentItem != null;
      _updatePipRect(context, hasItem);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(activePlayerProvider);
      _updatePipRect(context, state.currentItem != null);
    });

    return MiniPlayerBar(
      onExpand: () {
        final state = ref.read(activePlayerProvider);
        if (state.currentItem != null) {
          // Senior: Sincroniza uiState antes del push para que PlayerScreen vea isFull=true y no oculte extract
          ref.read(activePlayerProvider.notifier).setUiState(PlayerUIState.full);
          final posterParam = '&posterUrl=${Uri.encodeComponent(state.currentItem!.posterUrl)}&bannerUrl=${Uri.encodeComponent(state.currentItem!.bannerUrl ?? '')}&logoUrl=${Uri.encodeComponent(state.currentItem!.logoUrl ?? '')}';
          final serverParam = state.source != null ? '&serverName=${Uri.encodeComponent(simplifySourceName(state.source!))}' : '';
          final uri = '/player/${Uri.encodeComponent(state.currentItem!.title)}'
              '?source=${Uri.encodeComponent(state.source ?? '')}'
              '&url=${Uri.encodeComponent(state.url ?? '')}'
              '&episode=${Uri.encodeComponent(state.episode ?? '')}'
              '&season=${state.season ?? ''}'
              '&category=${state.currentItem!.type.name}'
              '$posterParam$serverParam';
          
          appRouter.push(uri);
        }
      },
    );
  }

  void _updatePipRect(BuildContext context, bool allowed) {
    if (!allowed) {
      PipService.setPipAllowed(false);
      return;
    }
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      PipService.setPipAllowed(
        true,
        left: position.dx,
        top: position.dy,
        right: position.dx + size.width,
        bottom: position.dy + size.height,
      );
    } else {
      PipService.setPipAllowed(true);
    }
  }
}
