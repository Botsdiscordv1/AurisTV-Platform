import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:reicon_flutter/reicon_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';

enum _LoginStep {
  welcome,
  loginManual,
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _bgImages = [
    'assets/images/login_bg_collage.webp',
    'assets/images/login_bg_netflix.jpg',
    'assets/images/login_bg_hbomax.webp',
  ];

  int _currentBgIndex = 0;
  Timer? _bgTimer;
  _LoginStep _step = _LoginStep.welcome;
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
      if (mounted && _step == _LoginStep.welcome) {
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

  void _goToStep(_LoginStep step) {
    _fadeCtrl.reset();
    setState(() => _step = step);
    _fadeCtrl.forward();
  }

  void _goBack() {
    if (_step != _LoginStep.welcome) {
      _goToStep(_LoginStep.welcome);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = ResponsiveUtils.isMobile(context);
    final double formWidth = isMobile ? double.infinity : 420.0;
    final bool isWelcome = _step == _LoginStep.welcome;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
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

            // 4. Main Content Area (Bottom for Welcome, Top for Manual Login)
            SafeArea(
              child: isWelcome
                  ? Column(
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
            // 3. Top Header Bar (Back Icon + Title on Manual Step)
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
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isWelcome ? Colors.black.withOpacity(0.50) : Colors.transparent,
                            border: isWelcome
                                ? Border.all(color: Colors.white.withOpacity(0.20), width: 1)
                                : null,
                          ),
                          child: Icon(isWelcome ? Icons.arrow_back : Icons.close, color: Colors.white, size: isWelcome ? 22 : 24),
                        ),
                        onPressed: _goBack,
                      ),
                      if (!isWelcome)
                        const Text(
                          'Acceder',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      const SizedBox(width: 48), // Balance spacing for back button
                    ],
                  ),
                ),
              ),
            ),

          ],
        ),
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
            onPressed: () => _goToStep(_LoginStep.loginManual),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4A724),
              foregroundColor: const Color(0xFF000000),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
                const Text('ACCEDER'),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset('assets/icons/google_logo.svg', height: 20, width: 20),
                const SizedBox(width: 10),
                const Text(
                  'INICIAR SESI\u00D3N CON GOOGLE',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFFEF7A1E)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        GestureDetector(
          onTap: () => _goToStep(_LoginStep.loginManual),
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
          'Al usar AurisTV aceptas nuestros T\u00E9rminos de Uso y Pol\u00EDtica de Privacidad.',
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

  // ── MANUAL LOGIN STEP (CRUNCHYROLL MATCH) ──────────────────────────────────
  Widget _buildManualLoginStep() {
    return Column(
      key: const ValueKey('loginManual'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Centered Brand Logo
        SvgPicture.asset(
          'assets/icons/auris-logo-web-flat.svg',
          height: 42,
          colorFilter: const ColorFilter.mode(
            Color(0xFFEF7A1E),
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(height: 14),

        // Email Field (Crunchyroll Filled Dark Box Style)
        _buildCrunchyField(
          hintText: 'Direcci\u00F3n de email o usuario',
          controller: _emailController,
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 14),

        // Password Field
        _buildCrunchyField(
          hintText: 'Contrase\u00F1a',
          controller: _passwordController,
          icon: Icons.lock_outline,
          isPassword: true,
        ),
        const SizedBox(height: 20),

        // Legal text directly above action button
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
                TextSpan(text: 'Al iniciar sesi\u00F3n aceptas nuestros '),
                TextSpan(
                  text: 'T\u00E9rminos',
                  style: TextStyle(color: Color(0xFFEF7A1E), fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ' & '),
                TextSpan(
                  text: 'Pol\u00EDtica de Privacidad',
                  style: TextStyle(color: Color(0xFFEF7A1E), fontWeight: FontWeight.bold),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Primary Action Button: INICIAR SESIÓN
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4A724),
              foregroundColor: const Color(0xFF000000),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
            child: const Text('INICIAR SESI\u00D3N'),
          ),
        ),
        const SizedBox(height: 22),

        // Footer Links: Forgot Password | Create Account
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FooterLink(label: '\u00BFOLVIDASTE TU CONTRASE\u00D1A?', onTap: () {}),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              child: Text('|', style: TextStyle(color: Colors.white24, fontSize: 13)),
            ),
            _FooterLink(label: 'CREAR CUENTA', onTap: () {}),
          ],
        ),
        const SizedBox(height: 28),

        // Google Social Option
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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

  // Crunchyroll Box Filled Input Field
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
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: Colors.white12, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: Color(0xFFEF7A1E), width: 1.5),
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
