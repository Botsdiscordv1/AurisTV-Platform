import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_utils.dart';

class ActivateScreen extends ConsumerStatefulWidget {
  final String initialCode;
  const ActivateScreen({super.key, this.initialCode = ''});

  @override
  ConsumerState<ActivateScreen> createState() => _ActivateScreenState();
}

class _ActivateScreenState extends ConsumerState<ActivateScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode.isNotEmpty) {
      final clean = widget.initialCode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
      for (int i = 0; i < clean.length && i < 6; i++) {
        _controllers[i].text = clean[i];
      }
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _fullCode => _controllers.map((c) => c.text).join().toUpperCase();

  void _handleCodeInput(int index, String val) {
    final clean = val.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

    if (clean.length >= 4) {
      final startIdx = clean.length >= 6 ? 0 : index;
      for (int i = 0; i < clean.length && (startIdx + i) < 6; i++) {
        _controllers[startIdx + i].text = clean[i];
      }
      final nextFocus = (startIdx + clean.length).clamp(0, 5);
      if (startIdx + clean.length >= 6) {
        _focusNodes[5].unfocus();
      } else {
        _focusNodes[nextFocus].requestFocus();
      }
    } else if (clean.length > 1) {
      final newChar = clean[clean.length - 1];
      _controllers[index].text = newChar;
      _controllers[index].selection = TextSelection.fromPosition(
        const TextPosition(offset: 1),
      );
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (clean.length == 1) {
      _controllers[index].text = clean;
      _controllers[index].selection = TextSelection.fromPosition(
        const TextPosition(offset: 1),
      );
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else {
      _controllers[index].text = '';
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  Future<void> _submitCode() async {
    final code = _fullCode;
    if (code.length < 6) {
      setState(() => _errorMessage = 'Por favor ingresa los 6 caracteres del código.');
      return;
    }

    final user = ref.read(authProvider);
    if (user == null || user.id == 'guest_user') {
      setState(() => _errorMessage = 'Debes iniciar sesión para activar este dispositivo.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await DeviceActivationService.activateDevice(code, user);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          _isSuccess = true;
        } else {
          _errorMessage = 'Error activando dispositivo. Verifica el código e intenta de nuevo.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isLoggedIn = user != null && user.id != 'guest_user';
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/inicio'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 32,
              vertical: isMobile ? 24 : 32,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                ),
              ],
            ),
            child: _isSuccess
                ? _buildSuccessView(isMobile)
                : (!isLoggedIn ? _buildLoginRequiredView(isMobile) : _buildActivationForm(isMobile)),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginRequiredView(bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.tv, size: isMobile ? 44 : 54, color: AppTheme.brand),
        SizedBox(height: isMobile ? 12 : 16),
        Text(
          'Activar Tu Dispositivo',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Debes iniciar sesión en tu cuenta de AurisTV para dar acceso a tu televisor.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: isMobile ? 13 : 14),
        ),
        SizedBox(height: isMobile ? 20 : 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final redirect = Uri.encodeComponent('/activate?code=${widget.initialCode}');
              context.go('/login?redirect=$redirect');
            },
            child: const Text(
              'INICIAR SESIÓN',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivationForm(bool isMobile) {
    final boxSpacing = isMobile ? 6.0 : 12.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.tv_rounded, size: isMobile ? 44 : 54, color: AppTheme.brand),
        SizedBox(height: isMobile ? 12 : 16),
        Text(
          'Activar Tu Dispositivo',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Introduce el código de 6 caracteres que aparece en la pantalla de tu TV.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: isMobile ? 13 : 14),
        ),
        SizedBox(height: isMobile ? 20 : 28),

        // 6 Character Boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return [
              if (index > 0) SizedBox(width: boxSpacing),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 50,
                    maxHeight: 60,
                  ),
                  child: AspectRatio(
                    aspectRatio: 0.83,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFF1F1F23),
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.brand, width: 2),
                        ),
                      ),
                      onChanged: (val) => _handleCodeInput(index, val),
                    ),
                  ),
                ),
              ),
            ];
          }).expand((element) => element).toList(),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],

        SizedBox(height: isMobile ? 20 : 28),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _isLoading ? null : _submitCode,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                  )
                : const Text(
                    'ACTIVAR DISPOSITIVO',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline_rounded, size: isMobile ? 56 : 68, color: Colors.greenAccent),
        SizedBox(height: isMobile ? 14 : 18),
        Text(
          '¡Dispositivo Activado!',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tu televisor ha iniciado sesión correctamente. Ya puedes disfrutar de AurisTV.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: isMobile ? 13 : 14),
        ),
        SizedBox(height: isMobile ? 20 : 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => context.go('/inicio'),
            child: const Text(
              'VOLVER AL INICIO',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
