import 'package:reicon_flutter/reicon_flutter.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Posters usados en el grid de fondo (avatares disponibles en Core)
// ─────────────────────────────────────────────────────────────────────────────
class GridMediaItem {
  final String path;
  final bool isWide; // true para banner horizontal 16:9, false para póster vertical 2:3

  const GridMediaItem(this.path, {this.isWide = false});
}

// Plantilla estilo Netflix con banners (16:9) y pósters (2:3) mezclados.
// Puedes agregar o cambiar las rutas de tus imágenes locales o URLs aquí:
const List<GridMediaItem> _kNetflixCollageItems = [
  GridMediaItem('assets/collage/Anime/banner 1.webp', isWide: true),
  GridMediaItem('assets/collage/Anime/poster 1.webp', isWide: false),
  GridMediaItem('assets/collage/Anime/banner 10.webp', isWide: true),
  GridMediaItem('assets/collage/Anime/poster 10.webp', isWide: false),
  GridMediaItem('assets/collage/Anime/banner 2.webp', isWide: true),
  GridMediaItem('assets/collage/Anime/poster 2.webp', isWide: false),
  GridMediaItem('assets/collage/Anime/banner 3.webp', isWide: true),
  GridMediaItem('assets/collage/Anime/poster 3.webp', isWide: false),
  GridMediaItem('assets/collage/Anime/banner 4.webp', isWide: true),
  GridMediaItem('assets/collage/Anime/poster 4.webp', isWide: false),
  GridMediaItem('assets/collage/Anime/banner 5.webp', isWide: true),
  GridMediaItem('assets/collage/Anime/poster 5.webp', isWide: false),
  GridMediaItem('assets/collage/Anime/banner 6.webp', isWide: true),
  GridMediaItem('assets/collage/Anime/poster 6.webp', isWide: false),
  GridMediaItem('assets/collage/Anime/banner 7.webp', isWide: true),
  GridMediaItem('assets/collage/Anime/poster 7.webp', isWide: false),
  GridMediaItem('assets/collage/Anime/banner 8.webp', isWide: true),
  GridMediaItem('assets/collage/Anime/poster 8.webp', isWide: false),
  GridMediaItem('assets/collage/Anime/banner 9.webp', isWide: true),
  GridMediaItem('assets/collage/Anime/poster 9.webp', isWide: false),
  GridMediaItem('assets/collage/Kdrama/banner 1.webp', isWide: true),
  GridMediaItem('assets/collage/Kdrama/poster 1.webp', isWide: false),
  GridMediaItem('assets/collage/Kdrama/banner 10.webp', isWide: true),
  GridMediaItem('assets/collage/Kdrama/poster 10.webp', isWide: false),
  GridMediaItem('assets/collage/Kdrama/banner 2.webp', isWide: true),
  GridMediaItem('assets/collage/Kdrama/poster 2.webp', isWide: false),
  GridMediaItem('assets/collage/Kdrama/banner 3.webp', isWide: true),
  GridMediaItem('assets/collage/Kdrama/poster 3.webp', isWide: false),
  GridMediaItem('assets/collage/Kdrama/banner 4.webp', isWide: true),
  GridMediaItem('assets/collage/Kdrama/poster 4.webp', isWide: false),
  GridMediaItem('assets/collage/Kdrama/banner 5.webp', isWide: true),
  GridMediaItem('assets/collage/Kdrama/poster 5.webp', isWide: false),
  GridMediaItem('assets/collage/Kdrama/banner 6.webp', isWide: true),
  GridMediaItem('assets/collage/Kdrama/poster 6.webp', isWide: false),
  GridMediaItem('assets/collage/Kdrama/banner 7.webp', isWide: true),
  GridMediaItem('assets/collage/Kdrama/poster 7.webp', isWide: false),
  GridMediaItem('assets/collage/Kdrama/banner 8.webp', isWide: true),
  GridMediaItem('assets/collage/Kdrama/poster 8.webp', isWide: false),
  GridMediaItem('assets/collage/Kdrama/banner 9.webp', isWide: true),
  GridMediaItem('assets/collage/Kdrama/poster 9.webp', isWide: false),
  GridMediaItem('assets/collage/Pelicula/banner 1.webp', isWide: true),
  GridMediaItem('assets/collage/Pelicula/poster 1.webp', isWide: false),
  GridMediaItem('assets/collage/Pelicula/banner 10.webp', isWide: true),
  GridMediaItem('assets/collage/Pelicula/poster 10.webp', isWide: false),
  GridMediaItem('assets/collage/Pelicula/banner 2.webp', isWide: true),
  GridMediaItem('assets/collage/Pelicula/poster 2.webp', isWide: false),
  GridMediaItem('assets/collage/Pelicula/banner 3.webp', isWide: true),
  GridMediaItem('assets/collage/Pelicula/poster 3.webp', isWide: false),
  GridMediaItem('assets/collage/Pelicula/banner 4.webp', isWide: true),
  GridMediaItem('assets/collage/Pelicula/poster 4.webp', isWide: false),
  GridMediaItem('assets/collage/Pelicula/banner 5.webp', isWide: true),
  GridMediaItem('assets/collage/Pelicula/poster 5.webp', isWide: false),
  GridMediaItem('assets/collage/Pelicula/banner 6.webp', isWide: true),
  GridMediaItem('assets/collage/Pelicula/poster 6.webp', isWide: false),
  GridMediaItem('assets/collage/Pelicula/banner 7.webp', isWide: true),
  GridMediaItem('assets/collage/Pelicula/poster 7.webp', isWide: false),
  GridMediaItem('assets/collage/Pelicula/banner 8.webp', isWide: true),
  GridMediaItem('assets/collage/Pelicula/poster 8.webp', isWide: false),
  GridMediaItem('assets/collage/Pelicula/banner 9.webp', isWide: true),
  GridMediaItem('assets/collage/Pelicula/poster 9.webp', isWide: false),
  GridMediaItem('assets/collage/Serie/banner 1.webp', isWide: true),
  GridMediaItem('assets/collage/Serie/poster 1.webp', isWide: false),
  GridMediaItem('assets/collage/Serie/banner 10.webp', isWide: true),
  GridMediaItem('assets/collage/Serie/poster 10.webp', isWide: false),
  GridMediaItem('assets/collage/Serie/banner 2.webp', isWide: true),
  GridMediaItem('assets/collage/Serie/poster 2.webp', isWide: false),
  GridMediaItem('assets/collage/Serie/banner 3.webp', isWide: true),
  GridMediaItem('assets/collage/Serie/poster 3.webp', isWide: false),
  GridMediaItem('assets/collage/Serie/banner 4.webp', isWide: true),
  GridMediaItem('assets/collage/Serie/poster 4.webp', isWide: false),
  GridMediaItem('assets/collage/Serie/banner 5.webp', isWide: true),
  GridMediaItem('assets/collage/Serie/poster 5.webp', isWide: false),
  GridMediaItem('assets/collage/Serie/banner 6.webp', isWide: true),
  GridMediaItem('assets/collage/Serie/poster 6.webp', isWide: false),
  GridMediaItem('assets/collage/Serie/banner 7.webp', isWide: true),
  GridMediaItem('assets/collage/Serie/poster 7.webp', isWide: false),
  GridMediaItem('assets/collage/Serie/banner 8.webp', isWide: true),
  GridMediaItem('assets/collage/Serie/poster 8.webp', isWide: false),
  GridMediaItem('assets/collage/Serie/banner 9.webp', isWide: true),
  GridMediaItem('assets/collage/Serie/poster 9.webp', isWide: false),
];

// ─────────────────────────────────────────────────────────────────────────────
//  Widget raiz: detecta si es desktop o mobile y muestra la pantalla correcta
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = !ResponsiveUtils.isMobile(context);
    if (isDesktop) {
      return const _DesktopLoginScreen();
    } else {
      return const _MobileLoginScreen();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MOBILE / TABLET: reutiliza el mismo flujo de la plataforma Movil
// ─────────────────────────────────────────────────────────────────────────────
enum _MobileStep { welcome, loginManual }

class _MobileLoginScreen extends ConsumerStatefulWidget {
  const _MobileLoginScreen();

  @override
  ConsumerState<_MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends ConsumerState<_MobileLoginScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _bgImages = [
    'assets/images/login_bg_collage.webp',
    'assets/images/login_bg_netflix.jpg',
    'assets/images/login_bg_hbomax.webp',
  ];

  int _currentBgIndex = 0;
  Timer? _bgTimer;
  _MobileStep _step = _MobileStep.welcome;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _currentBgIndex = Random().nextInt(_bgImages.length);
    _startBgRotation();
  }

  void _startBgRotation() {
    _bgTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted && _step == _MobileStep.welcome) {
        setState(() {
          _currentBgIndex = (_currentBgIndex + 1) % _bgImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _bgTimer?.cancel();
    _fadeCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToStep(_MobileStep step) {
    _fadeCtrl.reset();
    setState(() => _step = step);
    _fadeCtrl.forward();
  }

  void _goBack() {
    if (_step != _MobileStep.welcome) {
      _goToStep(_MobileStep.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = ResponsiveUtils.isMobile(context);
    final double formWidth = isMobile ? double.infinity : 420.0;
    final bool isWelcome = _step == _MobileStep.welcome;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: Stack(
        children: [
          // 1. App Dark Base Background
          const Positioned.fill(child: ColoredBox(color: Color(0xFF0B0B0D))),

          // 2. Dynamic Background Carousel (Welcome screen only)
          AnimatedOpacity(
            opacity: isWelcome ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: size.height * 0.70,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1400),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    child: Image.asset(
                      _bgImages[_currentBgIndex],
                      key: ValueKey<String>(_bgImages[_currentBgIndex]),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => Container(color: Colors.black),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: size.height * 0.75,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.30, 0.52, 0.70, 0.86, 1.0],
                        colors: [
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0x40000000),
                          Color(0xBF000000),
                          Color(0xF5000000),
                          Color(0xFF0B0B0D),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Main Content Area (Bottom for Welcome, Top for Manual Login)
          SafeArea(
            child: isWelcome
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Column(
                              children: [
                                const Spacer(),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  child: Center(
                                    child: SizedBox(
                                      width: formWidth,
                                      child: FadeTransition(
                                        opacity: _fadeAnim,
                                        child: _buildWelcomeStep(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Center(
                        child: SizedBox(
                          width: formWidth,
                          child: Column(
                            children: [
                              SizedBox(height: size.height * 0.08),
                              FadeTransition(
                                opacity: _fadeAnim,
                                child: _buildManualLoginStep(),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),

          // 4. Top Header Bar (Back Icon + Title on Manual Step)
          if (!isWelcome)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                        ),
                        onPressed: _goBack,
                      ),
                      const Text(
                        'Acceder',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── WELCOME STEP ─────────────────────────────────────────────────────────────
  Widget _buildWelcomeStep() {
    return Column(
      key: const ValueKey('welcome'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/auris-logo-web-flat.svg',
              height: 38,
              colorFilter: const ColorFilter.mode(
                Color(0xFFEF7A1E),
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Todo tu entretenimiento favorito.\nEn un solo lugar.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 28),

        // Primary Button: ACCEDER
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => _goToStep(_MobileStep.loginManual),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4A724),
              foregroundColor: const Color(0xFF000000),
              elevation: 0,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.string(
                  reiconSvg(Reicon.outline.crown3),
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF000000),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'ACCEDER',
                  style: TextStyle(
                    color: Color(0xFF000000),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary Button: GOOGLE
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFEF7A1E), width: 1.5),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset('assets/icons/google_logo.svg', height: 20, width: 20),
                const SizedBox(width: 10),
                const Text(
                  'INICIAR SESIÓN CON GOOGLE',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFFEF7A1E)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        GestureDetector(
          onTap: () => _goToStep(_MobileStep.loginManual),
          child: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 13, letterSpacing: 0.4),
              children: [
                TextSpan(text: 'o ', style: TextStyle(color: Colors.white60)),
                TextSpan(text: 'Crear cuenta', style: TextStyle(color: Color(0xFFEF7A1E), fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Text(
          'Al usar AurisTV aceptas nuestros Términos de Uso y Política de Privacidad.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.40),
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ── MANUAL LOGIN STEP ────────────────────────────────────────────────────────
  Widget _buildManualLoginStep() {
    return Column(
      key: const ValueKey('loginManual'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/icons/auris-logo-web-flat.svg',
          height: 42,
          colorFilter: const ColorFilter.mode(
            Color(0xFFEF7A1E),
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(height: 14),

        _buildCrunchyField(
          hintText: 'Dirección de email o usuario',
          controller: _emailController,
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 14),

        _buildCrunchyField(
          hintText: 'Contraseña',
          controller: _passwordController,
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: Colors.white.withOpacity(0.60),
                fontSize: 12,
                height: 1.35,
              ),
              children: const [
                TextSpan(text: 'Al iniciar sesión aceptas nuestros '),
                TextSpan(
                  text: 'Términos',
                  style: TextStyle(color: Color(0xFFEF7A1E), fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ' & '),
                TextSpan(
                  text: 'Política de Privacidad',
                  style: TextStyle(color: Color(0xFFEF7A1E), fontWeight: FontWeight.bold),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4A724),
              foregroundColor: const Color(0xFF000000),
              elevation: 0,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
            child: const Text('INICIAR SESIÓN'),
          ),
        ),
        const SizedBox(height: 22),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FooterLink(label: '¿OLVIDASTE TU CONTRASEÑA?', onTap: () {}),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              child: Text('|', style: TextStyle(color: Colors.white24, fontSize: 13)),
            ),
            _FooterLink(label: 'CREAR CUENTA', onTap: () {}),
          ],
        ),
        const SizedBox(height: 28),

        const Center(
          child: Text(
            'O CONECTAR CON',
            style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFEF7A1E), width: 1.5),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset('assets/icons/google_logo.svg', height: 20, width: 20),
                const SizedBox(width: 10),
                const Text(
                  'GOOGLE',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1, color: Color(0xFFEF7A1E)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCrunchyField({
    required String hintText,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !_showPassword,
      cursorColor: const Color(0xFFEF7A1E),
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF141418),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.40), fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              )
            : null,
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.white12, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFFEF7A1E), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFEF7A1E),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

//  DESKTOP: Pantalla estilo Netflix/Crunchyroll con grid de posters en perspectiva
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopLoginScreen extends ConsumerStatefulWidget {
  const _DesktopLoginScreen();

  @override
  ConsumerState<_DesktopLoginScreen> createState() => _DesktopLoginScreenState();
}

class _DesktopLoginScreenState extends ConsumerState<_DesktopLoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _showPanel = false;
  late final List<GridMediaItem> _items;

  late final AnimationController _scrollCtrl;
  late final Animation<double> _scrollAnim;

  late final AnimationController _panelCtrl;
  late final Animation<double> _panelFade;
  late final Animation<Offset> _panelSlide;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _items = List.from(_kNetflixCollageItems)..shuffle(rng);

    _scrollCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
    _scrollAnim = CurvedAnimation(parent: _scrollCtrl, curve: Curves.linear);

    _panelCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _panelFade = CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOut);
    _panelSlide = Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _panelCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openPanel() {
    setState(() => _showPanel = true);
    _panelCtrl.forward();
  }

  void _closePanel() {
    _panelCtrl.reverse().then((_) {
      if (mounted) setState(() => _showPanel = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Capa 1: Grid de posters en perspectiva
          _PosterGridBackground(items: _items, scrollAnim: _scrollAnim, screenSize: size),

          // Capa 2: Gradiente izquierda -> derecha
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.50, 1.0],
                colors: [Color(0xF2000000), Color(0xAA000000), Color(0x22000000)],
              ),
            ),
          ),
          // Capa 2b: Gradiente arriba/abajo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.12, 0.88, 1.0],
                colors: [Color(0xEE000000), Color(0x00000000), Color(0x00000000), Color(0xEE000000)],
              ),
            ),
          ),

          // Capa 3: Navbar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => context.go('/inicio'),
                        child: SvgPicture.asset('assets/icons/auris-logo-web-flat.svg', height: 38, colorFilter: const ColorFilter.mode(Color(0xFFEF7A1E), BlendMode.srcIn)),
                      ),
                    ),
                    Row(children: [
                      OutlinedButton(
                        onPressed: _openPanel,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white60, width: 1.5),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 13),
                        ),
                        child: const Text('ACCEDER'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF7A1E), foregroundColor: Colors.black,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 13),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          SvgPicture.asset('assets/icons/google_logo.svg', height: 18),
                          const SizedBox(width: 8),
                          const Text('GOOGLE'),
                        ]),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),

          // Capa 4: Hero izquierdo
          Positioned(
            left: 0, right: 0, top: 0, bottom: 0,
            child: Padding(
              padding: const EdgeInsets.only(left: 52, right: 52),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'El mayor catalogo\nde anime, a tu alcance.',
                        style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, height: 1.08, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Unete a AurisTV y descubre el mundo del anime sin limites.',
                        style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 19, height: 1.45),
                      ),
                      const SizedBox(height: 36),
                      // Inline email + botón estilo Netflix
                      _InlineEmailRow(emailController: _emailController, onAcceder: _openPanel),
                      const SizedBox(height: 14),
                      Text(
                        'Al acceder aceptas nuestros Terminos de Uso y Politica de Privacidad.',
                        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Capa 5: Backdrop oscuro cuando panel está abierto
          if (_showPanel)
            GestureDetector(
              onTap: _closePanel,
              child: FadeTransition(
                opacity: _panelFade,
                child: Container(color: Colors.black.withOpacity(0.50)),
              ),
            ),

          // Capa 6: Panel lateral de login
          if (_showPanel)
            Positioned(
              top: 0, right: 0, bottom: 0,
              width: 420,
              child: SlideTransition(
                position: _panelSlide,
                child: FadeTransition(
                  opacity: _panelFade,
                  child: Container(
                    color: const Color(0xF5000000),
                    child: SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(36, 28, 36, 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              SvgPicture.asset('assets/icons/auris-logo-web-flat.svg', height: 34, colorFilter: const ColorFilter.mode(Color(0xFFEF7A1E), BlendMode.srcIn)),
                              IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 22), onPressed: _closePanel),
                            ]),
                            const SizedBox(height: 40),
                            const Text('Iniciar sesion', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text('Accede con tu cuenta AurisTV.', style: TextStyle(color: Colors.white.withOpacity(0.52), fontSize: 14)),
                            const SizedBox(height: 36),
                            _buildPanelField(label: 'Direccion de email', controller: _emailController, icon: Icons.email_outlined),
                            const SizedBox(height: 20),
                            _buildPanelField(label: 'Contrasena', controller: _passwordController, icon: Icons.lock_outline, isPassword: true),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity, height: 52,
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF7A1E), foregroundColor: Colors.black, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                                child: const Text('ACCEDER'),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              _FooterLink(label: 'OLVIDE MI CONTRASENA', onTap: () {}),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('|', style: TextStyle(color: Colors.white24, fontSize: 13))),
                              _FooterLink(label: 'CREAR CUENTA', onTap: () {}),
                            ]),
                            const SizedBox(height: 36),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 24),
                            const Center(child: Text('O CONECTAR CON', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity, height: 52,
                              child: OutlinedButton(
                                onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFEF7A1E), width: 1.5), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), foregroundColor: Colors.white),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  SvgPicture.asset('assets/icons/google_logo.svg', height: 22),
                                  const SizedBox(width: 12),
                                  const Text('CONTINUAR CON GOOGLE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1, color: Color(0xFFEF7A1E))),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPanelField({required String label, required TextEditingController controller, required IconData icon, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        const SizedBox(height: 6),
        TextField(
          controller: controller, obscureText: isPassword && !_showPassword, cursorColor: const Color(0xFFEF7A1E),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            filled: true, fillColor: const Color(0xFF141418),
            prefixIcon: Icon(icon, color: Colors.white38, size: 20),
            suffixIcon: isPassword ? IconButton(icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20), onPressed: () => setState(() => _showPassword = !_showPassword)) : null,
            enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.white12)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Color(0xFFEF7A1E), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Grid de posters con perspectiva y scroll horizontal lento
// ─────────────────────────────────────────────────────────────────────────────
class _PosterGridBackground extends StatelessWidget {
  final List<GridMediaItem> items;
  final Animation<double> scrollAnim;
  final Size screenSize;

  const _PosterGridBackground({
    required this.items,
    required this.scrollAnim,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    // Height set to 168px to preserve full natural 2:3 poster ratio and 16:9 banner ratio
    const double cardHeight = 168.0;
    const double gap = 12.0;
    const double posterWidth = 112.0; // 2:3 ratio (112 x 168)
    const double bannerWidth = 298.0; // 16:9 ratio (298 x 168)
    const int numRows = 7;
    final List<int> rowSizes = [11, 11, 11, 11, 11, 11, 14];

    return AnimatedBuilder(
      animation: scrollAnim,
      builder: (context, _) {
        final double t = scrollAnim.value; // 0.0 → 1.0 repeating
        int currentStart = 0;

        return ClipRect(
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform(
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0006)
                ..rotateZ(-0.14)
                ..rotateX(0.12)
                ..scale(1.28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(numRows, (rowIndex) {
                  final int count = rowSizes[rowIndex % rowSizes.length];
                  final int startIdx = currentStart;
                  currentStart += count;

                  // Unique partition of items per row (no image repeated across rows)
                  final List<GridMediaItem> rowItems = List.generate(
                    count,
                    (i) => items[(startIdx + i) % items.length],
                  );

                  // Calculate exact width of 1 single copy of this row
                  final double singleWidth = rowItems.fold(0.0, (sum, item) {
                    return sum + (item.isWide ? bannerWidth : posterWidth) + gap;
                  });

                  // Speed & Direction per row
                  final bool goesLeft = rowIndex.isEven;
                  final double speedFactor = 0.85 + (rowIndex * 0.05); // 0.85..1.15
                  final double progress = (t * speedFactor) % 1.0;

                  // Offset animation over 1 singleWidth for seamless loop
                  // Round to nearest pixel to eliminate sub-pixel rendering jitter
                  final double dx = goesLeft
                      ? (-(progress * singleWidth)).roundToDouble()
                      : (-((1.0 - progress) * singleWidth)).roundToDouble();

                  // Repeat 6 times so row total width (~15,000px) easily covers
                  // rotated screen boundaries on left (-7500px) and right (+5000px)
                  final List<GridMediaItem> repeated = [
                    ...rowItems,
                    ...rowItems,
                    ...rowItems,
                    ...rowItems,
                    ...rowItems,
                    ...rowItems,
                  ];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: gap),
                    child: Transform.translate(
                      offset: Offset(dx, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: repeated.map((item) {
                          final double w = item.isWide ? bannerWidth : posterWidth;
                          return Container(
                            width: w,
                            height: cardHeight,
                            margin: const EdgeInsets.only(right: gap),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141418),
                              borderRadius: BorderRadius.circular(6),
                              // No border — thin borders cause sub-pixel jitter during translation
                              // Depth is provided by surrounding shadows instead
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black87,
                                  blurRadius: 6,
                                  spreadRadius: 0,
                                  offset: Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: item.path.startsWith('http')
                                ? Image.network(
                                    item.path,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.high,
                                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                                  )
                                : Image.asset(
                                    item.path,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.high,
                                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                                  ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1B1C22),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white24, size: 28),
      ),
    );
  }
}

//  Formulario email inline estilo Netflix
// ─────────────────────────────────────────────────────────────────────────────
class _InlineEmailRow extends StatelessWidget {
  final TextEditingController emailController;
  final VoidCallback onAcceder;

  const _InlineEmailRow({required this.emailController, required this.onAcceder});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Quieres ver AurisTV ya? Ingresa tu email para comenzar.',
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16, height: 1.4),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TextField(
                  controller: emailController,
                  cursorColor: const Color(0xFFEF7A1E),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.6),
                    hintText: 'Email o nombre de usuario',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Colors.white38, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFFEF7A1E), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: const Color(0xFFEF7A1E),
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  onTap: onAcceder,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Comenzar',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.chevron_right, color: Colors.white, size: 26),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

//  Widgets auxiliares compartidos
// ─────────────────────────────────────────────────────────────────────────────
