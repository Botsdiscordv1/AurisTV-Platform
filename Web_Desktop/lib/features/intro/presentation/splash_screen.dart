import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/web_utils.dart';
import 'widgets/auris_splash_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
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

  void _onAnimationFinished() {
    if (mounted) {
      context.go('/');
    }
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
