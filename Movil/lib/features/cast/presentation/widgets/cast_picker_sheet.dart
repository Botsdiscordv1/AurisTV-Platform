import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:auris_core/auris_core.dart';
import 'package:auristv_mobile/features/remote_control/presentation/providers/remote_control_provider.dart';
import 'package:auristv_mobile/features/remote_control/presentation/widgets/device_selector_dialog.dart';

import '../providers/cast_provider.dart';

/// Hoja de transmisiÃ³n unificada (estilo Netflix): secciÃ³n Chromecast NATIVO
/// (diÃ¡logo de Google) + secciÃ³n dispositivos AurisTV (remote control Supabase).
///
/// Se abre desde el botÃ³n de cast del reproductor. Cuando hay sesiÃ³n
/// Chromecast activa muestra el dispositivo conectado y el botÃ³n para detener.
class CastPickerSheet extends ConsumerWidget {
  const CastPickerSheet({super.key});

  void _close(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castState = ref.watch(chromecastProvider);
    final remoteState = ref.watch(remoteControlProvider);
    final hasRemoteDevices = remoteState.availableDevices.any((d) =>
        d.id != remoteState.currentDevice?.id &&
        d.isOnline &&
        d.lastSeen
            .isAfter(DateTime.now().subtract(const Duration(minutes: 15))));

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transmitir a un dispositivo',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _close(context),
                    borderRadius: BorderRadius.circular(20),
                    child: const Center(
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ------------------------------------------------------------
          // SecciÃ³n Chromecast nativo (Google Cast SDK)
          // ------------------------------------------------------------
          if (castState.available || castState.isCasting) ...[
            const _SectionLabel('Chromecast'),
            const SizedBox(height: 8),
            if (castState.isCasting && castState.device != null) ...[
              _CastDeviceTile(
                icon: AurisIcons.castTv,
                title: castState.device!.name.isEmpty
                    ? 'Chromecast'
                    : castState.device!.name,
                subtitle: castState.media.loaded
                    ? (castState.media.isPlaying
                        ? 'Transmitiendo'
                        : 'En pausa')
                    : 'Conectando...',
                highlight: true,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    _close(context);
                    ref.read(chromecastProvider.notifier).stopCasting();
                  },
                  icon: const Icon(Icons.stop_circle_outlined,
                      color: Colors.redAccent, size: 20),
                  label: const Text('Detener transmisiÃ³n',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ] else
              _CastDeviceTile(
                icon: AurisIcons.castTv,
                title: 'Buscar Chromecasts',
                subtitle: 'Se abrirÃ¡ el menÃº de Google en tu dispositivo',
                highlight: false,
                hoveredWhileNoDevices: true,
                onTap: () {
                  _close(context);
                  ref.read(chromecastProvider.notifier).showDeviceChooser();
                },
              ),
            const SizedBox(height: 8),
          ],

          // ------------------------------------------------------------
          // SecciÃ³n remota AurisTV (Supabase realtime) â€” oculta si ya hay
          // una sesiÃ³n Chromecast para no mezclar canales de playback.
          // ------------------------------------------------------------
          if (!castState.isCasting) ...[
            if (castState.available || hasRemoteDevices)
              const _SectionLabel('Dispositivos AurisTV'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF7A1E),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                          color: const Color(0xFFEF7A1E).withValues(alpha: 0.35)),
                    ),
                  ),
                  onPressed: () {
                    _close(context);
                    _openRemoteSelector(context);
                  },
                  icon: const Icon(Icons.devices_rounded, size: 20),
                  label: const Text('Conectar a un dispositivo AurisTV',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          const SafeArea(top: false, child: SizedBox(height: 8)),
        ],
      ),
    );
  }

  Future<void> _openRemoteSelector(BuildContext context) async {
    await showDialog(context: context, builder: (_) => const DeviceSelectorDialog());
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFFEF7A1E),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _CastDeviceTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final bool highlight;
  final bool hoveredWhileNoDevices;
  final VoidCallback? onTap;

  const _CastDeviceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.highlight,
    this.hoveredWhileNoDevices = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFEF7A1E);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: highlight
                ? accent.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight
                  ? accent.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (highlight ? accent : Colors.white).withValues(alpha: 0.12),
                ),
                child: Center(child: AurisIcon(icon, color: Colors.white, size: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
