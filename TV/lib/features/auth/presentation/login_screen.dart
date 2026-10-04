import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Screen entry point
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginStep {
  welcome,        // Crunchyroll-style landing
  scanQR,         // Scan QR Code
  activateCode,   // Activate with Code
  loginEmail,     // Log In with Email
  createAccount,  // Create Account
  forgotPassword, // Forgot Password?
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  _LoginStep _step = _LoginStep.welcome;
  late String _activationCode;
  Timer? _pollTimer;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  TextEditingController? _activeController;

  // Focus nodes for TV D-PAD navigation
  final FocusNode _loginBtnFocus      = FocusNode();
  final FocusNode _backBtnFocus       = FocusNode();
  final FocusNode _scanQrFocus        = FocusNode();
  final FocusNode _activateCodeFocus  = FocusNode();
  final FocusNode _loginEmailFocus    = FocusNode();
  final FocusNode _createAccountFocus = FocusNode();
  final FocusNode _forgotPassFocus    = FocusNode();
  final FocusNode _emailInputFocus    = FocusNode();
  final FocusNode _passInputFocus     = FocusNode();
  final FocusNode _eyeBtnFocus        = FocusNode();
  final FocusNode _submitBtnFocus     = FocusNode();
  bool _showPassword = false;

  // Page-level animation
  late final AnimationController _fadeCtrl;
  late final Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();
    _activationCode = DeviceActivationService.generateCode();
    _activeController = _emailController;
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loginBtnFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _fadeCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _loginBtnFocus.dispose();
    _backBtnFocus.dispose();
    _scanQrFocus.dispose();
    _activateCodeFocus.dispose();
    _loginEmailFocus.dispose();
    _createAccountFocus.dispose();
    _forgotPassFocus.dispose();
    _emailInputFocus.dispose();
    _passInputFocus.dispose();
    _eyeBtnFocus.dispose();
    _submitBtnFocus.dispose();
    super.dispose();
  }

  void _startActivationPolling() {
    _pollTimer?.cancel();
    setState(() {
      _activationCode = DeviceActivationService.generateCode();
    });
    DeviceActivationService.createActivationSession(_activationCode);

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final userAccount = await DeviceActivationService.checkActivationStatus(_activationCode);
      if (userAccount != null && mounted) {
        timer.cancel();
        _pollTimer = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Dispositivo activado con éxito! Iniciando sesión...'),
            backgroundColor: Color(0xFFEF7A1E),
          ),
        );
        context.go('/home');
      }
    });
  }

  void _stopActivationPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _enterSubMenu(_LoginStep step) {
    _fadeCtrl.reset();
    setState(() => _step = step);
    _fadeCtrl.forward();

    if (step == _LoginStep.scanQR || step == _LoginStep.activateCode) {
      _startActivationPolling();
    } else {
      _stopActivationPolling();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (step == _LoginStep.scanQR) {
          _scanQrFocus.requestFocus();
        } else if (step == _LoginStep.activateCode) {
          _activateCodeFocus.requestFocus();
        } else if (step == _LoginStep.loginEmail) {
          _loginEmailFocus.requestFocus();
        } else if (step == _LoginStep.createAccount) {
          _createAccountFocus.requestFocus();
        } else if (step == _LoginStep.forgotPassword) {
          _forgotPassFocus.requestFocus();
        } else if (step == _LoginStep.welcome) {
          _loginBtnFocus.requestFocus();
        }
      }
    });
  }

  void _selectSubMenu(_LoginStep step) {
    if (_step == step) return;
    setState(() => _step = step);

    if (step == _LoginStep.scanQR || step == _LoginStep.activateCode) {
      _startActivationPolling();
    } else {
      _stopActivationPolling();
    }
  }

  void _goBack() {
    if (_step != _LoginStep.welcome) {
      _enterSubMenu(_LoginStep.welcome);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0C0C),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Stack(
            children: [
              // Full screen background: Collage on welcome, solid black on sub-menus
              Positioned.fill(
                child: _step == _LoginStep.welcome
                    ? const CollageGridBackground()
                    : const ColoredBox(color: Color(0xFF000000)),
              ),

              // Subtle ambient shadow on left side
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: [0.0, 0.45, 1.0],
                      colors: [
                        Color(0x990A0A0A),
                        Color(0x330A0A0A),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              if (_step == _LoginStep.welcome) ...[
                // Mascot PNG (transparent bg) right side
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: size.width * 0.52,
                  child: _MascotPanel(step: _step),
                ),

                // Content – left half
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: size.width * 0.58,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(64, 0, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 52),
                        SvgPicture.asset(
                          'assets/icons/auris-logo-web-flat.svg',
                          height: 38,
                          alignment: Alignment.centerLeft,
                        ),
                        Expanded(
                          child: Align(
                            alignment: const Alignment(-1, -0.15),
                            child: _buildWelcomeStep(),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 36),
                          child: Text(
                            'Al usar AurisTV aceptas nuestros Terminos de Uso y Politica de Privacidad.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Sub-menu layout: Left Sidebar + Right Content
                Row(
                  children: [
                    _LoginSidebar(
                      currentStep: _step,
                      backFocus: _backBtnFocus,
                      scanQrFocus: _scanQrFocus,
                      activateCodeFocus: _activateCodeFocus,
                      loginEmailFocus: _loginEmailFocus,
                      createAccountFocus: _createAccountFocus,
                      forgotPassFocus: _forgotPassFocus,
                      onBack: _goBack,
                      onSelectStep: _selectSubMenu,
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.fromLTRB(64, 52, 64, 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: _step == _LoginStep.scanQR
                                    ? const Alignment(0, -0.15)
                                    : const Alignment(-1, -0.15),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeOut,
                                  transitionBuilder: (child, anim) {
                                    return FadeTransition(
                                      opacity: anim,
                                      child: child,
                                    );
                                  },
                                  child: KeyedSubtree(
                                    key: ValueKey(_step),
                                    child: _buildSubMenuContent(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Welcome Step
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildWelcomeStep() {
    return Column(
      key: const ValueKey('welcome'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '¡Bienvenido!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Elige como quieres acceder.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.50),
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 52),

        // ACCEDER -> Opens Scan QR Code step
        _BigButton(
          focusNode: _loginBtnFocus,
          label: 'ACCEDER',
          filled: true,
          onPressed: () => _enterSubMenu(_LoginStep.scanQR),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  Sub-Menu Content Switcher
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSubMenuContent() {
    switch (_step) {
      case _LoginStep.scanQR:
        return _buildScanQRStep();
      case _LoginStep.activateCode:
        return _buildActivateCodeStep();
      case _LoginStep.loginEmail:
        return _buildLoginEmailStep();
      case _LoginStep.createAccount:
        return _buildCreateAccountStep();
      case _LoginStep.forgotPassword:
        return _buildForgotPassStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // 1. Scan QR Code
  Widget _buildScanQRStep() {
    final qrDirectUrl = 'auristv://activate?code=$_activationCode';

    return Column(
      key: const ValueKey('scan_qr'),
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Iniciar sesión en AurisTV',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: QrImageView(
            data: qrDirectUrl,
            version: QrVersions.auto,
            size: 165,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 420,
          child: Text(
            'Escanea el código QR con la cámara de tu teléfono para iniciar sesión automáticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // 2. Activate with Code
  Widget _buildActivateCodeStep() {
    return Column(
      key: const ValueKey('activate_code'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Iniciar sesión en AurisTV',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 24),
        const _StepRow(
          n: '1',
          text: 'Entra a: auristv.dpdns.org/activate',
        ),
        const SizedBox(height: 14),
        const _StepRow(
          n: '2',
          text: 'Introduce este código:',
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 38),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _activationCode.length == 6
                  ? '${_activationCode.substring(0, 3)} - ${_activationCode.substring(3)}'
                  : _activationCode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _StepRow(
          n: '3',
          text: 'Permanece en esta pantalla y la TV iniciará sesión automáticamente.',
        ),
      ],
    );
  }

  // 3. Log In with Email
  Widget _buildLoginEmailStep() {
    return Column(
      key: const ValueKey('login_email'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Iniciar sesión en AurisTV',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 24),

        // Email Address Label
        const Text(
          'Correo electrónico',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _TVCleanTextField(
          focusNode: _emailInputFocus,
          controller: _emailController,
          hintText: 'ejemplo@auristv.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          nextFocus: _passInputFocus,
          prevFocus: _loginEmailFocus,
        ),
        const SizedBox(height: 20),

        // Password Label
        const Text(
          'Contraseña',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TVCleanTextField(
                focusNode: _passInputFocus,
                controller: _passwordController,
                hintText: '••••••••',
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                prevFocus: _emailInputFocus,
                nextFocus: _submitBtnFocus,
                rightFocus: _eyeBtnFocus,
                onSubmitted: (_) => _performManualLogin(),
              ),
            ),
            const SizedBox(width: 12),
            _EyeToggleButton(
              focusNode: _eyeBtnFocus,
              showPassword: _showPassword,
              leftFocus: _passInputFocus,
              prevFocus: _emailInputFocus,
              nextFocus: _submitBtnFocus,
              onToggle: () => setState(() => _showPassword = !_showPassword),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // LOG IN Button
        _BigButton(
          focusNode: _submitBtnFocus,
          label: 'INICIAR SESIÓN',
          filled: true,
          prevFocus: _passInputFocus,
          onPressed: _performManualLogin,
        ),
      ],
    );
  }

  // 4. Create Account
  Widget _buildCreateAccountStep() {
    return Column(
      key: const ValueKey('create_account'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Crear cuenta',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Visita auristv.dpdns.org/register para crear una cuenta nueva y disfrutar de todo el contenido de AurisTV en tu televisor.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 18,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // 5. Forgot Password?
  Widget _buildForgotPassStep() {
    return Column(
      key: const ValueKey('forgot_pass'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '¿Olvidaste tu contraseña?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Visita auristv.dpdns.org/reset para restablecer tu contraseña y recuperar el acceso a tu cuenta.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 18,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Future<void> _performManualLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa tu correo y contraseña.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Sesión iniciada con éxito!'),
            backgroundColor: Color(0xFFEF7A1E),
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de autenticación: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sidebar Navigation Menu (Crunchyroll Style)
// ─────────────────────────────────────────────────────────────────────────────
class _LoginSidebar extends StatelessWidget {
  final _LoginStep currentStep;
  final FocusNode backFocus;
  final FocusNode scanQrFocus;
  final FocusNode activateCodeFocus;
  final FocusNode loginEmailFocus;
  final FocusNode createAccountFocus;
  final FocusNode forgotPassFocus;
  final VoidCallback onBack;
  final ValueChanged<_LoginStep> onSelectStep;

  const _LoginSidebar({
    required this.currentStep,
    required this.backFocus,
    required this.scanQrFocus,
    required this.activateCodeFocus,
    required this.loginEmailFocus,
    required this.createAccountFocus,
    required this.forgotPassFocus,
    required this.onBack,
    required this.onSelectStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      color: const Color(0xFF14141E),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarBackButton(
            focusNode: backFocus,
            onPressed: onBack,
            nextFocus: scanQrFocus,
          ),
          const SizedBox(height: 36),
          _SidebarMenuItem(
            focusNode: scanQrFocus,
            label: 'Escanear código QR',
            isSelected: currentStep == _LoginStep.scanQR,
            prevFocus: backFocus,
            nextFocus: activateCodeFocus,
            onFocus: () => onSelectStep(_LoginStep.scanQR),
            onPressed: () => onSelectStep(_LoginStep.scanQR),
          ),
          const SizedBox(height: 12),
          _SidebarMenuItem(
            focusNode: activateCodeFocus,
            label: 'Activar con código',
            isSelected: currentStep == _LoginStep.activateCode,
            prevFocus: scanQrFocus,
            nextFocus: loginEmailFocus,
            onFocus: () => onSelectStep(_LoginStep.activateCode),
            onPressed: () => onSelectStep(_LoginStep.activateCode),
          ),
          const SizedBox(height: 12),
          _SidebarMenuItem(
            focusNode: loginEmailFocus,
            label: 'Iniciar sesión con email',
            isSelected: currentStep == _LoginStep.loginEmail,
            prevFocus: activateCodeFocus,
            nextFocus: createAccountFocus,
            onFocus: () => onSelectStep(_LoginStep.loginEmail),
            onPressed: () => onSelectStep(_LoginStep.loginEmail),
          ),
          const SizedBox(height: 12),
          _SidebarMenuItem(
            focusNode: createAccountFocus,
            label: 'Crear cuenta',
            isSelected: currentStep == _LoginStep.createAccount,
            prevFocus: loginEmailFocus,
            nextFocus: forgotPassFocus,
            onFocus: () => onSelectStep(_LoginStep.createAccount),
            onPressed: () => onSelectStep(_LoginStep.createAccount),
          ),
          const SizedBox(height: 12),
          _SidebarMenuItem(
            focusNode: forgotPassFocus,
            label: '¿Olvidaste tu contraseña?',
            isSelected: currentStep == _LoginStep.forgotPassword,
            prevFocus: createAccountFocus,
            onFocus: () => onSelectStep(_LoginStep.forgotPassword),
            onPressed: () => onSelectStep(_LoginStep.forgotPassword),
          ),
        ],
      ),
    );
  }
}

class _SidebarBackButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final FocusNode? nextFocus;

  const _SidebarBackButton({
    required this.focusNode,
    required this.onPressed,
    this.nextFocus,
  });

  @override
  State<_SidebarBackButton> createState() => _SidebarBackButtonState();
}

class _SidebarBackButtonState extends State<_SidebarBackButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown && widget.nextFocus != null) {
            widget.nextFocus!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _focused ? AppTheme.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '← VOLVER',
                style: TextStyle(
                  color: _focused ? Colors.black : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarMenuItem extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final bool isSelected;
  final VoidCallback onFocus;
  final VoidCallback onPressed;
  final FocusNode? prevFocus;
  final FocusNode? nextFocus;

  const _SidebarMenuItem({
    required this.focusNode,
    required this.label,
    required this.isSelected,
    required this.onFocus,
    required this.onPressed,
    this.prevFocus,
    this.nextFocus,
  });

  @override
  State<_SidebarMenuItem> createState() => _SidebarMenuItemState();
}

class _SidebarMenuItemState extends State<_SidebarMenuItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f) {
          widget.onFocus();
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown && widget.nextFocus != null) {
            widget.nextFocus!.requestFocus();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp && widget.prevFocus != null) {
            widget.prevFocus!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          widget.focusNode.requestFocus();
          widget.onPressed();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _focused ? AppTheme.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _focused ? Colors.black : (widget.isSelected ? Colors.white : Colors.white70),
              fontSize: 16,
              fontWeight: widget.isSelected || _focused ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Mascot panel (right side in welcome step)
// ─────────────────────────────────────────────────────────────────────────────
class _MascotPanel extends StatelessWidget {
  final _LoginStep step;
  const _MascotPanel({required this.step});

  @override
  Widget build(BuildContext context) {
    final isWelcome = step == _LoginStep.welcome;
    return AnimatedOpacity(
      opacity: isWelcome ? 1.0 : 0.25,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          heightFactor: isWelcome ? 0.8 : 1.0,
          alignment: Alignment.bottomCenter,
          child: Image.asset(
            'assets/icons/login_mascot.png',
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Big welcome / action button
// ─────────────────────────────────────────────────────────────────────────────
class _BigButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final bool filled;
  final VoidCallback onPressed;
  final FocusNode? nextFocus;
  final FocusNode? prevFocus;

  const _BigButton({
    required this.focusNode,
    required this.label,
    required this.filled,
    required this.onPressed,
    this.nextFocus,
    this.prevFocus,
  });

  @override
  State<_BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<_BigButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isFilled = widget.filled;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter  ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown && widget.nextFocus != null) {
            widget.nextFocus!.requestFocus();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp && widget.prevFocus != null) {
            widget.prevFocus!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 310,
          height: isFilled ? 52 : 40,
          decoration: BoxDecoration(
            color: _focused ? AppTheme.brand : Colors.transparent,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: _focused ? AppTheme.brand : Colors.white,
              width: 2.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: _focused ? Colors.black : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  QR step row (number + text)
// ─────────────────────────────────────────────────────────────────────────────
class _StepRow extends StatelessWidget {
  final String n;
  final String text;
  const _StepRow({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            n,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Clean TV Text Field
// ─────────────────────────────────────────────────────────────────────────────
class _TVCleanTextField extends StatefulWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final FocusNode? nextFocus;
  final FocusNode? prevFocus;
  final FocusNode? rightFocus;
  final ValueChanged<String>? onSubmitted;

  const _TVCleanTextField({
    required this.focusNode,
    required this.controller,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.nextFocus,
    this.prevFocus,
    this.rightFocus,
    this.onSubmitted,
  });

  @override
  State<_TVCleanTextField> createState() => _TVCleanTextFieldState();
}

class _TVCleanTextFieldState extends State<_TVCleanTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowDown && widget.nextFocus != null) {
            widget.nextFocus!.requestFocus();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp && widget.prevFocus != null) {
            widget.prevFocus!.requestFocus();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight && widget.rightFocus != null) {
            widget.rightFocus!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 420,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _focused ? AppTheme.brand : Colors.white24,
            width: _focused ? 2.5 : 1.5,
          ),
        ),
        alignment: Alignment.centerLeft,
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.obscureText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 15,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onSubmitted: widget.onSubmitted,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Eye Toggle Button for Password
// ─────────────────────────────────────────────────────────────────────────────
class _EyeToggleButton extends StatefulWidget {
  final FocusNode focusNode;
  final bool showPassword;
  final VoidCallback onToggle;
  final FocusNode? leftFocus;
  final FocusNode? prevFocus;
  final FocusNode? nextFocus;

  const _EyeToggleButton({
    required this.focusNode,
    required this.showPassword,
    required this.onToggle,
    this.leftFocus,
    this.prevFocus,
    this.nextFocus,
  });

  @override
  State<_EyeToggleButton> createState() => _EyeToggleButtonState();
}

class _EyeToggleButtonState extends State<_EyeToggleButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            widget.onToggle();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft && widget.leftFocus != null) {
            widget.leftFocus!.requestFocus();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp && widget.prevFocus != null) {
            widget.prevFocus!.requestFocus();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown && widget.nextFocus != null) {
            widget.nextFocus!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _focused ? AppTheme.brand : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _focused ? AppTheme.brand : Colors.white24,
              width: 2,
            ),
          ),
          child: Center(
            child: Icon(
              widget.showPassword ? Icons.visibility_off : Icons.visibility,
              color: _focused ? Colors.black : Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
