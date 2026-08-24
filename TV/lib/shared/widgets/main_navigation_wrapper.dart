import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auris_core/auris_core.dart';

/// Senior TV Wrapper: Solo mantiene la lógica de pantalla grande y navegación.
/// En TV, el dispositivo actúa únicamente como receptor de comandos.
class MainNavigationWrapper extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationWrapper({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends ConsumerState<MainNavigationWrapper> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: widget.navigationShell,
    );
  }
}
