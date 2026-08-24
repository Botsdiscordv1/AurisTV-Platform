import 'package:flutter/material.dart';
import '../../core/utils/responsive_utils.dart';

class BrowserMockupWrapper extends StatelessWidget {
  final Widget child;

  const BrowserMockupWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Solo aplicamos el mockup en Desktop/Web y si la pantalla es suficientemente grande.
    final bool isDesktop = ResponsiveUtils.isDesktop(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    
    // Si es móvil o la ventana es pequeña, mostramos la app normal (responsiva).
    if (!isDesktop || screenWidth < 1000) {
      return child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // 1. Wallpaper de fondo (Ocupa el 100% del Viewport)
          Positioned.fill(
            child: Image.network(
              'https://images.alphacoders.com/605/605592.png', // Wallpaper de Bleach/Aizen como el de la captura
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.6),
              colorBlendMode: BlendMode.darken,
            ),
          ),

          // 2. Contenedor de la Ventana del Navegador (Mockup)
          Center(
            child: Container(
              width: 800,
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B0D),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 50,
                    spreadRadius: 10,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Barra de herramientas del navegador (Mockup)
                  _buildBrowserHeader(),
                  
                  // Contenido de la App (AurisTV)
                  Expanded(
                    child: MediaQuery(
                      // Forzamos a que la app interna crea que el ancho es 800px
                      // para que use sus píxeles adaptativos correctamente.
                      data: MediaQuery.of(context).copyWith(
                        size: const Size(800, 800),
                      ),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowserHeader() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A20),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Botones de control (Cerrar, Minimizar, etc.)
          Row(
            children: [
              _buildDot(Colors.redAccent),
              const SizedBox(width: 8),
              _buildDot(Colors.orangeAccent),
              const SizedBox(width: 8),
              _buildDot(Colors.greenAccent),
            ],
          ),
          const SizedBox(width: 24),
          // Barra de direcciones ficticia
          Expanded(
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_rounded, color: Colors.white24, size: 14),
                  SizedBox(width: 8),
                  Text(
                    'localhost:64399',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 20),
        ],
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.5)),
    );
  }
}
