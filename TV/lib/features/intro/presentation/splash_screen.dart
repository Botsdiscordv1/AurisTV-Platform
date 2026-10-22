import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/utils/web_utils.dart';
import '../../../core/router/app_router.dart';
import 'widgets/auris_splash_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Precarga el collage del Login mientras se ve el Splash para que, al
    // entrar (ahora o cuando Login sea la pantalla de arranque), aparezca
    // LLENO desde el primer frame sin tarjetas vacías.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CollageGridBackground.precache(context);
    });

    // Senior Note: En Web, la intro del index.html ya se esta reproduciendo.
    // Una vez que Flutter carga, mostramos la version nativa (AurisSplashLogo)
    // para asegurar una transicion perfecta hacia el Home.
    if (kIsWeb) {
      // Pequeno delay para sincronizar con la intro nativa del navegador
      Future.delayed(const Duration(milliseconds: 500), () {
        WebUtils.removeSplashScreen();
      });
    }
  }

  /// Navegación al terminar la intro del logo.
  ///
  /// Nuevo flujo de TV: splash → Login (con el collage/carrusel ya precargado
  /// desde initState) cuando NO hay sesión; splash → Home cuando sí la hay.
  /// `authProvider` restaura el usuario local (Hive) en un microtask al
  /// construirse, así que para este punto (tras la animación del logo) ya
  /// resolvió el estado o sigue siendo invitado.
  void _onAnimationFinished() {
    if (!mounted) return;
    final config = appRouter.routerDelegate.currentConfiguration;
    final matches = config.matches;
    final String current = matches.isNotEmpty ? matches.last.matchedLocation : config.uri.path;

    // Si un Cast o DeepLink abrió el reproductor sobre el splash, no lo pisamos
    if (current != '/splash') return;

    final user = ref.read(authProvider);
    final bool hasSession = user != null && user.id != 'guest_user';
    context.go(hasSession ? '/' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo: panel manga monocromo de alto contraste
          Image.asset(
            'assets/images/manga_panel_bg.png',
            fit: BoxFit.cover,
          ),
          // Overlay oscuro para que la animacion del logo resalte
          Container(
            color: const Color(0xCC000000), // negro al 80%
          ),
          // Logo animado centrado
          Center(
            child: Transform.scale(
              scale: isDesktop ? 1.5 : 1.0, // Escalar la intro en pantallas grandes
              child: AurisSplashLogo(
                onFinished: _onAnimationFinished,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
