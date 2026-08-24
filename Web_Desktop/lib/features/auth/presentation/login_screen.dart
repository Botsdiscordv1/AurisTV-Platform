import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLogoHovered = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final double formWidth = isMobile ? double.infinity : 400.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: SizedBox(
            width: formWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MouseRegion(
                  onEnter: (_) => setState(() => _isLogoHovered = true),
                  onExit: (_) => setState(() => _isLogoHovered = false),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.go('/'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: SvgPicture.asset(
                        'assets/icons/auris-logo-web-flat.svg',
                        height: 42,
                        colorFilter: ColorFilter.mode(
                          _isLogoHovered ? const Color(0xFFF5F5F5) : const Color(0xFFEF7A1E), 
                          BlendMode.srcIn
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 100), // Aumentado para bajar el bloque del formulario
                const Text(
                  'Acceder',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),
                _buildCrunchyField(
                  label: 'Dirección de email',
                  controller: _emailController,
                ),
                const SizedBox(height: 24),
                _buildCrunchyField(
                  label: 'Contraseña',
                  controller: _passwordController,
                  isPassword: true,
                ),
                const SizedBox(height: 48),
                
                // Botón Acceder (Estilo Crunchyroll)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      // Implementar login manual si es necesario
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24, width: 2),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'ACCEDER',
                      style: TextStyle(
                        color: Colors.white24, // Deshabilitado visualmente por ahora
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Footer Links
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FooterLink(label: '¿OLVIDASTE TU CONTRASEÑA?', onTap: () {}),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('|', style: TextStyle(color: Colors.white24)),
                    ),
                    _FooterLink(label: 'CREAR CUENTA', onTap: () {}),
                  ],
                ),
                
                const SizedBox(height: 48),
                const Text(
                  'O CONECTAR CON',
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 24),
                
                // Botón Google (Social Login)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
                    icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg', height: 20, errorBuilder: (_, __, ___) => const Icon(Icons.login)),
                    label: const Text('GOOGLE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCrunchyField({
    required String label,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword,
          cursorColor: const Color(0xFFEF7A1E),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24, width: 1),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFEF7A1E), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ],
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
