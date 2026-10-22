import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:auris_core/auris_core.dart';
import 'package:auristv_mobile/features/remote_control/data/models/remote_device.dart';
import 'package:auristv_mobile/features/remote_control/presentation/providers/remote_control_provider.dart';
import 'package:auristv_mobile/features/remote_control/presentation/widgets/device_selector_dialog.dart';

import '../providers/cast_provider.dart';
import '../../data/providers/local_cast_provider.dart';

/// Hoja / Panel de transmisión unificado: sección Chromecast NATIVO
/// + sección dispositivos AurisTV (local LAN + Supabase Realtime).
///
/// Soporta formato TwoPanel (panel lateral en landscape) y Bottom Sheet en portrait.
class CastPickerSheet extends ConsumerWidget {
  final void Function(RemoteDevice device)? onConnectAurisDevice;

  const CastPickerSheet({super.key, this.onConnectAurisDevice});

  void _close(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 360,
            height: double.infinity,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                ),
              ],
            ),
            child: CastPickerContent(
              isSidebar: true,
              onConnectAurisDevice: onConnectAurisDevice,
              onClose: () => _close(context),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: CastPickerContent(
        isSidebar: false,
        onConnectAurisDevice: onConnectAurisDevice,
        onClose: () => _close(context),
      ),
    );
  }
}

/// Contenido modular del selector de dispositivos (soporta modo TwoPanel lateral y sheet).
class CastPickerContent extends ConsumerWidget {
  final bool isSidebar;
  final void Function(RemoteDevice device)? onConnectAurisDevice;
  final VoidCallback? onClose;

  const CastPickerContent({
    super.key,
    this.isSidebar = false,
    this.onConnectAurisDevice,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castState = ref.watch(chromecastProvider);
    final remoteState = ref.watch(remoteControlProvider);

    final cutoff = DateTime.now().subtract(const Duration(minutes: 15));
    final aurisDevices = remoteState.availableDevices
        .where((d) =>
            d.id != remoteState.currentDevice?.id &&
            d.isOnline &&
            d.lastSeen.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    final hasRemoteDevices = aurisDevices.isNotEmpty;

    return Column(
      mainAxisSize: isSidebar ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isSidebar) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transmitir a un dispositivo',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (onClose != null)
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
                      onTap: onClose,
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
        ],

        Expanded(
          flex: isSidebar ? 1 : 0,
          child: SingleChildScrollView(
            padding: isSidebar ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8) : EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---------------- Sección Chromecast ----------------
                if (castState.sdkSupported || castState.available || castState.isCasting) ...[
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
                          if (onClose != null) onClose!();
                          ref.read(chromecastProvider.notifier).stopCasting();
                        },
                        icon: const Icon(Icons.stop_circle_outlined,
                            color: Colors.redAccent, size: 20),
                        label: const Text('Detener transmisión',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else
                    _CastDeviceTile(
                      icon: AurisIcons.castTv,
                      title: 'Buscar Chromecast',
                      subtitle: 'Se abrirá el menú de Google en tu dispositivo',
                      highlight: false,
                      hoveredWhileNoDevices: true,
                      onTap: () {
                        if (onClose != null) onClose!();
                        ref.read(chromecastProvider.notifier).showDeviceChooser();
                      },
                    ),
                  const SizedBox(height: 12),
                ],

                // ---------------- Sección Local LAN ----------------
                if (!castState.isCasting) ...[
                  _LocalDevicesSection(
                    onConnect: (device) {
                      if (onClose != null) onClose!();
                      if (onConnectAurisDevice != null) onConnectAurisDevice!(device);
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // ---------------- Sección AurisTV Cloud ----------------
                if (!castState.isCasting) ...[
                  if (castState.available || hasRemoteDevices || aurisDevices.isNotEmpty)
                    const _SectionLabel('Dispositivos AurisTV'),
                  const SizedBox(height: 8),
                  if (onConnectAurisDevice != null)
                    if (aurisDevices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: Text(
                            'No hay dispositivos AurisTV online',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ...aurisDevices.map((device) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _CastDeviceTile(
                              icon: _deviceIcon(device.type),
                              title: device.name,
                              subtitle: device.mediaTitle?.isNotEmpty == true
                                  ? device.mediaTitle!
                                  : 'En espera',
                              highlight: false,
                              onTap: () {
                                if (onClose != null) onClose!();
                                onConnectAurisDevice!(device);
                              },
                            ),
                          ))
                  else
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
                            if (onClose != null) onClose!();
                            _openRemoteSelector(context);
                          },
                          icon: const Icon(Icons.devices_rounded, size: 20),
                          label: const Text('Conectar a un dispositivo AurisTV',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openRemoteSelector(BuildContext context) async {
    await showDialog(context: context, builder: (_) => const DeviceSelectorDialog());
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFFEF7A1E),
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 1.2,
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
    this.highlight = false,
    this.hoveredWhileNoDevices = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFEF7A1E);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: highlight
                ? accent.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight
                  ? accent.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: highlight
                      ? accent.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.08),
                ),
                child: Center(
                  child: AurisIcon(
                    icon,
                    color: highlight ? accent : Colors.white70,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: highlight ? accent : Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: highlight ? accent : Colors.white38,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalDevicesSection extends ConsumerStatefulWidget {
  final void Function(RemoteDevice device)? onConnect;

  const _LocalDevicesSection({this.onConnect});

  @override
  ConsumerState<_LocalDevicesSection> createState() => _LocalDevicesSectionState();
}

class _LocalDevicesSectionState extends ConsumerState<_LocalDevicesSection> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration.zero, () {
      if (mounted) ref.read(localCastProvider.notifier).start();
    });
  }

  Future<void> _connect(LocalTvBeacon tv) async {
    final notifier = ref.read(localCastProvider.notifier);
    final onConnect = widget.onConnect;
    if (onConnect == null) return;

    if (!notifier.isPaired(tv)) {
      final paired = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _LocalPairDialog(tv: tv),
      );
      if (paired != true || !mounted) return;
    }

    final device = notifier.remoteDeviceFor(tv.deviceId);
    if (device != null) {
      onConnect(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localState = ref.watch(localCastProvider);
    final hasAuris = ref.watch(remoteControlProvider).availableDevices
        .any((d) => d.transport != 'local');

    if (localState.devices.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Local — misma red'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                localState.listening
                    ? 'Buscando TVs con AurisTV en tu red...'
                    : 'Abre AurisTV en tu TV para que aparezca aquí',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Local — misma red'),
        const SizedBox(height: 8),
        ...localState.devices.map((tv) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CastDeviceTile(
                icon: AurisIcons.castTv,
                title: tv.name,
                subtitle: ref.read(localCastProvider.notifier).isPaired(tv)
                    ? 'Vinculado — toca para transmitir'
                    : 'Primera vez: se pedirá un PIN',
                highlight: false,
                onTap: () => _connect(tv),
              ),
            )),
        if (localState.pairingError != null && hasAuris)
          Text(
            localState.pairingError!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
      ],
    );
  }
}

class _LocalPairDialog extends ConsumerStatefulWidget {
  final LocalTvBeacon tv;

  const _LocalPairDialog({required this.tv});

  @override
  ConsumerState<_LocalPairDialog> createState() => _LocalPairDialogState();
}

class _LocalPairDialogState extends ConsumerState<_LocalPairDialog> {
  final _pinCtrl = TextEditingController();
  final _pinFocus = FocusNode();
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(localCastProvider.notifier);
      final paired = await notifier.startPairing(widget.tv);
      if (paired && mounted) {
        Navigator.of(context).pop(true);
        return;
      }
      if (mounted) {
        setState(() {
          _verifying = notifier.isPaired(widget.tv) ? false : _verifying;
        });
        _pinFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) return;

    setState(() => _verifying = true);
    final notifier = ref.read(localCastProvider.notifier);
    final ok = await notifier.verifyPin(widget.tv, pin);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localState = ref.watch(localCastProvider);
    final error = localState.pairingError;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Dialog(
      backgroundColor: const Color(0xFF141418),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 40 : 24,
        vertical: isLandscape ? 8 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxWidth: isLandscape ? 480 : 380),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: isLandscape ? 12 : 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Vincular con ${widget.tv.name}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isLandscape ? 15 : 16,
                ),
              ),
              SizedBox(height: isLandscape ? 4 : 8),
              Text(
                'Ingresa el código PIN que se muestra en tu TV:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isLandscape ? 12 : 13,
                ),
              ),
              SizedBox(height: isLandscape ? 8 : 14),

              if (isLandscape) ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _pinCtrl,
                          focusNode: _pinFocus,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            hintText: '0000',
                            hintStyle: const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _verifyPin(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {
                        ref.read(localCastProvider.notifier).cancelPairing();
                        Navigator.of(context).pop(false);
                      },
                      child: const Text('Cancelar',
                          style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: _verifying ? null : _verifyPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF7A1E),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _verifying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Vincular',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                    ),
                  ],
                ),
              ] else ...[
                TextField(
                  controller: _pinCtrl,
                  focusNode: _pinFocus,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '0000',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _verifyPin(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        ref.read(localCastProvider.notifier).cancelPairing();
                        Navigator.of(context).pop(false);
                      },
                      child: const Text('Cancelar',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _verifying ? null : _verifyPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF7A1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _verifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Vincular',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],

              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _deviceIcon(RemoteDeviceType type) {
  switch (type) {
    case RemoteDeviceType.web:
      return AurisIcons.desktop;
    case RemoteDeviceType.android:
      return AurisIcons.mobile;
    case RemoteDeviceType.windows:
      return AurisIcons.desktop;
    case RemoteDeviceType.ios:
      return AurisIcons.mobile;
    default:
      return AurisIcons.cast;
  }
}
