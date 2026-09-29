import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_win_floating/webview_win_floating.dart';
import 'package:webview_flutter/webview_flutter.dart'; // Importante para JavaScriptMode

class WindowsWebWrapper extends StatefulWidget {
  final String initialUrl;

  const WindowsWebWrapper({
    super.key,
    this.initialUrl = 'https://web-qqo.pages.dev/', // Actualizado a la nueva URL de Cloudflare
  });

  @override
  State<WindowsWebWrapper> createState() => _WindowsWebWrapperState();
}

class _WindowsWebWrapperState extends State<WindowsWebWrapper> {
  late final WinWebViewController _controller;
  bool _isInitialized = false;

  int _virtualVolume = 100; // 0 to 200 (100% normal, 101-200 boost)
  bool _isMuted = false;
  int _lastVolumeBeforeMute = 100;

  static const _volumeControlChannel = MethodChannel('auristv/volume');

  @override
  void initState() {
    super.initState();
    _initWebView();
    _initVolumeChannel();
  }

  void _initVolumeChannel() {
    _volumeControlChannel.setMethodCallHandler((call) async {
      if (call.method == 'volumeUp') {
        _adjustVolume(5);
      } else if (call.method == 'volumeDown') {
        _adjustVolume(-5);
      } else if (call.method == 'volumeMute') {
        _toggleMute();
      }
    });
  }

  void _adjustVolume(int delta) {
    setState(() {
      _virtualVolume = (_virtualVolume + delta).clamp(0, 200);
      if (_virtualVolume > 0 && _isMuted) {
        _isMuted = false;
      }
    });
    _applyVirtualVolumeToWebView();
  }

  void _toggleMute() {
    setState(() {
      if (_isMuted) {
        _isMuted = false;
        _virtualVolume = _lastVolumeBeforeMute;
      } else {
        _isMuted = true;
        _lastVolumeBeforeMute = _virtualVolume > 0 ? _virtualVolume : 100;
        _virtualVolume = 0;
      }
    });
    _applyVirtualVolumeToWebView();
  }

  void _applyVirtualVolumeToWebView() {
    final double effectiveVolume = _isMuted ? 0.0 : (_virtualVolume > 100 ? 1.0 : _virtualVolume / 100.0);
    final double gain = _isMuted ? 0.0 : (_virtualVolume / 100.0);

    final jsCode = """
      (function() {
        const vVol = $_virtualVolume;
        const effVol = $effectiveVolume;
        const gainVal = $gain;
        const isBoost = vVol > 100;

        const videos = document.getElementsByTagName('video');
        for (let video of videos) {
          try {
            video.volume = effVol;
            video.muted = ${_isMuted.toString()};

            if (gainVal > 1.0 || (video._audioCtx && video._audioCtx.state)) {
              if (!video._audioCtx) {
                const AudioContext = window.AudioContext || window.webkitAudioContext;
                if (AudioContext) {
                  video._audioCtx = new AudioContext();
                  video._source = video._audioCtx.createMediaElementSource(video);
                  video._gainNode = video._audioCtx.createGain();
                  video._source.connect(video._gainNode);
                  video._gainNode.connect(video._audioCtx.destination);
                }
              }
              if (video._audioCtx && video._audioCtx.state === 'suspended') {
                video._audioCtx.resume();
              }
              if (video._gainNode) {
                video._gainNode.gain.setTargetAtTime(gainVal, video._audioCtx.currentTime, 0.01);
              }
            }
          } catch(e) {}
        }

        window.dispatchEvent(new CustomEvent('aurisVolumeChanged', { detail: { volume: vVol, boost: isBoost } }));
      })();
    """;

    try {
      _controller.runJavaScript(jsCode);
    } catch (e) {
      debugPrint('Error applying volume to WebView: $e');
    }
  }

  void _initWebView() {
    try {
      _controller = WinWebViewController();
      _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      _controller.loadRequest(Uri.parse(widget.initialUrl));

      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error inicializando WebView Windows Floating: $e');
    }
  }

  @override
  void dispose() {
    _volumeControlChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: !_isInitialized
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : WinWebViewWidget(controller: _controller),
    );
  }
}
