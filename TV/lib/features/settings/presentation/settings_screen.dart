import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/utils/responsive_utils.dart';
import 'package:auris_core/auris_core.dart';
import '../../avatar/presentation/providers/avatar_providers.dart';
import 'providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(sourcesProvider);
    const primaryColor = Color(0xFFEF7A1E);
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: const Color(0xFF0B0B0D),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // SECCIÓN: CUENTA
              const _SectionHeader(title: 'Cuenta'),
              _SettingsCard(
                child: Consumer(builder: (context, ref, child) {
                  final user = ref.watch(authProvider);
                  final bool isLoggedIn = user != null && user.email != null;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.push('/settings/avatar'),
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundColor: Colors.white10,
                                    backgroundImage: (user?.photoUrl != null)
                                        ? (user!.photoUrl!.startsWith('assets/')
                                            ? AssetImage(user.photoUrl!) as ImageProvider
                                            : CachedNetworkImageProvider(user.photoUrl!))
                                        : null,
                                    child: (user?.photoUrl == null)
                                        ? const Icon(Icons.person_rounded, color: Colors.white70, size: 32)
                                        : null,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit, size: 14, color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isLoggedIn ? (user.displayName ?? user.email!) : 'Invitado',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    isLoggedIn ? 'Sesión iniciada' : 'Inicia sesión para sincronizar',
                                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            if (isLoggedIn)
                              IconButton(
                                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                                onPressed: () => _showLogoutDialog(context, ref),
                              )
                            else
                              ElevatedButton(
                                onPressed: () => context.push('/login'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: const Text('Entrar', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white10),
                      _SettingsTile(
                        icon: Icons.switch_account_outlined,
                        title: 'Cambiar Perfil',
                        subtitle: 'Seleccionar otro integrante',
                        onTap: () => context.push('/select-profile'),
                      ),
                      _SettingsTile(
                        icon: Icons.hub_outlined,
                        title: 'Conexiones Externas',
                        subtitle: 'AniList, Simkl y más',
                        onTap: () => context.push('/connections'),
                      ),
                      _SettingsTile(
                        icon: Icons.video_library_outlined,
                        title: 'Mi espacio',
                        subtitle: 'Favoritos, historial y más',
                        onTap: () => context.push('/settings/library'),
                      ),
                    ],
                  );
                }),
              ),

              // SECCIÓN: REPRODUCCIÓN
              const _SectionHeader(title: 'Reproducción'),
              _SettingsCard(
                child: Column(
                  children: [
                    const _SettingsTile(
                      icon: Icons.high_quality_outlined,
                      title: 'Calidad de reproducción',
                      subtitle: 'Automático',
                    ),
                    _SettingsTile(
                      icon: Icons.language_outlined,
                      title: 'Idioma / subtítulos',
                      subtitle: 'Español',
                      onTap: () => _showLanguageDialog(context, ref),
                    ),
                  ],
                ),
              ),

              // SECCIÓN: FUENTES
              const _SectionHeader(title: 'Fuentes de contenido'),
              _SettingsCard(
                child: sourcesAsync.when(
                  data: (sources) {
                    if (isMobile) {
                      return Column(
                        children: sources.map((s) => _SettingsTile(
                          icon: Icons.link_outlined,
                          title: s.name,
                          subtitle: s.description,
                        )).toList(),
                      );
                    }
                    // Grid para Desktop/Web
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 3.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: sources.length,
                        itemBuilder: (context, index) {
                          final s = sources[index];
                          return ListTile(
                            leading: const Icon(Icons.link_outlined, color: primaryColor),
                            title: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            subtitle: Text(s.description, 
                              maxLines: 1, 
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            dense: true,
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(color: primaryColor)),
                  ),
                  error: (err, _) => _SettingsTile(
                    icon: Icons.error_outline,
                    title: 'Error al cargar fuentes',
                    subtitle: err.toString(),
                  ),
                ),
              ),

              // SECCIÓN: SISTEMA
              const _SectionHeader(title: 'Almacenamiento'),
              const _SettingsCard(
                child: _SettingsTile(
                  icon: Icons.storage_outlined,
                  title: 'Almacenamiento y caché',
                  subtitle: 'Gestionar datos locales',
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('Idioma / subtítulos', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOptionTile(
              label: 'English',
              isSelected: false,
              onTap: () => Navigator.pop(context),
            ),
            _LanguageOptionTile(
              label: 'Español',
              isSelected: true,
              onTap: () => Navigator.pop(context),
            ),
            _LanguageOptionTile(
              label: 'Español Latinoamerica',
              isSelected: false,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de que quieres cerrar tu sesión de AurisTV?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).signOut();
            },
            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: const Color(0xFF1A1D24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    
    return ListTile(
      leading: Icon(icon, color: primaryColor, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded, color: Colors.white24) : null),
      onTap: onTap,
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFFEF7A1E) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected 
          ? const Icon(Icons.check_circle, color: Color(0xFFEF7A1E), size: 20) 
          : null,
      onTap: onTap,
    );
  }
}
