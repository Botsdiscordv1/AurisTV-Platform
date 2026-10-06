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
  }

  @override
  void dispose() {
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

          // 2. Native collage grid background (Welcome screen only)
          AnimatedOpacity(
            opacity: isWelcome ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: Stack(
              children: [
                const Positioned.fill(child: CollageGridBackground()),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
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

        _LegalNotice(fontSize: 11, color: Colors.white.withOpacity(0.40)),
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
          child: _LegalNotice(fontSize: 12, color: Colors.white.withOpacity(0.60)),
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

class _LegalNotice extends StatelessWidget {
  final double fontSize;
  final Color? color;

  const _LegalNotice({this.fontSize = 11, this.color});

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? Colors.white.withOpacity(0.40);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Al usar AurisTV aceptas nuestros ', style: TextStyle(color: textColor, fontSize: fontSize, height: 1.4)),
        GestureDetector(
          onTap: () => context.go('/terms'),
          child: Text('Términos de Uso', style: TextStyle(color: const Color(0xFFEF7A1E), fontSize: fontSize, fontWeight: FontWeight.bold, height: 1.4)),
        ),
        Text(' y la ', style: TextStyle(color: textColor, fontSize: fontSize, height: 1.4)),
        GestureDetector(
          onTap: () => context.go('/privacy'),
          child: Text('Política de Privacidad', style: TextStyle(color: const Color(0xFFEF7A1E), fontSize: fontSize, fontWeight: FontWeight.bold, height: 1.4)),
        ),
        Text('.', style: TextStyle(color: textColor, fontSize: fontSize, height: 1.4)),
      ],
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


  late final AnimationController _panelCtrl;
  late final Animation<double> _panelFade;
  late final Animation<Offset> _panelSlide;

  @override
  void initState() {
    super.initState();


    _panelCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _panelFade = CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOut);
    _panelSlide = Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Capa 1: Grid de posters en perspectiva
          const CollageGridBackground(),

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
                      _LegalNotice(fontSize: 12, color: Colors.white.withOpacity(0.35)),
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
