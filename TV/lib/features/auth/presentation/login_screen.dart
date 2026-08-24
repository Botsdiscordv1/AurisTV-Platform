import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/theme/app_theme.dart';

enum LoginMode { phone, remote }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  LoginMode _currentMode = LoginMode.phone;
  bool _isLogoHovered = false;
  TextEditingController? _activeController;

  @override
  void initState() {
    super.initState();
    _activeController = _emailController;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              AppTheme.brand.withOpacity(0.08),
              Colors.black,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Logo top right
            Positioned(
              top: 40,
              right: 60,
              child: MouseRegion(
                onEnter: (_) => setState(() => _isLogoHovered = true),
                onExit: (_) => setState(() => _isLogoHovered = false),
                child: GestureDetector(
                  onTap: () => context.go('/'),
                  child: SvgPicture.asset(
                    'assets/icons/auris-logo-web-flat.svg',
                    height: 35,
                    colorFilter: ColorFilter.mode(
                      _isLogoHovered ? AppTheme.brandLight : AppTheme.brand,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),

            // Back button
            Positioned(
              top: 40,
              left: 40,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  onPressed: () => context.pop(),
                ),
              ),
            ),

            // Main Content
            Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(40, 42, 40, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Elige cómo iniciar sesión',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 38), // Ajustado para mantener proporción
                    
                    // Segmented Control (Unified Capsule)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildUnifiedToggleButton(
                            label: 'Usar Teléfono',
                            isSelected: _currentMode == LoginMode.phone,
                            onPressed: () => setState(() => _currentMode = LoginMode.phone),
                          ),
                          _buildUnifiedToggleButton(
                            label: 'Usar Control',
                            isSelected: _currentMode == LoginMode.remote,
                            onPressed: () => setState(() => _currentMode = LoginMode.remote),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40), // Reducido de 50

                    // Mode content
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _currentMode == LoginMode.phone 
                        ? _buildPhoneLogin() 
                        : _buildRemoteLogin(),
                    ),

                    const SizedBox(height: 40),

                    // Footer integrado en el scroll para evitar solapamientos
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '¿Necesitas ayuda?',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          Text(
                            'Visita http://help.auristv.com',
                            style: TextStyle(color: AppTheme.brand.withOpacity(0.8), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && 
            (event.logicalKey == LogicalKeyboardKey.enter || 
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final bool isFocused = Focus.of(context).hasFocus;
          
          return GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : (isFocused ? Colors.white.withOpacity(0.15) : Colors.transparent),
                borderRadius: BorderRadius.circular(25),
                border: isFocused && !isSelected ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ] : [],
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : (isFocused ? Colors.white : Colors.white70),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildPhoneLogin() {
    return Row(
      key: const ValueKey('phone_login'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step 1
        SizedBox(
          width: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4), // Senior Fix: Alineación visual
                    child: _buildStepNumber('1'),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Text(
                      'Apunta con la cámara de tu teléfono o tablet a este código, o ve a auristv.com/tv9',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20), // Reducido de 24
              Padding(
                padding: const EdgeInsets.only(left: 47),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: 'https://auristv.com/tv9?code=47519766',
                    version: QrVersions.auto,
                    size: 160.0, // Reducido de 180 para asegurar visibilidad
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 60),

        // Step 2
        SizedBox(
          width: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4), // Senior Fix: Alineación visual
                    child: _buildStepNumber('2'),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Text(
                      'Confirma este código en tu teléfono o tablet',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40), // Reducido de 50
              const Padding(
                padding: EdgeInsets.only(left: 47),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '4751-9766',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 56, // Reducido de 60
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
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

  Widget _buildRemoteLogin() {
    return Row(
      key: const ValueKey('remote_login'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna Izquierda: Teclado Virtual
        SizedBox(
          width: 460, // Reducido de 500
          child: Column(
            children: [
              _buildVirtualKeyboard(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildKeyboardButton(
                      label: 'Atrás',
                      onPressed: () => setState(() => _currentMode = LoginMode.phone),
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildKeyboardButton(
                      label: 'Siguiente',
                      onPressed: () {
                        // Lógica de siguiente paso
                      },
                      isPrimary: true,
                      height: 48,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildTextActionButton('¿Olvidaste tu contraseña?'),
                  const SizedBox(width: 20),
                  _buildRememberEmail(),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 40), // Reducido de 60

        // Columna Derecha: Campos de entrada
        SizedBox(
          width: 320, // Reducido de 400
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildRemoteInputLabel('Dirección de email'),
              _buildRemoteInputField(
                controller: _emailController,
              ),
              const SizedBox(height: 24),
              _buildRemoteInputLabel('Contraseña (4-60 caracteres)'),
              _buildRemoteInputField(
                controller: _passwordController,
                isPassword: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVirtualKeyboard() {
    final List<List<String>> keys = [
      ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
      ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', '-'],
      ['shift', 'z', 'x', 'c', 'v', 'b', 'n', 'm', '_'],
    ];

    final List<String> domains = ['@hotmail.com', '@gmail.com', '@yahoo.com'];
    final List<String> bottomKeys = ['!#\$', '@', '.', '.com', 'del'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          ...keys.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: row.map((key) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _buildKey(key),
                ),
              )).toList(),
            ),
          )),
          // Fila de dominios
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: domains.map((domain) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _buildKey(domain, isSmall: true),
                ),
              )).toList(),
            ),
          ),
          // Fila inferior
          Row(
            children: bottomKeys.map((key) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _buildKey(key),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String label, {bool isSmall = false}) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && 
            (event.logicalKey == LogicalKeyboardKey.enter || 
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          _handleKeyPress(label);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final bool isFocused = Focus.of(context).hasFocus;

          return GestureDetector(
            onTap: () => _handleKeyPress(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: 40, // Reducido de 45
              decoration: BoxDecoration(
                color: isFocused ? Colors.white : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: isFocused ? Border.all(color: AppTheme.brand, width: 2) : null,
              ),
              alignment: Alignment.center,
              child: label == 'del' 
                ? Icon(Icons.backspace_outlined, color: isFocused ? Colors.black : Colors.white, size: 16)
                : label == 'shift'
                ? Icon(Icons.arrow_upward_rounded, color: isFocused ? Colors.black : Colors.white, size: 16)
                : Text(
                    label,
                    style: TextStyle(
                      color: isFocused ? Colors.black : Colors.white,
                      fontSize: isSmall ? 11 : 14, // Reducido de 12/16
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            ),
          );
        }
      ),
    );
  }

  void _handleKeyPress(String key) {
    if (_activeController == null) return;

    setState(() {
      if (key == 'del') {
        if (_activeController!.text.isNotEmpty) {
          _activeController!.text = _activeController!.text.substring(0, _activeController!.text.length - 1);
        }
      } else if (key == 'shift') {
        // Lógica de Shift (Mayúsculas) opcional
      } else {
        _activeController!.text += key;
      }
    });
  }

  Widget _buildKeyboardButton({
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
    double height = 50,
  }) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppTheme.brand : Colors.white.withOpacity(0.1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildRemoteInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 16, // Reducido de 18
        ),
      ),
    );
  }

  Widget _buildRemoteInputField({
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return Focus(
      onFocusChange: (focused) {
        if (focused) {
          setState(() => _activeController = controller);
        }
      },
      child: Builder(
        builder: (context) {
          final bool isFocused = Focus.of(context).hasFocus;
          final bool isActive = _activeController == controller;

          return Container(
            height: 50, // Reducido de 55
            decoration: BoxDecoration(
              color: isFocused ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isFocused ? AppTheme.brand : (isActive ? AppTheme.brand.withOpacity(0.3) : Colors.transparent),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            child: Text(
              isPassword 
                ? (controller.text.isEmpty ? '' : '•' * controller.text.length)
                : controller.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16), // Reducido de 18
            ),
          );
        }
      ),
    );
  }

  Widget _buildTextActionButton(String label) {
    return Focus(
      child: Builder(
        builder: (context) {
          final bool isFocused = Focus.of(context).hasFocus;

          return InkWell(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isFocused ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
                border: isFocused ? Border.all(color: Colors.white, width: 1) : null,
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildRememberEmail() {
    return Focus(
      child: Builder(
        builder: (context) {
          final bool isFocused = Focus.of(context).hasFocus;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.brand,
                  borderRadius: BorderRadius.circular(4),
                  border: isFocused ? Border.all(color: Colors.white, width: 2) : null,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Recordar email',
                style: TextStyle(
                  color: isFocused ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildStepNumber(String number) {
    return Container(
      width: 28, // Reducido de 32
      height: 28, // Reducido de 32
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.12),
      ),
      alignment: Alignment.center,
      child: Text(
        number,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14, // Reducido de 16
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.surface.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.brand, width: 2),
        ),
      ),
    );
  }
}
