import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../remote_control/data/models/remote_device.dart';
import '../../../remote_control/presentation/providers/remote_control_provider.dart';

/// ============================================================================
/// Cast Local (LAN, sin login) — lado MOVIL (emisor).
///
/// La TV con AurisTV instalado difunde un beacon UDP cada ~3 s a
/// `255.255.255.255:kAurisBeaconPort` y corre un server HTTP en el puerto
/// del beacon. Este provider:
///
///   1. Escucha los beacon y mantiene la lista de TVs de la red (con TTL).
///   2. Empareja con la TV la PRIMERA vez usando el PIN que la TV muestra en
///      pantalla (/pair/start → pin_required; /pair/verify → token).
///   3. Guarda el token por TV (secure storage); después el pair es directo.
///   4. Envia comandos de cast por HTTP (start/control) y hace polling del
///      status (/cast/status) para que el timeline del overlay se anime.
///
/// Las TVs aparecen como RemoteDevice con id `local:<tvId>` dentro de
/// remoteControlProvider.availableDevices → todo el overlay/handback del
/// cast propio funciona sin cambios; solo el transporte cambia.
/// ============================================================================

/// Puerto UDP donde la TV bombardea sus beacon y el móvil escucha.
const int kAurisBeaconPort = 45630;

/// Puerto TCP del server HTTP de la TV.
const int kAurisCastServerPort = 45631;

/// Identificador del protocolo (ignora tráfico ajeno al llegar por el puerto).
const String kAurisBeaconProto = 'auriscast.1';

/// Una TV sin beacon durante este tiempo se considera fuera de la red.
const Duration kDeviceExpiry = Duration(seconds: 12);

class LocalTvBeacon {
  final String tvId;
  final String name;
  final String ip;
  final int port;
  final DateTime lastSeen;

  const LocalTvBeacon({
    required this.tvId,
    required this.name,
    required this.ip,
    required this.port,
    required this.lastSeen,
  });

  /// Id convencional usado como RemoteDevice.id para el cast propio.
  String get deviceId => 'local:$tvId';

  Uri uri(String path) => Uri.parse('http://$ip:$port$path');
}

class LocalCastState {
  final List<LocalTvBeacon> devices;
  final bool listening;

  /// tvId con proceso de vinculación activo (PIN visible en la TV).
  final String? pairingTvId;
  final String? pairingError;

  const LocalCastState({
    this.devices = const [],
    this.listening = false,
    this.pairingTvId,
    this.pairingError,
  });

  LocalCastState copyWith({
    List<LocalTvBeacon>? devices,
    bool? listening,
    String? pairingTvId,
    String? pairingError,
  }) {
    return LocalCastState(
      devices: devices ?? this.devices,
      listening: listening ?? this.listening,
      // pairingTvId/pairingError con null explícito los limpian.
      pairingTvId: pairingTvId ?? this.pairingTvId,
      pairingError: pairingError ?? this.pairingError,
    );
  }
}

final localCastProvider =
    StateNotifierProvider<LocalCastNotifier, LocalCastState>((ref) {
  return LocalCastNotifier(ref);
});

class LocalCastNotifier extends StateNotifier<LocalCastState> {
  final Ref _ref;
  final _box = Hive.box('user_data');
  final _secure = const FlutterSecureStorage();

  RawDatagramSocket? _udp;
  Timer? _pruneTimer;
  Timer? _pollTimer;
  HttpClient? _http;

  /// Tokens de sesión por tvId (secure storage → cache en memoria).
  final Map<String, String> _tokens = {};
  bool _tokensLoaded = false;

  /// Último /cast/status por tvId: {positionMs, durationMs, isPlaying, ...}.
  final Map<String, Map<String, dynamic>> _status = {};

  /// Consecutivos de fallo de polling por target activo.
  int _statusFailures = 0;

  /// Momento en que se abrió la sesión local actual (margen para handback
  /// si la TV ainda no abrió el player).
  int _sessionStartMs = 0;

  /// Dispositivo del emisor (persistente aunque no haya login).
  String? _deviceId;

  LocalCastNotifier(this._ref) : super(const LocalCastState()) {
    _registerCommandDelegate();
  }

  // ------------------------------------------------------------------
  // Identidad local
  // ------------------------------------------------------------------

  String get deviceId {
    if (_deviceId != null && _deviceId!.isNotEmpty) return _deviceId!;
    final saved = _box.get('localcast_device_id') as String?;
    _deviceId = (saved != null && saved.isNotEmpty) ? saved : const Uuid().v4();
    _box.put('localcast_device_id', _deviceId);
    return _deviceId!;
  }

  String get _deviceName {
    if (kIsWeb) return 'AurisTV Móvil';
    if (Platform.isAndroid) {
      try {
        // Nombre genérico: el modelo exacto lo resuelve la TV al emparejar.
        return 'AurisTV Móvil';
      } catch (_) {}
    }
    return 'AurisTV Móvil';
  }

  // ------------------------------------------------------------------
  // Discovery (UDP beacon de la TV)
  // ------------------------------------------------------------------

  /// Inicia (idempotente) la escucha de beacon + polling de status.
  Future<void> start() async {
    _registerCommandDelegate();
    await _loadTokens();
    if (state.listening) return;

    try {
      final req = await MethodChannel('auristv/network')
          .invokeMethod('acquireMulticastLock');
      debugPrint('[AurisLocal] MulticastLock: $req');
    } catch (e) {
      // Android lo necesita para recibir broadcast/multicast en Wi-Fi;
      // en desktop no existe el canal y la escucha suele funcionar igual.
      debugPrint('[AurisLocal] MulticastLock no disponible: $e');
    }

    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        kAurisBeaconPort,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket.receive();
          if (dg != null) _handleDatagram(dg);
        }
      });
      _udp = socket;
      state = state.copyWith(listening: true);
      debugPrint('[AurisLocal] Escuchando beacon en UDP $kAurisBeaconPort');
    } catch (e) {
      debugPrint('[AurisLocal] No se pudo abrir UDP $kAurisBeaconPort: $e');
      state = state.copyWith(listening: false);
      return;
    }

    _pruneTimer ??=
        Timer.periodic(const Duration(seconds: 3), (_) => _pruneStale());
    _startStatusPolling();
  }

  void stop() {
    _udp?.close();
    _udp = null;
    _pruneTimer?.cancel();
    _pruneTimer = null;
    state = state.copyWith(listening: false, devices: const []);
    _pushLocalDevices(); // vacía la mezcla en remoteControl
  }

  void _handleDatagram(Datagram dg) {
    try {
      final text = utf8.decode(dg.data);
      final map = jsonDecode(text) as Map<String, dynamic>;
      if (map['proto'] != kAurisBeaconProto) return;
      final tvId = map['tvId']?.toString() ?? '';
      if (tvId.isEmpty) return;

      final beacon = LocalTvBeacon(
        tvId: tvId,
        name: map['name']?.toString() ?? 'AurisTV',
        ip: dg.address.address,
        port: (map['port'] as num?)?.toInt() ?? kAurisCastServerPort,
        lastSeen: DateTime.now(),
      );
      _upsertBeacon(beacon);
    } catch (e) {
      // Beacon corrupto / de otra app: se ignora.
    }
  }

  void _upsertBeacon(LocalTvBeacon beacon) {
    final now = DateTime.now();
    final updated = <LocalTvBeacon>[];
    var replaced = false;
    for (final d in state.devices) {
      if (d.tvId == beacon.tvId) {
        updated.add(beacon);
        replaced = true;
      } else if (now.difference(d.lastSeen) < kDeviceExpiry) {
        updated.add(d);
      }
    }
    if (!replaced) updated.add(beacon);
    updated.sort((a, b) => a.name.compareTo(b.name));
    state = state.copyWith(devices: updated);
    _pushLocalDevices();
  }

  void _pruneStale() {
    final now = DateTime.now();
    final alive = state.devices
        .where((d) => now.difference(d.lastSeen) < kDeviceExpiry)
        .toList();
    if (alive.length != state.devices.length) {
      state = state.copyWith(devices: alive);
      _pushLocalDevices();
    }
  }

  LocalTvBeacon? beaconFor(String localId) {
    final tvId = localId.replaceFirst('local:', '');
    try {
      return state.devices.firstWhere((d) => d.tvId == tvId);
    } catch (_) {
      return null;
    }
  }

  /// RemoteDevice sintético del cast propio para un tvId. Lo usa la hoja de
  /// cast tras el emparejamiento para iniciar la sesión con el overlay.
  RemoteDevice? remoteDeviceFor(String deviceId) {
    final tv = beaconFor(deviceId);
    if (tv == null) return null;
    final st = _status[tv.tvId] ?? const {};
    return RemoteDevice(
      id: 'local:${tv.tvId}',
      userId: 'local',
      name: tv.name,
      type: _guessType() ?? RemoteDeviceType.other,
      isOnline: true,
      lastSeen: tv.lastSeen,
      transport: 'local',
      mediaTitle: st['mediaTitle'] as String?,
      positionMs: (st['positionMs'] as num?)?.toInt() ?? 0,
      durationMs: (st['durationMs'] as num?)?.toInt() ?? 0,
      isPlaying: st['isPlaying'] == true,
      availableTracks: (st['tracks'] as List?)
              ?.whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList() ??
          const [],
      selectedTrackIndex: (st['selectedTrackIndex'] as num?)?.toInt() ?? 0,
    );
  }

  /// ¿Hay token de sesión guardado para esta TV? (emparejada antes)
  bool isPaired(LocalTvBeacon tv) => _tokens[tv.tvId]?.isNotEmpty == true;

  /// Elimina el token guardado y desvincula la TV local.
  Future<void> forgetDevice(String tvId) async {
    final cleanId = tvId.replaceFirst('local:', '');
    _tokens.remove(cleanId);
    try {
      await _secure.write(
        key: 'localcast_tokens',
        value: jsonEncode(_tokens),
      );
    } catch (_) {}
    _pushLocalDevices();
  }

  // ------------------------------------------------------------------
  // Introspección en remoteControlProvider (bus común del cast propio)
  // ------------------------------------------------------------------

  void _registerCommandDelegate() {
    try {
      final remote = _ref.read(remoteControlProvider.notifier);
      remote.localCommandDelegate = _handleLocalCommand;
      remote.syncLocalDevices(_remoteDevicesFromState());
    } catch (e) {
      debugPrint('[AurisLocal] No se pudo registrar delegado: $e');
    }
  }

  void _pushLocalDevices() {
    try {
      _ref.read(remoteControlProvider.notifier).syncLocalDevices(
            _remoteDevicesFromState(),
          );
    } catch (_) {}
  }

  List<RemoteDevice> _remoteDevicesFromState() {
    return state.devices
        .map((tv) => remoteDeviceFor('local:${tv.tvId}'))
        .whereType<RemoteDevice>()
        .toList();
  }

  RemoteDeviceType? _guessType() {
    if (kIsWeb) return RemoteDeviceType.web;
    if (Platform.isAndroid || Platform.isIOS) return RemoteDeviceType.android;
    return null;
  }

  // ------------------------------------------------------------------
  // Comandos (delegado de sendCommand del bus común)
  // ------------------------------------------------------------------

  Future<bool> _handleLocalCommand(String action, Map<String, dynamic>? data) async {
    final targetId = _ref.read(remoteControlProvider).activeTargetDeviceId;
    final tv = targetId == null ? null : beaconFor(targetId);
    if (tv == null) return false;

    if (action == 'open_media') {
      final params = data?['params'];
      final res = await _post(
        tv.uri('/cast/start'),
        {
          'deviceId': deviceId,
          'deviceName': _deviceName,
          if (isPaired(tv)) 'token': _tokens[tv.tvId],
          'params': params,
        },
      );
      if (res != null) _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
      return res != null;
    }

    final res = await _post(
      tv.uri('/cast/control'),
      {
        'deviceId': deviceId,
        'deviceName': _deviceName,
        if (isPaired(tv)) 'token': _tokens[tv.tvId],
        'action': action,
        if (data != null) ...data,
      },
    );
    return res != null;
  }

  // ------------------------------------------------------------------
  // Emparejamiento (PIN)
  // ------------------------------------------------------------------

  /// Paso 1: si ya hay token, queda emparejado; si no, la TV entra en modo
  /// PIN (mostrándolo en pantalla). Puede fallar por TV ocupada.
  Future<bool> startPairing(LocalTvBeacon tv) async {
    await _loadTokens();
    if (isPaired(tv)) {
      final ok = await _verifyCachedPairing(tv);
      return ok;
    }

    final res = await _post(tv.uri('/pair/start'), {
      'deviceId': deviceId,
      'deviceName': _deviceName,
    });
    if (res == null) return false;
    if (res['paired'] == true && res['token'] != null) {
      _tokens[tv.tvId] = res['token'].toString();
      await _saveTokens();
      state = state.copyWith(pairingTvId: null, pairingError: null);
      return true;
    }
    state = state.copyWith(pairingTvId: tv.tvId, pairingError: null);
    return false;
  }

  /// Paso 2: verifica el PIN que la TV muestra; al acertar guarda el token.
  Future<bool> verifyPin(LocalTvBeacon tv, String pin) async {
    final res = await _post(tv.uri('/pair/verify'), {
      'deviceId': deviceId,
      'deviceName': _deviceName,
      'pin': pin,
    });
    if (res == null) {
      state = state.copyWith(
          pairingError: 'No se pudo verificar. Inténtalo de nuevo.');
      return false;
    }
    if (res['paired'] != true || res['token'] == null) {
      final reason = res['error']?.toString();
      state = state.copyWith(
          pairingError: reason ?? 'PIN incorrecto. Revisa el código en la TV.');
      return false;
    }
    _tokens[tv.tvId] = res['token'].toString();
    await _saveTokens();
    state = state.copyWith(pairingTvId: null, pairingError: null);
    return true;
  }

  void cancelPairing() {
    final tvId = state.pairingTvId;
    final tv = tvId == null
        ? null
        : beaconFor('local:$tvId');
    if (tv != null) {
      // Notifica a la TV que se canceló (limpia el PIN en pantalla).
      _post(tv.uri('/pair/cancel'), {'deviceId': deviceId});
    }
    state = state.copyWith(pairingTvId: null, pairingError: null);
  }

  Future<bool> _verifyCachedPairing(LocalTvBeacon tv) async {
    try {
      final client = await _client();
      final req = await client.postUrl(tv.uri('/pair/start'));
      req.headers.contentType = ContentType.json;
      req.headers.set('X-Auris-Device', deviceId);
      req.headers.set('X-Auris-Token', _tokens[tv.tvId] ?? '');
      req.write(jsonEncode({
        'deviceId': deviceId,
        'deviceName': _deviceName,
        'token': _tokens[tv.tvId],
      }));
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      final map = jsonDecode(text);
      return map is Map<String, dynamic> && map['paired'] == true;
    } catch (e) {
      debugPrint('[AurisLocal] Re-validación de pairing falló: $e');
      return false;
    }
  }

  // ------------------------------------------------------------------
  // Polling del status de la sesión activa (anima el timeline)
  // ------------------------------------------------------------------

  void _startStatusPolling() {
    _pollTimer ??= Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      final targetId =
          _ref.read(remoteControlProvider).activeTargetDeviceId;
      if (targetId == null || !targetId.startsWith('local:')) {
        _statusFailures = 0;
        return;
      }
      final tv = beaconFor(targetId);
      if (tv == null) {
        _statusFailures++;
        if (_statusFailures >= 3) {
          _statusFailures = 0;
          // TV desapareció de la red → handback al local (los listeners del
          // player reaccionan al cambio de target como en el cast Supabase).
          _ref.read(remoteControlProvider.notifier).setActiveTarget(null);
        }
        return;
      }

      final res = await _getAuthed(tv, '/cast/status');
      if (res == null || res['ok'] != true) {
        _statusFailures++;
        if (_statusFailures >= 4) {
          _statusFailures = 0;
          _ref.read(remoteControlProvider.notifier).setActiveTarget(null);
        }
        return;
      }
      _statusFailures = 0;

      final st = _status[tv.tvId] ?? {};
      final newPos = (res['positionMs'] as num?)?.toInt() ?? 0;
      final newDur = (res['durationMs'] as num?)?.toInt() ?? 0;
      final oldPos = (st['positionMs'] as num?)?.toInt() ?? 0;
      final oldDur = (st['durationMs'] as num?)?.toInt() ?? 0;

      final String? titleRes = res['mediaTitle'] as String?;

      _status[tv.tvId] = {
        'positionMs': (newPos > 0 || res['loaded'] == true) ? newPos : oldPos,
        'durationMs': newDur > 0 ? newDur : oldDur,
        'isPlaying': res['isPlaying'] == true,
        'mediaTitle': (titleRes != null && titleRes.isNotEmpty) ? titleRes : st['mediaTitle'],
        'tracks': res['tracks'] ?? st['tracks'],
        'selectedTrackIndex': res['selectedTrackIndex'] ?? st['selectedTrackIndex'],
      };
      _pushLocalDevices();

      // La TV reporta sin player activo (se cerró allá): handback, salvo
      // en la ventana de arranque (la TV aún está abriendo el player).
      if (res['loaded'] == false) {
        final sinceCast = DateTime.now().millisecondsSinceEpoch - _sessionStartMs;
        if (sinceCast > const Duration(seconds: 8).inMilliseconds) {
          _ref.read(remoteControlProvider.notifier).setActiveTarget(null);
        }
        return;
      }
    });
  }

  // ------------------------------------------------------------------
  // HTTP helpers
  // ------------------------------------------------------------------

  Future<HttpClient> _client() {
    _http ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    return Future.value(_http!);
  }

  Map<String, String> get _authHeaders => {
        'X-Auris-Device': deviceId,
      };

  Future<Map<String, String>> _authFor(LocalTvBeacon tv) async {
    await _loadTokens();
    return {
      ..._authHeaders,
      if (isPaired(tv)) 'X-Auris-Token': _tokens[tv.tvId]!,
    };
  }

  /// POST JSON; devuelve el mapa de respuesta o null si falló.
  Future<Map<String, dynamic>?> _post(Uri uri, Map<String, dynamic> body,
      {Map<String, String> headers = const {}}) async {
    try {
      final client = await _client();
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      headers.forEach(req.headers.set);
      req.write(jsonEncode(body));
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        debugPrint('[AurisLocal] ${uri.path} -> HTTP ${res.statusCode}');
        return null;
      }
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : {'ok': true};
    } catch (e) {
      debugPrint('[AurisLocal] POST ${uri.path} falló: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getAuthed(LocalTvBeacon tv, String path) async {
    try {
      final client = await _client();
      final req = await client.getUrl(tv.uri(path));
      final headers = await _authFor(tv);
      headers.forEach(req.headers.set);
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('[AurisLocal] GET $path falló: $e');
      return null;
    }
  }

  // ------------------------------------------------------------------
  // Persistencia de tokens (secure storage)
  // ------------------------------------------------------------------

  Future<void> _loadTokens() async {
    if (_tokensLoaded) return;
    _tokensLoaded = true;
    try {
      final raw = await _secure.read(key: 'localcast_tokens');
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        map.forEach((k, v) {
          if (v != null) _tokens[k] = v.toString();
        });
      }
    } catch (e) {
      debugPrint('[AurisLocal] Error leyendo tokens: $e');
    }
  }

  Future<void> _saveTokens() async {
    try {
      await _secure.write(
        key: 'localcast_tokens',
        value: jsonEncode(_tokens),
      );
    } catch (e) {
      debugPrint('[AurisLocal] Error guardando tokens: $e');
    }
  }
}
