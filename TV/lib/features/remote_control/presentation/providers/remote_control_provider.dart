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
  final bool isInitialized;
  final Map<String, dynamic>? lastReceivedCommand;

  RemoteControlState({
    this.availableDevices = const [],
    this.currentDevice,
    this.isInitialized = false,
    this.lastReceivedCommand,
  });

  RemoteControlState copyWith({
    List<RemoteDevice>? availableDevices,
    RemoteDevice? currentDevice,
    bool? isInitialized,
    Map<String, dynamic>? lastReceivedCommand,
  }) {
    return RemoteControlState(
      availableDevices: availableDevices ?? this.availableDevices,
      currentDevice: currentDevice ?? this.currentDevice,
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
    } catch (_) {}
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
    } catch (_) {}
  }

  Future<void> _init() async {
    _ref.listen(authProvider, (previous, next) {
      if (next != null && previous == null) {
        _initSession(next);
      } else if (next == null && previous != null) {
        _stopRemote();
      }
    }, fireImmediately: true);
  }

  Future<void> _initSession(dynamic user) async {
    String deviceId = _userBox.get('remote_device_id') ?? '';
    if (deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await _userBox.put('remote_device_id', deviceId);
    }

    String deviceName = 'Auris TV';
    RemoteDeviceType type = RemoteDeviceType.android; // TV is Android-based

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      deviceName = androidInfo.model;
    } catch (_) {}

    final currentDevice = RemoteDevice(
      id: deviceId,
      userId: user.id,
      name: deviceName,
      type: type,
    );

    state = state.copyWith(currentDevice: currentDevice, isInitialized: true);

    await _registerDevice();
    await _purgeStaleSessions(user.id);
    _startHeartbeat();
    _subscribeToCommands();
  }

  Future<void> _purgeStaleSessions(String userId) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String();
      await _supabase.from('remote_sessions').update({'is_online': false}).match({
        'user_id': userId,
        'is_online': true,
      }).lt('last_seen', cutoff);
    } catch (_) {}
  }

  Future<void> _registerDevice() async {
    if (state.currentDevice == null) return;
    try {
      await _supabase.from('remote_sessions').upsert(
        state.currentDevice!.toJson(),
        onConflict: 'user_id, device_id',
      );
    } catch (_) {}
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
      } catch (_) {}
    });
  }

  void _subscribeToCommands() {
    final currentDevice = state.currentDevice;
    if (currentDevice == null) return;

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
    } catch (_) {}
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
