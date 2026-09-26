import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_ce/hive_ce.dart';

import 'package:auris_core/auris_core.dart';
import 'providers/settings_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedCategoryIndex = 0;
  final List<String> _categories = [
    'Cuenta',
    'Reproducción',
    'Subtítulos',
    'Fuentes',
    'Sistema',
  ];

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: Row(
        children: [
          // BARRA LATERAL DE CATEGORÍAS
          Container(
            width: 300,
            color: const Color(0xFF0B0B0D),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 10, bottom: 30),
                  child: Text(
                    'AJUSTES',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedCategoryIndex == index;
                      return _CategoryTile(
                        label: _categories[index],
                        isSelected: isSelected,
                        onTap: () => setState(() => _selectedCategoryIndex = index),
                      );
                    },
                  ),
                ),
                _CategoryTile(
                  label: 'Cerrar sesión',
                  isSelected: false,
                  icon: Icons.logout_rounded,
                  color: Colors.redAccent.withOpacity(0.7),
                  onTap: () => _showLogoutDialog(context, ref),
                ),
              ],
            ),
          ),

          // LÍNEA DIVISORIA
          Container(width: 1, color: Colors.white.withOpacity(0.05)),

          // CONTENIDO DE LA CATEGORÍA SELECCIONADA
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 80),
              child: _buildCategoryContent(settings),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryContent(UserSettings settings) {
    switch (_selectedCategoryIndex) {
      case 0: return _buildAccountCategory();
      case 1: return _buildPlaybackCategory(settings);
      case 2: return _buildSubtitlesCategory(settings);
      case 3: return _buildSourcesCategory();
      case 4: return _buildSystemCategory();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildAccountCategory() {
    final user = ref.watch(authProvider);
    final bool isLoggedIn = user != null && user.email != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryHeader(title: 'Gestión de Cuenta'),
        const SizedBox(height: 30),
        Row(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white10,
              backgroundImage: (user?.photoUrl != null)
                  ? (user!.photoUrl!.startsWith('assets/')
                      ? AssetImage(user.photoUrl!) as ImageProvider
                      : CachedNetworkImageProvider(user.photoUrl!))
                  : null,
              child: (user?.photoUrl == null)
                  ? const Icon(Icons.person_rounded, color: Colors.white70, size: 50)
                  : null,
            ),
            const SizedBox(width: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn ? (user.displayName ?? user.email!) : 'Modo Invitado',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Text(
                  isLoggedIn ? user.email! : 'Inicia sesión para sincronizar favoritos e historial',
                  style: const TextStyle(color: Colors.white54, fontSize: 18),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 50),
        _SettingsTVButton(
          label: 'Cambiar Perfil',
          icon: Icons.switch_account_outlined,
          onTap: () => context.push('/select-profile'),
        ),
        _SettingsTVButton(
          label: 'Conexiones Externas (AniList/MAL)',
          icon: Icons.hub_outlined,
          onTap: () => context.push('/connections'),
        ),
        if (!isLoggedIn)
          _SettingsTVButton(
            label: 'Iniciar sesión ahora',
            icon: Icons.login_rounded,
            primary: true,
            onTap: () => context.push('/login'),
          ),
      ],
    );
  }

  Widget _buildPlaybackCategory(UserSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryHeader(title: 'Preferencias de Reproducción'),
        const SizedBox(height: 30),
        _SettingsTVSelector(
          label: 'Calidad preferida',
          value: settings.preferredQuality.toUpperCase(),
          options: const ['AUTO', '1080P', '720P', '480P'],
          onChanged: (val) => ref.read(settingsProvider.notifier).setPreferredQuality(val.toLowerCase()),
        ),
        _SettingsTVSelector(
          label: 'Idioma predeterminado',
          value: settings.preferredLanguage.toUpperCase(),
          options: const ['LATINO', 'SUBTITULADO', 'CASTELLANO'],
          onChanged: (val) => ref.read(settingsProvider.notifier).setPreferredLanguage(val.toLowerCase()),
        ),
        _SettingsTVSwitch(
          label: 'Auto-reproducir Trailers en el Inicio',
          value: settings.autoPlayTrailers,
          onChanged: (v) => ref.read(settingsProvider.notifier).setAutoPlayTrailers(v),
        ),
        _SettingsTVSwitch(
          label: 'Reproducir automáticamente el siguiente episodio',
          value: settings.autoPlayNextEpisode,
          onChanged: (v) => ref.read(settingsProvider.notifier).setAutoPlayNextEpisode(v),
        ),
      ],
    );
  }

  Widget _buildSubtitlesCategory(UserSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryHeader(title: 'Estilo de Subtítulos'),
        const SizedBox(height: 30),
        _SettingsTVSelector(
          label: 'Tamaño del texto',
          value: '${(settings.subtitleSize * 100).toInt()}%',
          options: const ['80%', '100%', '120%', '150%'],
          onChanged: (val) {
            final double size = double.parse(val.replaceAll('%', '')) / 100;
            ref.read(settingsProvider.notifier).setSubtitleSize(size);
          },
        ),
        _SettingsTVSelector(
          label: 'Color de fuente',
          value: settings.subtitleColor == 0xFFFFFFFF ? 'BLANCO' : (settings.subtitleColor == 0xFFFFFF00 ? 'AMARILLO' : 'CIAN'),
          options: const ['BLANCO', 'AMARILLO', 'CIAN'],
          onChanged: (val) {
            final int color = val == 'BLANCO' ? 0xFFFFFFFF : (val == 'AMARILLO' ? 0xFFFFFF00 : 0xFF00FFFF);
            ref.read(settingsProvider.notifier).setSubtitleColor(color);
          },
        ),
        const SizedBox(height: 40),
        // Previsualización de subtítulos
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              const Text('PREVISUALIZACIÓN', style: TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text(
                'Esta es una muestra de cómo se verán tus subtítulos.',
                style: TextStyle(
                  color: Color(settings.subtitleColor),
                  fontSize: 22 * settings.subtitleSize,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.8), offset: const Offset(2, 2), blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSourcesCategory() {
    final sourcesAsync = ref.watch(sourcesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryHeader(title: 'Servidores Disponibles'),
        const SizedBox(height: 30),
        Expanded(
          child: sourcesAsync.when(
            data: (sources) => GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 4,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: sources.length,
              itemBuilder: (context, index) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.link, color: Color(0xFFEF7A1E)),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sources[index].name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(sources[index].description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemCategory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryHeader(title: 'Almacenamiento y Sistema'),
        const SizedBox(height: 30),
        _SettingsTVButton(
          label: 'Limpiar caché local y datos',
          icon: Icons.delete_sweep_outlined,
          onTap: () async {
            await DefaultCacheManager().emptyCache();
            if (Hive.isBoxOpen('playback_history')) await Hive.box('playback_history').clear();
            if (Hive.isBoxOpen('search_history')) await Hive.box('search_history').clear();
            if (Hive.isBoxOpen('home_cache')) await Hive.box('home_cache').clear();

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('¡Caché y datos locales limpiados con éxito!')),
              );
            }
          },
        ),
        _SettingsTVButton(
          label: 'Verificar actualizaciones',
          icon: Icons.update_rounded,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('La aplicación está actualizada a la última versión')),
            );
          },
        ),
        const Spacer(),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.hasData ? 'v${snapshot.data!.version}' : 'v1.0.0';
            return Text('AurisTV $version • Auris Core v1.4.2', style: const TextStyle(color: Colors.white24, fontSize: 14));
          },
        ),
      ],
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

class _CategoryTile extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  const _CategoryTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.color,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isSelected || _focused;
    const primaryColor = Color(0xFFEF7A1E);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: active ? Colors.white.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: _focused ? Border.all(color: primaryColor, width: 2) : null,
            ),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: widget.color ?? (active ? primaryColor : Colors.white60), size: 22),
                  const SizedBox(width: 15),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.color ?? (active ? Colors.white : Colors.white60),
                    fontSize: 18,
                    fontWeight: active ? FontWeight.w900 : FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String title;
  const _CategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(color: Color(0xFFEF7A1E), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
    );
  }
}

class _SettingsTVButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _SettingsTVButton({required this.label, required this.icon, required this.onTap, this.primary = false});

  @override
  State<_SettingsTVButton> createState() => _SettingsTVButtonState();
}

class _SettingsTVButtonState extends State<_SettingsTVButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    final bool active = _focused;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            width: 500,
            decoration: BoxDecoration(
              color: widget.primary ? primaryColor : (active ? Colors.white10 : Colors.white.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(12),
              border: active ? Border.all(color: widget.primary ? Colors.white : primaryColor, width: 2) : null,
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: widget.primary ? Colors.black : (active ? primaryColor : Colors.white70)),
                const SizedBox(width: 20),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.primary ? Colors.black : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTVSelector extends StatefulWidget {
  final String label;
  final String value;
  final List<String> options;
  final Function(String) onChanged;

  const _SettingsTVSelector({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  State<_SettingsTVSelector> createState() => _SettingsTVSelectorState();
}

class _SettingsTVSelectorState extends State<_SettingsTVSelector> {
  bool _focused = false;

  void _cycle() {
    final currentIndex = widget.options.indexOf(widget.value);
    final nextIndex = (currentIndex + 1) % widget.options.length;
    widget.onChanged(widget.options[nextIndex]);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
            _cycle();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: _cycle,
          child: Container(
            width: 600,
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
            decoration: BoxDecoration(
              color: _focused ? Colors.white10 : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: _focused ? Border.all(color: primaryColor, width: 2) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.label, style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600)),
                Row(
                  children: widget.options.map((o) {
                    final isSelected = widget.value == o;
                    return Container(
                      margin: const EdgeInsets.only(left: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                        border: (isSelected && _focused) ? Border.all(color: Colors.white, width: 1) : null,
                      ),
                      child: Text(o, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTVSwitch extends StatefulWidget {
  final String label;
  final bool value;
  final Function(bool) onChanged;

  const _SettingsTVSwitch({required this.label, required this.value, required this.onChanged});

  @override
  State<_SettingsTVSwitch> createState() => _SettingsTVSwitchState();
}

class _SettingsTVSwitchState extends State<_SettingsTVSwitch> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: GestureDetector(
          onTap: () => widget.onChanged(!widget.value),
          child: Container(
            width: 600,
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
            decoration: BoxDecoration(
              color: _focused ? Colors.white10 : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: _focused ? Border.all(color: primaryColor, width: 2) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                Switch(
                  value: widget.value,
                  onChanged: widget.onChanged,
                  activeColor: primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
