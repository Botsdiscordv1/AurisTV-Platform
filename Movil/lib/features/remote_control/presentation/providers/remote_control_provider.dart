import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:auristv_mobile/features/remote_control/data/models/remote_device.dart';
import 'package:auris_core/auris_core.dart';

final remoteControlProvider = StateNotifierProvider<RemoteControlNotifier, RemoteControlState>((ref) {
  return RemoteControlNotifier(ref);
});

class RemoteControlState {
  final List<RemoteDevice> availableDevices;
  final RemoteDevice? currentDevice;
  final String? activeTargetDeviceId; // ID del dispositivo que estamos controlando
  final bool isInitialized;
  final Map<String, dynamic>? lastReceivedCommand;

  RemoteControlState({
    this.availableDevices = const [],
    this.currentDevice,
    this.activeTargetDeviceId,
    this.isInitialized = false,
    this.lastReceivedCommand,
  });

  RemoteControlState copyWith({
    List<RemoteDevice>? availableDevices,
    RemoteDevice? currentDevice,
    String? activeTargetDeviceId,
    bool clearActiveTarget = false,
    bool? isInitialized,
    Map<String, dynamic>? lastReceivedCommand,
  }) {
    return RemoteControlState(
      availableDevices: availableDevices ?? this.availableDevices,
      currentDevice: currentDevice ?? this.currentDevice,
      activeTargetDeviceId: clearActiveTarget
          ? null
          : (activeTargetDeviceId ?? this.activeTargetDeviceId),
      isInitialized: isInitialized ?? this.isInitialized,
      lastReceivedCommand: lastReceivedCommand ?? this.lastReceivedCommand,
    );
  }
}

class RemoteControlNotifier extends StateNotifier<RemoteControlState> with WidgetsBindingObserver {
  final Ref _ref;
  final _supabase = Supabase.instance.client;
  final _userBox = Hive.box('user_data');
  Timer? _heartbeatTimer;
  RealtimeChannel? _channel;
  StreamSubscription? _devicesSubscription;

  /// Dispositivos cast LAN descubertos/emparejados localmente (local_cast).
  /// Conviven con los de Supabase en `availableDevices` para que el overlay
  /// del player y los selectores funcionen igual en ambos transportes.
  final Map<String, RemoteDevice> _localDevices = {};

  /// Delegado del transporte local (lo registra local_cast_provider al
  /// inicializar). Evita la dependencia directa remote_control → local_cast.
  Future<bool> Function(String action, Map<String, dynamic>? data)?
      localCommandDelegate;

  RemoteControlNotifier(this._ref) : super(RemoteControlState()) {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _setOffline();
    } else if (state == AppLifecycleState.resumed) {
      _setOnline();
    }
  }

  Future<void> _setOffline() async {
    final current = state.currentDevice;
    if (current == null || current.userId == 'guest_user') return;
    try {
      await _supabase.from('remote_sessions').update({
        'is_online': false,
        'last_seen': DateTime.now().toIso8601String(),
      }).match({
        'user_id': current.userId,
        'device_id': current.id,
      });
      debugPrint('[AurisRemote] Device set to OFFLINE');
    } catch (e) {
      debugPrint('Error setting offline: $e');
    }
  }

  Future<void> _setOnline() async {
    final current = state.currentDevice;
    if (current == null || current.userId == 'guest_user') return;
    try {
      await _supabase.from('remote_sessions').update({
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
      }).match({
        'user_id': current.userId,
        'device_id': current.id,
      });
      debugPrint('[AurisRemote] Device set to ONLINE');
    } catch (e) {
      debugPrint('Error setting online: $e');
    }
  }

  Future<void> _init() async {
    // Escuchar cambios de autenticación para reiniciar o detener
    _ref.listen(authProvider, (previous, next) {
      if (next != null && previous == null) {
        _initSession(next);
      } else if (next == null && previous != null) {
        _stopRemote();
      }
    }, fireImmediately: true);
  }

  Future<void> _initSession(dynamic user) async {
    debugPrint('[AurisRemote] Initializing session for user: ${user.id}');

    // 1. Obtener o generar ID de dispositivo
    String deviceId = _userBox.get('remote_device_id') ?? '';
    if (deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await _userBox.put('remote_device_id', deviceId);
    }

    // 2. Obtener nombre del dispositivo
    String deviceName = 'Auris Player';
    RemoteDeviceType type = RemoteDeviceType.other;

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        deviceName = 'Web Browser';
        type = RemoteDeviceType.web;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = androidInfo.model;
        type = RemoteDeviceType.android;
      } else if (Platform.isWindows) {
        deviceName = 'Windows PC';
        type = RemoteDeviceType.windows;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
        type = RemoteDeviceType.ios;
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    final currentDevice = RemoteDevice(
      id: deviceId,
      userId: user.id,
      name: deviceName,
      type: type,
    );

    state = state.copyWith(currentDevice: currentDevice, isInitialized: true);

    // 3. Cargar último objetivo guardado
    final savedTargetId = _userBox.get('active_remote_target_id');
    if (savedTargetId != null) {
      state = state.copyWith(activeTargetDeviceId: savedTargetId);
    }

    // 4. Registrarse en Supabase y empezar Heartbeat (solo si no es invitado)
    if (user.id != 'guest_user') {
      await _registerDevice();
      await _purgeStaleSessions(user.id);
      _startHeartbeat();
      _listenToDevices();
      _subscribeToCommands();
    }
  }

  Future<void> _purgeStaleSessions(String userId) async {
    if (userId == 'guest_user') return;
    try {
      // Senior Purgue Logic: Cualquier sesión que no se haya visto en más de 10 minutos
      // y esté marcada como online, se considera "estancada" y se limpia.
      final cutoff = DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String();
      
      await _supabase.from('remote_sessions').update({
        'is_online': false
      }).match({
        'user_id': userId,
        'is_online': true,
      }).lt('last_seen', cutoff);
      
      debugPrint('[AurisRemote] Stale sessions purged');
    } catch (e) {
      debugPrint('Error purging stale sessions: $e');
    }
  }

  Future<void> _registerDevice() async {
    if (state.currentDevice == null || state.currentDevice!.userId == 'guest_user') return;
    try {
      await _supabase.from('remote_sessions').upsert(
        state.currentDevice!.toJson(),
        onConflict: 'user_id, device_id',
      );
    } catch (e) {
      debugPrint('Error registering remote device: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (state.currentDevice == null || state.currentDevice!.userId == 'guest_user') return;
      try {
        await _supabase.from('remote_sessions').update({
          'last_seen': DateTime.now().toIso8601String(),
          'is_online': true,
        }).match({
          'user_id': state.currentDevice!.userId,
          'device_id': state.currentDevice!.id,
        });
      } catch (e) {
        debugPrint('Heartbeat failed: $e');
      }
    });
  }

  void _listenToDevices() {
    _devicesSubscription?.cancel();
    final user = _ref.read(authProvider);
    if (user == null || user.id == 'guest_user') return;

    _devicesSubscription = _supabase
        .from('remote_sessions')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((data) {
          final devices = data.map((d) => RemoteDevice.fromJson(d)).toList();
          state = state.copyWith(availableDevices: devices);
          _mergeAvailableDevices();
        });
  }

  void _subscribeToCommands() {
    final currentDevice = state.currentDevice;
    if (currentDevice == null || currentDevice.userId == 'guest_user') return;

    // Usamos Postgres Changes para escuchar actualizaciones en nuestro registro
    _supabase
        .channel('remote_commands:${currentDevice.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'remote_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'device_id',
            value: currentDevice.id,
          ),
          callback: (payload) {
            final newData = payload.newRecord;
            final lastCommand = newData['last_command'] as Map<String, dynamic>?;
            
            if (lastCommand != null && lastCommand.isNotEmpty) {
              _processCommand(lastCommand);
            }
          },
        )
        .subscribe();
  }

  void _processCommand(Map<String, dynamic> command) {
    debugPrint('Received remote command: $command');
    state = state.copyWith(lastReceivedCommand: command);
  }

  /// Registra/actualiza los dispositivos locales (cast LAN) visibles ahora
  /// mismo. Se llama desde local_cast_provider con cada beacon/actualización.
  void syncLocalDevices(List<RemoteDevice> devices) {
    _localDevices
      ..clear()
      ..addEntries(devices.map((d) => MapEntry(d.id, d)));
    _mergeAvailableDevices();
  }

  /// Combina Supabase (fuente principal de `availableDevices`) con locales.
  void _mergeAvailableDevices() {
    final supabaseDevices = state.availableDevices
        .where((d) => d.transport != 'local')
        .toList();
    state = state.copyWith(
      availableDevices: [...supabaseDevices, ..._localDevices.values],
    );
  }

  void setActiveTarget(String? deviceId) {
    if (deviceId == null) {
      state = state.copyWith(clearActiveTarget: true);
      _userBox.delete('active_remote_target_id');
    } else {
      state = state.copyWith(activeTargetDeviceId: deviceId);
      _userBox.put('active_remote_target_id', deviceId);
    }
  }

  Future<void> sendCommand(String targetDeviceId, String action, [Map<String, dynamic>? data]) async {
    // Cast LAN (transporte local, sin login): el dispositivo no existe en
    // Supabase; el comando viaja por HTTP directo al server de la TV.
    if (targetDeviceId.startsWith('local:')) {
      final delegate = localCommandDelegate;
      if (delegate == null) {
        debugPrint('[AurisRemote] Sin delegado LOCAL para $targetDeviceId');
        return;
      }
      try {
        await delegate(action, data);
        debugPrint('[AurisRemote] Command LOCAL $action -> $targetDeviceId');
      } catch (e) {
        debugPrint('[AurisRemote] Error comando LOCAL $action: $e');
      }
      return;
    }

    try {
      final command = {
        'action': action,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        if (data != null) ...data,
      };

      await _supabase.from('remote_sessions').update({
        'last_command': command,
      }).match({'device_id': targetDeviceId});
      
      debugPrint('Command sent to $targetDeviceId: $action');
    } catch (e) {
      debugPrint('Error sending remote command: $e');
    }
  }

  Future<void> updateStatus({
    String? mediaTitle,
    String? mediaSource,
    String? mediaUrl,
    String? metadataTitle,
    String? posterUrl,
    String? bannerUrl,
    String? logoUrl,
    String? category,
    String? year,
    int? positionMs,
    int? durationMs,
    bool? isPlaying,
    double? volume,
    List<Map<String, dynamic>>? availableTracks,
    int? selectedTrackIndex,
  }) async {
    final current = state.currentDevice;
    if (current == null) return;

    final updated = current.copyWith(
      mediaTitle: mediaTitle,
      mediaSource: mediaSource,
      mediaUrl: mediaUrl,
      metadataTitle: metadataTitle,
      posterUrl: posterUrl,
      bannerUrl: bannerUrl,
      logoUrl: logoUrl,
      category: category,
      year: year,
      positionMs: positionMs,
      durationMs: durationMs,
      isPlaying: isPlaying,
      volume: volume,
      availableTracks: availableTracks,
      selectedTrackIndex: selectedTrackIndex,
    );

    state = state.copyWith(currentDevice: updated);

    try {
      await _supabase.from('remote_sessions').update(updated.toJson()).match({
        'user_id': current.userId,
        'device_id': current.id,
      });
    } catch (e) {
      // Evitar spam de logs en actualizaciones frecuentes como position
    }
  }

  void _stopRemote() {
    _setOffline();
    _heartbeatTimer?.cancel();
    _devicesSubscription?.cancel();
    _channel?.unsubscribe();
    state = RemoteControlState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRemote();
    super.dispose();
  }
}
