import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

late final AurisAudioHandler audioHandler;

/// Handler de `audio_service` que expone el player de media_kit como notificación
/// media del sistema (shade, lock screen, Bluetooth). Soporta dos modos:
///  - local: observa un `Player` de media_kit (reproducción normal).
///  - remoto: estado alimentado desde fuera (cast), con comandos delegados a
///    callbacks (play/pause/seek/stop del receptor).
class AurisAudioHandler extends BaseAudioHandler with SeekHandler {
  Player? _player;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;

  // Modo remoto (cast).
  bool _remote = false;
  Future<void> Function()? _remotePlay;
  Future<void> Function()? _remotePause;
  Future<void> Function(Duration)? _remoteSeek;
  Future<void> Function()? _remoteStop;
  bool _remotePlaying = false;
  Duration _remotePosition = Duration.zero;
  Duration _remoteDuration = Duration.zero;

  void attach(Player player, {required String title, String? artist, String? artUri}) {
    detach();
    _player = player;
    _remote = false;

    mediaItem.add(MediaItem(
      id: title,
      title: title,
      artist: artist,
      artUri: (artUri != null && artUri.isNotEmpty) ? Uri.tryParse(artUri) : null,
      duration: player.state.duration,
    ));

    _playingSub = player.stream.playing.listen((playing) {
      _updateLocal(playing: playing);
    });
    _posSub = player.stream.position.listen((pos) {
      _updateLocal(position: pos);
    });
    _durSub = player.stream.duration.listen((dur) {
      final mi = mediaItem.value;
      if (mi != null) mediaItem.add(mi.copyWith(duration: dur));
    });

    _updateLocal(playing: player.state.playing, position: player.state.position);
  }

  /// Conecta el handler a una sesión de cast: el estado viene de fuera y los
  /// comandos se delegan a los callbacks. Llamar [updateRemoteState] para
  /// refrescar posición/duración/playing.
  void attachRemote({
    required String title,
    String? artist,
    String? artUri,
    required bool playing,
    required Duration position,
    required Duration duration,
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function(Duration) onSeek,
    required Future<void> Function() onStop,
  }) {
    detach();
    _remote = true;
    _remotePlaying = playing;
    _remotePosition = position;
    _remoteDuration = duration;
    _remotePlay = onPlay;
    _remotePause = onPause;
    _remoteSeek = onSeek;
    _remoteStop = onStop;

    mediaItem.add(MediaItem(
      id: title,
      title: title,
      artist: artist,
      artUri: (artUri != null && artUri.isNotEmpty) ? Uri.tryParse(artUri) : null,
      duration: duration,
    ));
    _updateRemote();
  }

  /// Refresca el estado de la sesión de cast (llamar desde el polling).
  void updateRemoteState({bool? playing, Duration? position, Duration? duration}) {
    if (!_remote) return;
    if (playing != null) _remotePlaying = playing;
    if (position != null) _remotePosition = position;
    if (duration != null) _remoteDuration = duration;
    _updateRemote();
    final mi = mediaItem.value;
    if (mi != null && mi.duration != _remoteDuration) {
      mediaItem.add(mi.copyWith(duration: _remoteDuration));
    }
  }

  void detach() {
    _playingSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _playingSub = null;
    _posSub = null;
    _durSub = null;
    _player = null;
    _remote = false;
    _remotePlay = null;
    _remotePause = null;
    _remoteSeek = null;
    _remoteStop = null;
    mediaItem.add(null);
    playbackState.add(PlaybackState(processingState: AudioProcessingState.idle));
  }

  void _updateLocal({bool? playing, Duration? position}) {
    final p = _player;
    if (p == null) return;
    final isPlaying = playing ?? p.state.playing;
    playbackState.add(PlaybackState(
      controls: const [
        MediaControl.rewind,
        MediaControl.play,
        MediaControl.fastForward,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: isPlaying
          ? AudioProcessingState.ready
          : AudioProcessingState.ready,
      playing: isPlaying,
      updatePosition: position ?? p.state.position,
      bufferedPosition: p.state.buffer,
      speed: p.state.rate,
    ));
  }

  void _updateRemote() {
    playbackState.add(PlaybackState(
      controls: const [
        MediaControl.rewind,
        MediaControl.play,
        MediaControl.fastForward,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _remotePlaying
          ? AudioProcessingState.ready
          : AudioProcessingState.ready,
      playing: _remotePlaying,
      updatePosition: _remotePosition,
      bufferedPosition: _remotePosition,
      speed: 1.0,
    ));
  }

  @override
  Future<void> play() async {
    if (_remote) {
      await _remotePlay?.call();
      return;
    }
    await _player?.play();
  }

  @override
  Future<void> pause() async {
    if (_remote) {
      await _remotePause?.call();
      return;
    }
    await _player?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_remote) {
      await _remoteSeek?.call(position);
      return;
    }
    await _player?.seek(position);
  }

  @override
  Future<void> stop() async {
    if (_remote) {
      await _remoteStop?.call();
      return;
    }
    await _player?.stop();
    await super.stop();
  }

  @override
  Future<void> rewind() async {
    if (_remote) {
      final target = _remotePosition - const Duration(seconds: 10);
      await _remoteSeek?.call(target < Duration.zero ? Duration.zero : target);
      return;
    }
    final p = _player;
    if (p == null) return;
    final target = p.state.position - const Duration(seconds: 10);
    await p.seek(target < Duration.zero ? Duration.zero : target);
  }

  @override
  Future<void> fastForward() async {
    if (_remote) {
      await _remoteSeek?.call(_remotePosition + const Duration(seconds: 10));
      return;
    }
    final p = _player;
    if (p == null) return;
    await p.seek(p.state.position + const Duration(seconds: 10));
  }
}
