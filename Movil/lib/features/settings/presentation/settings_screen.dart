import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/utils/responsive_utils.dart';
import 'package:auris_core/auris_core.dart';
import '../../avatar/presentation/providers/avatar_providers.dart';
import 'providers/settings_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(sourcesProvider);
    final settings = ref.watch(settingsProvider);
    const primaryColor = Color(0xFFEF7A1E);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
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
                    _SettingsTile(
                      icon: Icons.high_quality_outlined,
                      title: 'Calidad de reproducción',
                      subtitle: settings.preferredQuality.toUpperCase(),
                      onTap: () => _showQualityDialog(context, ref),
                    ),
                    _SettingsTile(
                      icon: Icons.language_outlined,
                      title: 'Idioma preferido',
                      subtitle: settings.preferredLanguage.toUpperCase(),
                      onTap: () => _showLanguageDialog(context, ref),
                    ),
                    SwitchListTile(
                      activeColor: primaryColor,
                      secondary: const Icon(Icons.play_circle_outline, color: primaryColor),
                      title: const Text('Auto-reproducir trailers', style: TextStyle(color: Colors.white, fontSize: 15)),
                      value: settings.autoPlayTrailers,
                      onChanged: (v) => ref.read(settingsProvider.notifier).setAutoPlayTrailers(v),
                    ),
                    SwitchListTile(
                      activeColor: primaryColor,
                      secondary: const Icon(Icons.next_plan_outlined, color: primaryColor),
                      title: const Text('Auto-reproducir siguiente episodio', style: TextStyle(color: Colors.white, fontSize: 15)),
                      value: settings.autoPlayNextEpisode,
                      onChanged: (v) => ref.read(settingsProvider.notifier).setAutoPlayNextEpisode(v),
                    ),
                  ],
                ),
              ),

              // SECCIÓN: SUBTÍTULOS
              const _SectionHeader(title: 'Subtítulos'),
              _SettingsCard(
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.format_size,
                      title: 'Tamaño de fuente',
                      subtitle: '${(settings.subtitleSize * 100).toInt()}%',
                      onTap: () => _showSubtitleSizeDialog(context, ref),
                    ),
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      title: 'Color de subtítulos',
                      subtitle: 'Personalizar color',
                      onTap: () => _showSubtitleColorDialog(context, ref),
                    ),
                  ],
                ),
              ),

              // SECCIÓN: FUENTES
              const _SectionHeader(title: 'Fuentes de contenido'),
              _SettingsCard(
                child: sourcesAsync.when(
                  data: (sources) {
                    return Column(
                      children: sources.map((s) => _SettingsTile(
                        icon: Icons.link_outlined,
                        title: s.name,
                        subtitle: s.description,
                      )).toList(),
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
              _SettingsCard(
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.storage_outlined,
                      title: 'Almacenamiento y caché',
                      subtitle: 'Gestionar datos locales',
                      onTap: () {},
                    ),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        final version = snapshot.hasData ? 'v${snapshot.data!.version}' : 'v1.0.0';
                        return _SettingsTile(
                          icon: Icons.info_outline,
                          title: 'Versión',
                          subtitle: version,
                          onTap: () {},
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showQualityDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final options = ['auto', '1080p', '720p', '480p'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('Calidad de reproducción', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((o) => _OptionTile(
            label: o.toUpperCase(),
            isSelected: settings.preferredQuality == o,
            onTap: () {
              ref.read(settingsProvider.notifier).setPreferredQuality(o);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final options = ['latino', 'subtitulado', 'castellano'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('Idioma preferido', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((o) => _OptionTile(
            label: o.toUpperCase(),
            isSelected: settings.preferredLanguage == o,
            onTap: () {
              ref.read(settingsProvider.notifier).setPreferredLanguage(o);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showSubtitleSizeDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final sizes = [0.8, 1.0, 1.2, 1.5];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('Tamaño de fuente', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: sizes.map((s) => _OptionTile(
            label: '${(s * 100).toInt()}%',
            isSelected: settings.subtitleSize == s,
            onTap: () {
              ref.read(settingsProvider.notifier).setSubtitleSize(s);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showSubtitleColorDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final colors = [
      {'name': 'Blanco', 'value': 0xFFFFFFFF},
      {'name': 'Amarillo', 'value': 0xFFFFFF00},
      {'name': 'Cian', 'value': 0xFF00FFFF},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('Color de subtítulos', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: colors.map((c) => _OptionTile(
            label: c['name'] as String,
            isSelected: settings.subtitleColor == c['value'],
            onTap: () {
              ref.read(settingsProvider.notifier).setSubtitleColor(c['value'] as int);
              Navigator.pop(context);
            },
          )).toList(),
        ),
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

class _OptionTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
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
