import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auris_core/auris_core.dart';
import '../providers/remote_control_provider.dart';
import '../../data/models/remote_device.dart';

class DeviceSelectorDialog extends ConsumerWidget {
  const DeviceSelectorDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteState = ref.watch(remoteControlProvider);
    // Senior Filter: Solo dispositivos online, que hayan reportado actividad en los últimos 15 min 
    // y ordenados por actividad reciente
    final cutoff = DateTime.now().subtract(const Duration(minutes: 15));
    final devices = remoteState.availableDevices
        .where((d) => 
          d.id != remoteState.currentDevice?.id && 
          d.isOnline && 
          d.lastSeen.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

    return Dialog(
      backgroundColor: const Color(0xFF0F0F0F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        width: 400,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Conectar a un dispositivo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: const Center(
                        child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (devices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No se encontraron otros dispositivos online',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return _DeviceTile(device: device, autofocus: index == 0);
                  },
                ),
              ),
            const SizedBox(height: 12),
            _CurrentDeviceStatus(device: remoteState.currentDevice),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  final RemoteDevice device;
  final bool autofocus;
  const _DeviceTile({required this.device, this.autofocus = false});

  Future<void> _connect(WidgetRef ref, BuildContext context) async {
    final remoteNotifier = ref.read(remoteControlProvider.notifier);

    // Senior Implementation: Enviar comando de apertura si el emisor tiene algo reproduciendo
    final current = ref.read(remoteControlProvider).currentDevice;

    if (current != null && current.mediaUrl != null) {
      remoteNotifier.setActiveTarget(device.id); // Guardar dispositivo activo
      await remoteNotifier.sendCommand(device.id, RemoteAction.openMedia, {
        'params': {
          'contentId': current.mediaTitle ?? 'Contenido Remoto',
          'url': current.mediaUrl,
          'source': current.mediaSource ?? '',
          'metadataTitle': current.metadataTitle ?? '',
          'banner': current.bannerUrl ?? '',
          'category': current.category ?? 'anime',
          // Podríamos pasar el positionMs actual para que el otro dispositivo reanude ahí
          'startPosition': current.positionMs.toString(),
        }
      });
    }

    if (context.mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFEF7A1E),
        content: Text('Sincronizando con ${device.name}...', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = device.isOnline;
    final isActiveTarget =
        ref.watch(remoteControlProvider.select((s) => s.activeTargetDeviceId)) == device.id;

    return AurisOptionCard(
      title: device.name,
      subtitle: isOnline ? (device.mediaTitle ?? 'En espera') : 'Offline',
      icon: _getDeviceIcon(device.type),
      isCurrent: isActiveTarget,
      isAvailable: isOnline,
      autofocus: autofocus,
      onTap: () => _connect(ref, context),
    );
  }

  String _getDeviceIcon(RemoteDeviceType type) {
    switch (type) {
      case RemoteDeviceType.web: return AurisIcons.desktop;
      case RemoteDeviceType.android: return AurisIcons.mobile;
      case RemoteDeviceType.windows: return AurisIcons.desktop;
      case RemoteDeviceType.ios: return AurisIcons.mobile;
      default: return AurisIcons.cast;
    }
  }
}

class _CurrentDeviceStatus extends ConsumerWidget {
  final RemoteDevice? device;
  const _CurrentDeviceStatus({this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (device == null) return const SizedBox.shrink();
    
    final activeTargetId = ref.watch(remoteControlProvider.select((s) => s.activeTargetDeviceId));
    final hasActiveTarget = activeTargetId != null;

    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFEF7A1E), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Este dispositivo: ${device!.name}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            if (hasActiveTarget)
              TextButton(
                onPressed: () => ref.read(remoteControlProvider.notifier).setActiveTarget(null),
                child: const Text('Desvincular', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
          ],
        ),
      ],
    );
  }
}
