import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/theme/app_theme.dart';

class ActivateScreen extends ConsumerStatefulWidget {
  final String initialCode;
  const ActivateScreen({super.key, this.initialCode = ''});

  @override
  ConsumerState<ActivateScreen> createState() => _ActivateScreenState();
}

class _ActivateScreenState extends ConsumerState<ActivateScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _confirmActivation(String code) async {
    final user = ref.read(authProvider);
    if (user == null || user.id == 'guest_user') {
      final redirect = Uri.encodeComponent('/activate?code=$code');
      context.go('/login?redirect=$redirect');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await DeviceActivationService.activateDevice(code, user);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Televisor vinculado con éxito!'),
            backgroundColor: Color(0xFFEF7A1E),
          ),
        );
        context.go('/inicio');
      } else {
        setState(() => _errorMessage = 'No se pudo vincular. Intenta de nuevo.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isLoggedIn = user != null && user.id != 'guest_user';
    final code = widget.initialCode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.75),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: const Color(0xFF222226),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 28,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Mascot / TV Header Banner
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 130,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFEF7A1E), Color(0xFFC85F0D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tv_rounded, size: 54, color: Colors.white),
                        ],
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 24),
                          onPressed: () => context.go('/inicio'),
                        ),
                      ),
                    ],
                  ),

                  // Popup Confirmation Body
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '¿Vincular televisor a tu cuenta?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Se iniciará sesión automáticamente en tu TV.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Action Button 1: VINCULAR DISPOSITIVO
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.brand,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : () => _confirmActivation(code),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    isLoggedIn ? 'Vincular Dispositivo' : 'Iniciar Sesión y Vincular',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Action Button 2: CANCELAR
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.brand, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => context.go('/inicio'),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
