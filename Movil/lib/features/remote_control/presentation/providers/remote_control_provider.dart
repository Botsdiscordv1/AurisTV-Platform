import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../data/models/remote_device.dart';
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
    bool? isInitialized,
    Map<String, dynamic>? lastReceivedCommand,
  }) {
    return RemoteControlState(
      availableDevices: availableDevices ?? this.availableDevices,
      currentDevice: currentDevice ?? this.currentDevice,
      activeTargetDeviceId: activeTargetDeviceId ?? this.activeTargetDeviceId,
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
    if (current == null) return;
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
    if (current == null) return;
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

    // 4. Registrarse en Supabase y empezar Heartbeat
    await _registerDevice();
    await _purgeStaleSessions(user.id);
    _startHeartbeat();
    _listenToDevices();
    _subscribeToCommands();
  }

  Future<void> _purgeStaleSessions(String userId) async {
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
    if (state.currentDevice == null) return;
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
      if (state.currentDevice == null) return;
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
    if (user == null) return;

    _devicesSubscription = _supabase
        .from('remote_sessions')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((data) {
          final devices = data.map((d) => RemoteDevice.fromJson(d)).toList();
          state = state.copyWith(availableDevices: devices);
        });
  }

  void _subscribeToCommands() {
    final currentDevice = state.currentDevice;
    if (currentDevice == null) return;

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

  void setActiveTarget(String? deviceId) {
    state = state.copyWith(activeTargetDeviceId: deviceId);
    if (deviceId != null) {
      _userBox.put('active_remote_target_id', deviceId);
    } else {
      _userBox.delete('active_remote_target_id');
    }
  }

  Future<void> sendCommand(String targetDeviceId, String action, [Map<String, dynamic>? data]) async {
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
