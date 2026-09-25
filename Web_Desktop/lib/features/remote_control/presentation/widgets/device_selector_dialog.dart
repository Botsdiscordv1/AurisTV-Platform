import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
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
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 400,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Conectar a un dispositivo',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                    return _DeviceTile(device: device);
                  },
                ),
              ),
            const Divider(color: Colors.white10, height: 32),
            _CurrentDeviceStatus(device: remoteState.currentDevice),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  final RemoteDevice device;
  const _DeviceTile({required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = device.isOnline;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      onTap: () async {
        final remoteNotifier = ref.read(remoteControlProvider.notifier);
        
        // Intentamos obtener el estado actual del reproductor (si estamos en él)
        // O simplemente enviamos un comando de "vincular"
        
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
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF7A1E),
            content: Text('Sincronizando con ${device.name}...', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: isOnline ? Colors.green.withOpacity(0.1) : Colors.white10,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _getDeviceIcon(device.type),
          color: isOnline ? Colors.greenAccent : Colors.white24,
          size: 20,
        ),
      ),
      title: Text(device.name, style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: Text(
        isOnline ? (device.mediaTitle ?? 'En espera') : 'Offline',
        style: TextStyle(color: isOnline ? Colors.greenAccent.withOpacity(0.7) : Colors.white24, fontSize: 12),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white10, size: 14),
    );
  }

  IconData _getDeviceIcon(RemoteDeviceType type) {
    switch (type) {
      case RemoteDeviceType.web: return Symbols.desktop_windows;
      case RemoteDeviceType.android: return Symbols.airplay;
      case RemoteDeviceType.windows: return Symbols.desktop_windows;
      case RemoteDeviceType.ios: return Symbols.phone_iphone;
      default: return Symbols.devices_other;
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
