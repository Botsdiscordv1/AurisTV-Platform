import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:auris_core/auris_core.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../remote_control/presentation/providers/remote_control_provider.dart';

/// ============================================================================
/// Cast Local (LAN, sin login) — lado TV (receptor/server).
///
/// AurisTV en la TV abre:
///   * Un beacon UDP cada ~3 s hacia `255.255.255.255:45630` para que el móvil
///     lo descubra (el móvil solo escucha; no hace falta MulticastLock aquí).
///   * Un server HTTP en `:45631` con rutas:
///       /pair/start   → si ya está emparejado valida el token; si no, genera
///                       un PIN de 6 dígitos que se muestra en pantalla.
///       /pair/verify  → verifica el PIN, crea el token de sesión y lo guarda.
///       /pair/cancel  → limpia el PIN pendiente.
///       /cast/start   → `open_media` inyectado al bus de comandos (player).
///       /cast/control → comandos play/pause/seek/stop/volumen/tracks.
///       /cast/status  → posición/duración/pistas actuales del player.
///
/// Todo funciona sin Supabase y sin que la TV esté logueada: el bus de
/// comandos es `remoteControlProvider.lastReceivedCommand`, el mismo que usa
/// el cast propio vía Supabase, así que el PlayerScreen no cambia.
/// Los dispositivos emparejados quedan en Hive (`local_pairings`).
/// ============================================================================

/// Puerto UDP al que la TV envía sus beacon (el móvil lo escucha).
const int kAurisBeaconRemotePort = 45630;
/// Puerto TCP del server HTTP de la TV (el móvil lo usa para todo).
const int kAurisCastServerPort = 45631;
const String kAurisBeaconProto = 'auriscast.1';
const Duration kPinValidity = Duration(minutes: 3);

class LocalCastPlaybackState {
  final bool loaded;
  final int positionMs;
  final int durationMs;
  final bool isPlaying;
  final String? mediaTitle;
  final List<Map<String, dynamic>> tracks;
  final int selectedTrackIndex;

  const LocalCastPlaybackState({
    this.loaded = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.isPlaying = false,
    this.mediaTitle,
    this.tracks = const [],
    this.selectedTrackIndex = 0,
  });
}

/// Estado visible del server (lo consume el overlay de PIN en pantalla).
class LocalCastServerState {
  final bool running;
  final int port;
  final String tvId;
  final String tvName;
  final bool pairedEnabled;

  /// Emparejamiento en curso: PIN mostrado y a quién se le verificó.
  final String? pairingPin;
  final DateTime? pinExpires;
  final String? pendingDeviceId;

  /// Confirmación breve tras un vínculo exitoso ("Emiliano conectado").
  final String? connectedName;

  const LocalCastServerState({
    this.running = false,
    this.port = kAurisCastServerPort,
    this.tvId = '',
    this.tvName = 'AurisTV',
    this.pairedEnabled = false,
    this.pairingPin,
    this.pinExpires,
    this.pendingDeviceId,
    this.connectedName,
  });

  LocalCastServerState copyWith({
    bool? running,
    int? port,
    String? tvId,
    String? tvName,
    bool? pairedEnabled,
    String? pairingPin,
    DateTime? pinExpires,
    String? pendingDeviceId,
    String? connectedName,
    bool clearPair = false,
    bool clearConnected = false,
  }) {
    return LocalCastServerState(
      running: running ?? this.running,
      port: port ?? this.port,
      tvId: tvId ?? this.tvId,
      tvName: tvName ?? this.tvName,
      pairedEnabled: pairedEnabled ?? this.pairedEnabled,
      pairingPin: clearPair ? null : (pairingPin ?? this.pairingPin),
      pinExpires: clearPair ? null : (pinExpires ?? this.pinExpires),
      pendingDeviceId: clearPair ? null : (pendingDeviceId ?? this.pendingDeviceId),
      connectedName: clearConnected ? null : (connectedName ?? this.connectedName),
    );
  }
}

final localCastServerProvider =
    StateNotifierProvider<LocalCastServerNotifier, LocalCastServerState>((ref) {
  return LocalCastServerNotifier()..attachProviderRef(ref);
});

/// Estado del player publicado por la TV (lo consume /cast/status).
final localCastBridgeProvider =
    StateNotifierProvider<LocalCastBridgeNotifier, LocalCastPlaybackState>((ref) {
  return LocalCastBridgeNotifier();
});

class LocalCastBridgeNotifier extends StateNotifier<LocalCastPlaybackState> {
  LocalCastBridgeNotifier() : super(const LocalCastPlaybackState());

  void publish({
    required bool loaded,
    required int positionMs,
    required int durationMs,
    required bool isPlaying,
    String? mediaTitle,
    List<Map<String, dynamic>> tracks = const [],
    int selectedTrackIndex = 0,
  }) {
    state = LocalCastPlaybackState(
      loaded: loaded,
      positionMs: positionMs,
      durationMs: durationMs,
      isPlaying: isPlaying,
      mediaTitle: mediaTitle,
      tracks: tracks,
      selectedTrackIndex: selectedTrackIndex,
    );
  }

  void clear() => state = const LocalCastPlaybackState();
}

class LocalCastServerNotifier extends StateNotifier<LocalCastServerState> {
  Box get _box => Hive.box('local_pairings');
  HttpServer? _server;
  RawDatagramSocket? _beaconSocket;
  Timer? _beaconTimer;
  Timer? _pinExpiryTimer;
  Timer? _connectedBannerTimer;
  String _tvName = 'AurisTV';

  LocalCastServerNotifier() : super(const LocalCastServerState());

  // ------------------------------------------------------------------
  // Arranque
  // ------------------------------------------------------------------

  Future<void> start() async {
    if (state.running) return;

    // Nombre de la TV (modelo del dispositivo).
    try {
      if (!kIsWeb) {
        final info = await DeviceInfoPlugin().androidInfo;
        _tvName = info.model.isNotEmpty ? info.model : 'AurisTV';
      }
    } catch (_) {}

    // Identidad estable de la TV (para que el móvil la recuerde).
    String tvId = _box.get('server_tv_id') as String? ?? '';
    if (tvId.isEmpty) {
      tvId = const Uuid().v4();
      await _box.put('server_tv_id', tvId);
    }

    state = state.copyWith(
      running: true,
      tvId: tvId,
      tvName: _tvName,
    );
    _reloadPairedFlag();

    await _startHttpServer();
    _startBeacon();
  }

  void _reloadPairedFlag() {
    final pads = _box.keys.where((k) => k != 'server_tv_id').length;
    state = state.copyWith(pairedEnabled: pads > 0);
  }

  // ------------------------------------------------------------------
  // Server HTTP
  // ------------------------------------------------------------------

  Future<void> _startHttpServer() async {
    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        kAurisCastServerPort,
        shared: false,
      );
      _server!.listen(_onRequest, onError: (e) {
        debugPrint('[AurisLocalServer] error: $e');
      });
      debugPrint('[AurisLocalServer] HTTP listo en $kAurisCastServerPort');
    } catch (e) {
      debugPrint('[AurisLocalServer] No se pudo abrir $kAurisCastServerPort: $e');
      state = state.copyWith(running: false);
    }
  }

  Future<void> _onRequest(HttpRequest req) async {
    try {
      final body = await utf8.decoder.bind(req).join();
      Map<String, dynamic> data = {};
      if (body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) data = decoded;
      }
      final path = req.uri.path;

      Map<String, dynamic>? res;
      if (path == '/pair/start') {
        res = await _pairStart(data);
      } else if (path == '/pair/verify') {
        res = await _pairVerify(data);
      } else if (path == '/pair/cancel') {
        res = _pairCancel(data);
      } else if (path == '/cast/start') {
        res = _authorized(req, data)
            ? _injectCommand('open_media', {
                'params': data['params'] is Map
                    ? Map<String, dynamic>.from(data['params'] as Map)
                    : <String, dynamic>{},
              })
            : _unauthorized();
      } else if (path == '/cast/control') {
        final action = data['action']?.toString();
        if (action == null || action.isEmpty) {
          res = {'ok': false, 'error': 'missing_action'};
        } else if (!_authorized(req, data)) {
          res = _unauthorized();
        } else {
          final rest = Map<String, dynamic>.from(data)
            ..remove('action')
            ..remove('deviceId')
            ..remove('deviceName')
            ..remove('token');
          res = _injectCommand(action, rest);
        }
      } else if (path == '/cast/status') {
        res = _authorized(req, data)
            ? _statusSnapshot()
            : _unauthorized();
      } else if (path == '/ping') {
        res = {'ok': true, 'name': state.tvName};
      } else {
        res = {'ok': false, 'error': 'unknown_path'};
      }

      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(res));
      await req.response.close();
    } catch (e) {
      try {
        req.response.statusCode = 500;
        req.response.write(jsonEncode({'ok': false, 'error': e.toString()}));
        await req.response.close();
      } catch (_) {}
    }
  }

  Map<String, dynamic> _unauthorized() =>
      {'ok': false, 'error': 'unauthorized'};

  /// Verifica deviceId+token contra el registro local de emparejados (Headers o Body).
  bool _authorized(HttpRequest req, Map<String, dynamic> data) {
    String deviceId = req.headers.value('X-Auris-Device') ?? '';
    String token = req.headers.value('X-Auris-Token') ?? '';

    if (deviceId.isEmpty) deviceId = data['deviceId']?.toString() ?? '';
    if (token.isEmpty) token = data['token']?.toString() ?? '';

    if (deviceId.isEmpty || token.isEmpty) return false;
    final record = _box.get('device_$deviceId');
    if (record is! Map) return false;
    return record['token']?.toString() == token;
  }

  /// Inyecta un comando al MISMO bus que usa el cast Supabase: el player TV
  /// reacciona vía `remoteControlProvider.lastReceivedCommand`.
  Map<String, dynamic> _injectCommand(
      String action, Map<String, dynamic> extra) {
    final command = <String, dynamic>{
      'action': action,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      ...extra,
    };
    try {
      final container = _providerRef;
      if (container != null) {
        container.read(remoteControlProvider.notifier).receiveCommand(command);
      } else {
        debugPrint('[AurisLocalServer] Sin ProviderRef aún; comando perdido');
      }
    } catch (e) {
      debugPrint('[AurisLocalServer] Inyección de comando falló: $e');
    }
    return {'ok': true};
  }

  Ref? _providerRef;
  void attachProviderRef(Ref ref) => _providerRef = ref;

  Map<String, dynamic> _statusSnapshot() {
    final bridge = _providerRef?.read(localCastBridgeProvider.notifier).state ??
        const LocalCastPlaybackState();
    return {
      'ok': true,
      'loaded': bridge.loaded,
      'positionMs': bridge.positionMs,
      'durationMs': bridge.durationMs,
      'isPlaying': bridge.isPlaying,
      'mediaTitle': bridge.mediaTitle,
      'tracks': bridge.tracks,
      'selectedTrackIndex': bridge.selectedTrackIndex,
    };
  }

  // ------------------------------------------------------------------
  // Emparejamiento
  // ------------------------------------------------------------------

  Future<bool> _isDevicePaired(String deviceId, {String? token}) async {
    final record = _box.get('device_$deviceId');
    if (record is! Map) return false;
    if (token == null) return true;
    return record['token']?.toString() == token;
  }

  Future<Map<String, dynamic>> _pairStart(Map<String, dynamic> data) async {
    final deviceId = data['deviceId']?.toString() ?? '';
    if (deviceId.isEmpty) {
      return {'ok': false, 'error': 'missing_device'};
    }

    // Token válido del emisor: emparejado directo (sin PIN).
    if (data['token'] != null &&
        await _isDevicePaired(deviceId, token: data['token'].toString())) {
      return {'ok': true, 'paired': true};
    }

    // Sin token o token defectuoso: exige el PIN (re-empareja y guarda).

    // Generar PIN y mostrarlo en la TV.
    final pin =
        List<int>.generate(6, (_) => Random.secure().nextInt(10)).join();
    final expires = DateTime.now().add(kPinValidity);
    _pinExpiryTimer?.cancel();
    _pinExpiryTimer = Timer(kPinValidity, () {
      if (state.pendingDeviceId == deviceId) {
        state = state.copyWith(clearPair: true);
      }
    });
    state = state.copyWith(
      pairingPin: pin,
      pinExpires: expires,
      pendingDeviceId: deviceId,
    );
    debugPrint('[AurisLocalServer] PIN de vinculación generado');

    return {'ok': true, 'paired': false, 'pinRequired': true};
  }

  Future<Map<String, dynamic>> _pairVerify(Map<String, dynamic> data) async {
    final deviceId = data['deviceId']?.toString() ?? '';
    final pin = data['pin']?.toString() ?? '';
    final name = data['deviceName']?.toString() ?? 'Móvil';

    final pending = state.pendingDeviceId;
    final shown = state.pairingPin;
    final expires = state.pinExpires;

    if (pending == null ||
        shown == null ||
        pending != deviceId ||
        expires == null ||
        DateTime.now().isAfter(expires)) {
      state = state.copyWith(clearPair: true);
      return {'ok': false, 'error': 'PIN expirado. Presiona la TV otra vez.'};
    }
    if (pin != shown) {
      return {'ok': false, 'error': 'PIN incorrecto'};
    }

    // Guardar el emparejamiento.
    final token = String.fromCharCodes(
      List<int>.generate(24, (_) {
        const chars =
            'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        return chars.codeUnitAt(Random.secure().nextInt(chars.length));
      }),
    );
    await _box.put('device_$deviceId', {
      'name': name,
      'token': token,
      'paired_at': DateTime.now().toIso8601String(),
    });

    state = state.copyWith(
      clearPair: true,
      connectedName: name,
    );
    _connectedBannerTimer?.cancel();
    _connectedBannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) state = state.copyWith(clearConnected: true);
    });
    _reloadPairedFlag();

    debugPrint('[AurisLocalServer] Vinculado: $name');
    return {'ok': true, 'paired': true, 'token': token};
  }

  Map<String, dynamic> _pairCancel(Map<String, dynamic> data) {
    final deviceId = data['deviceId']?.toString() ?? '';
    if (state.pendingDeviceId == deviceId || deviceId.isEmpty) {
      state = state.copyWith(clearPair: true);
    }
    return {'ok': true};
  }

  // ------------------------------------------------------------------
  // Beacon UDP
  // ------------------------------------------------------------------

  Future<void> _startBeacon() async {
    try {
      _beaconSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      _beaconSocket!.broadcastEnabled = true;
    } catch (e) {
      debugPrint('[AurisLocalServer] Beacon UDP no disponible: $e');
      return;
    }

    _beaconTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final payload = jsonEncode({
        'proto': kAurisBeaconProto,
        'tvId': state.tvId,
        'name': state.tvName,
        'port': kAurisCastServerPort,
      });
      try {
        _beaconSocket?.send(
          utf8.encode(payload),
          InternetAddress('255.255.255.255'),
          kAurisBeaconRemotePort,
        );
      } catch (_) {}
    });
    debugPrint('[AurisLocalServer] Beacon UDP activo');
  }

  @override
  void dispose() {
    _beaconTimer?.cancel();
    _pinExpiryTimer?.cancel();
    _connectedBannerTimer?.cancel();
    _beaconSocket?.close();
    _server?.close(force: true);
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Inicializador: arranca el server + beacon cuando la app TV arranca.
// ---------------------------------------------------------------------------
class LocalCastInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const LocalCastInitializer({super.key, required this.child});

  @override
  ConsumerState<LocalCastInitializer> createState() =>
      _LocalCastInitializerState();
}

class _LocalCastInitializerState extends ConsumerState<LocalCastInitializer> {
  @override
  void initState() {
    super.initState();
    // Diferido para no competir con el arranque (Splash/Supabase/media_kit).
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(localCastServerProvider.notifier).start();
        const MethodChannel('auristv/system')
            .invokeMethod('startCastService')
            .catchError((_) {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// ---------------------------------------------------------------------------
// Overlay: muestra el PIN de vinculación y la confirmación de dispositivo
// vinculado. Se pega al stack global de main.dart.
// ---------------------------------------------------------------------------
class LocalCastOverlay extends ConsumerWidget {
  const LocalCastOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localCastServerProvider);
    final showPin = state.pairingPin != null;
    final showConnected = state.connectedName != null;
    if (!showPin && !showConnected) return const SizedBox.shrink();

    final pinDigits = showPin ? state.pairingPin!.replaceAll(' ', '').split('') : <String>[];

    return Positioned(
      top: 28,
      right: 28,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xF5141519),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEF7A1E).withOpacity(0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF7A1E).withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 32,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: showPin
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AurisIcon(
                          AurisIcons.castMobile,
                          color: const Color(0xFFEF7A1E),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'VINCULACIÓN DE MÓVIL',
                          style: TextStyle(
                            color: Color(0xFFEF7A1E),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ingresa en tu móvil este código',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Cajas con cada dígito del PIN
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < pinDigits.length; i++) ...[
                          Container(
                            width: 42,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22242C),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              pinDigits[i],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (i < pinDigits.length - 1) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AurisIcon(
                          AurisIcons.tv,
                          color: Colors.white.withOpacity(0.45),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AurisTV — ${state.tvName}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0x2500E676),
                        shape: BoxShape.circle,
                      ),
                      child: AurisIcon(
                        AurisIcons.checkCircleFilled,
                        color: const Color(0xFF00E676),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Vinculado: ${state.connectedName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
