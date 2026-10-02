import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────
//  Screen entry point
// ─────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginStep {
  welcome,  // Crunchyroll-style landing
  qrPhone,  // QR code flow
  remote,   // D-PAD keyboard flow
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
  final FocusNode _loginBtnFocus  = FocusNode();
  final FocusNode _remoteBtnFocus = FocusNode();
  final FocusNode _backBtnFocus   = FocusNode();

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
    _remoteBtnFocus.dispose();
    _backBtnFocus.dispose();
    super.dispose();
  }

  void _startActivationPolling() {
    _pollTimer?.cancel();
    // Refresh activation code on each step entry
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
            content: Text('Dispositivo activado con éxito! Iniciando sesión...'),
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

  void _goToStep(_LoginStep step) {
    _fadeCtrl.reset();
    setState(() => _step = step);
    _fadeCtrl.forward();

    if (step == _LoginStep.qrPhone) {
      _startActivationPolling();
    } else {
      _stopActivationPolling();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _backBtnFocus.requestFocus();
    });
  }

  void _goBack() {
    if (_step != _LoginStep.welcome) {
      _goToStep(_LoginStep.welcome);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loginBtnFocus.requestFocus();
      });
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
            // Full screen background image
            Positioned.fill(
              child: Image.asset(
                'assets/icons/login_bg.jpg',
                fit: BoxFit.cover,
              ),
            ),

            // Subtle ambient shadow on left side only to ensure white text pops crisp
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

            // Mascot PNG (transparent bg) right side
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: size.width * 0.52,
              child: _MascotPanel(step: _step),
            ),

            // ── Content – left half ──
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

                    // Header: Back Button (if active) + Logo
                    Row(
                      children: [
                        if (_step != _LoginStep.welcome) ...[
                          _CircleBackButton(
                            focusNode: _backBtnFocus,
                            onPressed: _goBack,
                          ),
                          const SizedBox(width: 18),
                        ],
                        SvgPicture.asset(
                          'assets/icons/auris-logo-web-flat.svg',
                          height: 38,
                          alignment: Alignment.centerLeft,
                        ),
                      ],
                    ),

                    const Spacer(flex: 2),

                    // Step content with slide+fade transition
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.07),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOut,
                            )),
                            child: child,
                          ),
                        );
                      },
                      child: _buildStepContent(),
                    ),

                    const Spacer(flex: 3),

                    // Legal footer
                    Padding(
                      padding: const EdgeInsets.only(bottom: 36),
                      child: Text(
                        'Al usar AurisTV aceptas nuestros Terminos de Uso y Politica de Privacidad.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.26),
                          fontSize: 12,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),


          ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  Widget _buildStepContent() {
    switch (_step) {
      case _LoginStep.welcome:
        return _buildWelcomeStep();
      case _LoginStep.qrPhone:
        return _buildQRStep();
      case _LoginStep.remote:
        return _buildRemoteStep();
    }
  }

  // ── WELCOME ───────────────────────────────
  Widget _buildWelcomeStep() {
    return Column(
      key: const ValueKey('welcome'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Bienvenido!',
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

        // Primary – ACCEDER (QR)
        _BigButton(
          focusNode: _loginBtnFocus,
          label: 'ACCEDER',
          filled: true,
          nextFocus: _remoteBtnFocus,
          onPressed: () => _goToStep(_LoginStep.qrPhone),
        ),
        const SizedBox(height: 10),

        // Secondary – CONTROL REMOTO
        _BigButton(
          focusNode: _remoteBtnFocus,
          label: 'USAR CONTROL REMOTO',
          filled: false,
          prevFocus: _loginBtnFocus,
          onPressed: () => _goToStep(_LoginStep.remote),
        ),
      ],
    );
  }

  // ── QR / PHONE ────────────────────────────
  Widget _buildQRStep() {
    final activateUrl = 'https://auristv.dpdns.org/activate?code=$_activationCode';

    return Column(
      key: const ValueKey('qr'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Acceder a AurisTV',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // QR code - dynamic link to activate URL
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55EF7A1E),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: QrImageView(
                data: activateUrl,
                version: QrVersions.auto,
                size: 165,
              ),
            ),
            const SizedBox(width: 32),

            // Instructions - Crunchyroll style activation flow
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _StepRow(
                    n: '1',
                    text: 'Ingresa en tu navegador o escanea el QR a:',
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 38),
                    child: Text(
                      'auristv.dpdns.org/activate',
                      style: TextStyle(
                        color: AppTheme.brand,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _StepRow(
                    n: '2',
                    text: 'Introduce este codigo de activacion:',
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
                        style: TextStyle(
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
                    text: 'Permanece en esta pantalla y la TV iniciara sesion automaticamente.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── REMOTE / KEYBOARD ─────────────────────
  Widget _buildRemoteStep() {
    return Column(
      key: const ValueKey('remote'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Iniciar sesion',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 24),

        // Email
        _TVInputField(
          label: 'Correo electronico',
          controller: _emailController,
          icon: Icons.email_outlined,
          isActive: _activeController == _emailController,
          onFocused: () =>
              setState(() => _activeController = _emailController),
        ),
        const SizedBox(height: 12),

        // Password
        _TVInputField(
          label: 'Contrasena',
          controller: _passwordController,
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          isActive: _activeController == _passwordController,
          onFocused: () =>
              setState(() => _activeController = _passwordController),
        ),
        const SizedBox(height: 24),

        // Keyboard
        _TVKeyboard(
          onKey: (k) {
            setState(() {
              final ctrl = _activeController!;
              if (k == '⌫') {
                if (ctrl.text.isNotEmpty) {
                  ctrl.text = ctrl.text.substring(0, ctrl.text.length - 1);
                }
              } else {
                ctrl.text += k;
              }
            });
          },
          onConfirm: () {
            // TODO: call auth provider login
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Mascot panel (right side)
// ─────────────────────────────────────────────
class _MascotPanel extends StatelessWidget {
  final _LoginStep step;
  const _MascotPanel({required this.step});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: step == _LoginStep.welcome ? 1.0 : 0.25,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Image.asset(
        'assets/icons/login_mascot.png',
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Big welcome button (ACCEDER / CONTROL REMOTO)
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
//  Circular back button
// ─────────────────────────────────────────────
class _CircleBackButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;
  const _CircleBackButton({required this.focusNode, required this.onPressed});

  @override
  State<_CircleBackButton> createState() => _CircleBackButtonState();
}

class _CircleBackButtonState extends State<_CircleBackButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _focused
                ? Colors.white.withOpacity(0.18)
                : Colors.white.withOpacity(0.08),
            border: Border.all(
              color: _focused ? Colors.white : Colors.white24,
              width: _focused ? 2 : 1.5,
            ),
          ),
          child: Center(
            child: AurisIcon(AurisIcons.chevronLeft,
                color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  QR step row  (number + text)
// ─────────────────────────────────────────────
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
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.brand.withOpacity(0.18),
            border: Border.all(color: AppTheme.brand, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            n,
            style: TextStyle(
              color: AppTheme.brand,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  TV input field  (D-PAD selectable)
// ─────────────────────────────────────────────
class _TVInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool isPassword;
  final bool isActive;
  final VoidCallback onFocused;

  const _TVInputField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.isActive,
    required this.onFocused,
    this.isPassword = false,
  });

  @override
  State<_TVInputField> createState() => _TVInputFieldState();
}

class _TVInputFieldState extends State<_TVInputField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.isPassword
        ? '•' * widget.controller.text.length
        : widget.controller.text;

    return Focus(
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f) widget.onFocused();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 52,
        decoration: BoxDecoration(
          color: _focused
              ? Colors.white.withOpacity(0.10)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _focused ? AppTheme.brand : Colors.white24,
            width: _focused ? 2.0 : 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(widget.icon,
                color: _focused ? AppTheme.brand : Colors.white38,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text.isEmpty ? widget.label : text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text.isEmpty ? Colors.white38 : Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
            // Active indicator
            if (widget.isActive)
              Container(
                width: 2,
                height: 18,
                color: AppTheme.brand,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TV on-screen keyboard
// ─────────────────────────────────────────────
class _TVKeyboard extends StatefulWidget {
  final void Function(String key) onKey;
  final VoidCallback onConfirm;
  const _TVKeyboard({required this.onKey, required this.onConfirm});

  @override
  State<_TVKeyboard> createState() => _TVKeyboardState();
}

class _TVKeyboardState extends State<_TVKeyboard> {
  bool _caps = false;

  static const _rows = [
    ['1','2','3','4','5','6','7','8','9','0'],
    ['q','w','e','r','t','y','u','i','o','p'],
    ['a','s','d','f','g','h','j','k','l','⌫'],
    ['⇧','z','x','c','v','b','n','m','.','@'],
    ['ESPACIO', 'ACEPTAR'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: row.map((k) {
              final isBS     = k == '⌫';
              final isCaps   = k == '⇧';
              final isSpace  = k == 'ESPACIO';
              final isOk     = k == 'ACEPTAR';
              final label    = (!isBS && !isCaps && !isSpace && !isOk && _caps)
                  ? k.toUpperCase() : k;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: _Key(
                  label: label,
                  isSpecial: isBS || isCaps,
                  isOk: isOk,
                  isSpace: isSpace,
                  onPressed: () {
                    if (isCaps) {
                      setState(() => _caps = !_caps);
                    } else if (isSpace) {
                      widget.onKey(' ');
                    } else if (isOk) {
                      widget.onConfirm();
                    } else {
                      widget.onKey(_caps ? k.toUpperCase() : k);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _Key extends StatefulWidget {
  final String label;
  final bool isSpecial;
  final bool isOk;
  final bool isSpace;
  final VoidCallback onPressed;

  const _Key({
    required this.label,
    required this.onPressed,
    this.isSpecial = false,
    this.isOk      = false,
    this.isSpace    = false,
  });

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.isSpace
        ? 130.0
        : widget.isOk
            ? 84.0
            : widget.isSpecial
                ? 46.0
                : 36.0;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter  ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: w,
          height: 36,
          decoration: BoxDecoration(
            color: widget.isOk
                ? (_focused ? AppTheme.brandLight : AppTheme.brand)
                : _focused
                    ? Colors.white
                    : Colors.white.withOpacity(0.09),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: _focused ? Colors.white : Colors.white.withOpacity(0.18),
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isOk
                  ? Colors.white
                  : _focused ? Colors.black : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
