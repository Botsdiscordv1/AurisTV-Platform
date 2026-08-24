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
    
    // Senior Note: En Web, la intro del index.html ya se está reproduciendo.
    // Una vez que Flutter carga, mostramos la versión nativa (AurisSplashLogo)
    // para asegurar una transición perfecta hacia el Home.
    if (kIsWeb) {
      // Pequeño delay para sincronizar con la intro nativa del navegador
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
      body: Center(
        child: Transform.scale(
          scale: isDesktop ? 1.5 : 1.0, // Escalar la intro en pantallas grandes
          child: AurisSplashLogo(
            onFinished: _onAnimationFinished,
          ),
        ),
      ),
    );
  }
}
