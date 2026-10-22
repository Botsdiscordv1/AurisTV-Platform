import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:auris_core/auris_core.dart';

import '../providers/remote_control_provider.dart';
import '../../data/models/remote_device.dart';
import '../../../cast/presentation/providers/cast_provider.dart';

/// Abre la hoja de mando D-PAD táctil para controlar la TV o dispositivo remoto.
void showDpadRemoteSheet(BuildContext context, dynamic target, {dynamic chromecastMedia}) {
  RemoteDevice device;
  if (target is RemoteDevice) {
    device = target;
  } else {
    device = RemoteDevice.fromCastInfo(target, chromecastMedia);
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0F0F14),
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => DpadRemoteSheet(target: device),
  );
}

class DpadRemoteSheet extends ConsumerWidget {
  final RemoteDevice target;

  const DpadRemoteSheet({super.key, required this.target});

  void _sendAction(WidgetRef ref, String action, [Map<String, dynamic>? data]) {
    HapticFeedback.lightImpact();

    if (target.transport == 'chromecast') {
      final castNotifier = ref.read(chromecastProvider.notifier);
      final castState = ref.read(chromecastProvider);
      final currentPos = castState.media.positionMs;

      switch (action) {
        case RemoteAction.play:
        case RemoteAction.dpadCenter:
          castNotifier.togglePlay();
          break;
        case RemoteAction.pause:
          castNotifier.pause();
          break;
        case RemoteAction.dpadLeft:
          castNotifier.seekTo((currentPos - 10000).clamp(0, 1 << 31));
          break;
        case RemoteAction.dpadRight:
          castNotifier.seekTo((currentPos + 10000).clamp(0, 1 << 31));
          break;
        case RemoteAction.dpadUp:
        case RemoteAction.volumeUp:
          castNotifier.setVolume(1.0);
          break;
        case RemoteAction.dpadDown:
        case RemoteAction.volumeDown:
          castNotifier.setVolume(0.5);
          break;
        case RemoteAction.back:
        case RemoteAction.stop:
          castNotifier.stopCasting();
          break;
      }
      return;
    }

    ref.read(remoteControlProvider.notifier).sendCommand(target.id, action, data);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteState = ref.watch(remoteControlProvider);
    final activeDevice = remoteState.availableDevices.firstWhere(
      (d) => d.id == target.id,
      orElse: () => target,
    );

    const accent = Color(0xFFEF7A1E);
    final String deviceName = activeDevice.name.isNotEmpty ? activeDevice.name : 'TV';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gamepad_rounded, color: accent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'MANDO D-PAD • ${deviceName.toUpperCase()}',
                      style: const TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Top Navigation Controls (Back, Mute)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MandoCircleButton(
                icon: Icons.arrow_back_rounded,
                label: 'ATRÁS',
                onTap: () => _sendAction(ref, RemoteAction.back),
              ),
              _MandoCircleButton(
                icon: Icons.volume_off_rounded,
                label: 'MUTE',
                onTap: () => _sendAction(ref, RemoteAction.mute),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // D-PAD CONTROL PAD CENTRAL
          SizedBox(
            width: 230,
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Base D-Pad Circle
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1B1B22),
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // DPAD UP
                Positioned(
                  top: 8,
                  child: _DpadDirectionButton(
                    icon: Icons.keyboard_arrow_up_rounded,
                    onTap: () => _sendAction(ref, RemoteAction.dpadUp),
                  ),
                ),

                // DPAD DOWN
                Positioned(
                  bottom: 8,
                  child: _DpadDirectionButton(
                    icon: Icons.keyboard_arrow_down_rounded,
                    onTap: () => _sendAction(ref, RemoteAction.dpadDown),
                  ),
                ),

                // DPAD LEFT
                Positioned(
                  left: 8,
                  child: _DpadDirectionButton(
                    icon: Icons.keyboard_arrow_left_rounded,
                    onTap: () => _sendAction(ref, RemoteAction.dpadLeft),
                  ),
                ),

                // DPAD RIGHT
                Positioned(
                  right: 8,
                  child: _DpadDirectionButton(
                    icon: Icons.keyboard_arrow_right_rounded,
                    onTap: () => _sendAction(ref, RemoteAction.dpadRight),
                  ),
                ),

                // DPAD CENTER (OK)
                GestureDetector(
                  onTap: () => _sendAction(ref, RemoteAction.dpadCenter),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'OK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // VOLUME CONTROLS (VOL+ & VOL-) & PLAY/PAUSE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // VOL -
              _MandoSquareButton(
                icon: Icons.remove_rounded,
                label: 'VOL -',
                onTap: () => _sendAction(ref, RemoteAction.volumeDown),
              ),

              // PLAY / PAUSE
              _MandoSquareButton(
                icon: activeDevice.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                label: activeDevice.isPlaying ? 'PAUSA' : 'PLAY',
                isAccent: true,
                onTap: () => _sendAction(
                  ref,
                  activeDevice.isPlaying ? RemoteAction.pause : RemoteAction.play,
                ),
              ),

              // VOL +
              _MandoSquareButton(
                icon: Icons.add_rounded,
                label: 'VOL +',
                onTap: () => _sendAction(ref, RemoteAction.volumeUp),
              ),
            ],
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DpadDirectionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DpadDirectionButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        splashColor: const Color(0xFFEF7A1E).withOpacity(0.3),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: Icon(
              icon,
              color: Colors.white.withOpacity(0.9),
              size: 38,
            ),
          ),
        ),
      ),
    );
  }
}

class _MandoCircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MandoCircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _MandoSquareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isAccent;

  const _MandoSquareButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFEF7A1E);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isAccent ? accent.withOpacity(0.18) : Colors.white.withOpacity(0.08),
            border: Border.all(
              color: isAccent ? accent.withOpacity(0.5) : Colors.white.withOpacity(0.12),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Center(
                child: Icon(
                  icon,
                  color: isAccent ? accent : Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isAccent ? accent : Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
