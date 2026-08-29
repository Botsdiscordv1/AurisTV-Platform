import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class YouTubeTrailerPlayerController extends ChangeNotifier {
  WebViewController? _webViewController;
  bool _isReady = false;
  bool _isMuted = true;
  bool _isPlaying = false;

  bool get isReady => _isReady;
  bool get isMuted => _isMuted;
  bool get isPlaying => _isPlaying;

  void attach(WebViewController controller) {
    _webViewController = controller;
  }

  void detach() {
    _webViewController = null;
    _isReady = false;
    _isPlaying = false;
  }

  Future<void> playVideo() async {
    if (_webViewController == null) return;
    await _webViewController!.runJavaScript('if(window.ytPlayer) window.ytPlayer.playVideo();');
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> pauseVideo() async {
    if (_webViewController == null) return;
    await _webViewController!.runJavaScript('if(window.ytPlayer) window.ytPlayer.pauseVideo();');
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> mute() async {
    if (_webViewController == null) return;
    await _webViewController!.runJavaScript('if(window.ytPlayer) window.ytPlayer.mute();');
    _isMuted = true;
    notifyListeners();
  }

  Future<void> unmute() async {
    if (_webViewController == null) return;
    await _webViewController!.runJavaScript('if(window.ytPlayer) window.ytPlayer.unMute();');
    _isMuted = false;
    notifyListeners();
  }

  Future<void> setVolume(int volume) async {
    if (_webViewController == null) return;
    await _webViewController!.runJavaScript('if(window.ytPlayer) window.ytPlayer.setVolume($volume);');
    _isMuted = volume == 0;
    notifyListeners();
  }

  Future<void> seekTo(int seconds) async {
    if (_webViewController == null) return;
    await _webViewController!.runJavaScript('if(window.ytPlayer) window.ytPlayer.seekTo($seconds, true);');
  }

  void markReady() {
    if (!_isReady) {
      _isReady = true;
      notifyListeners();
    }
  }

  void reset() {
    _isReady = false;
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }
}

class YouTubeTrailerPlayer extends StatefulWidget {
  final YouTubeTrailerPlayerController? controller;
  final String videoId;
  final bool autoPlay;
  final bool mute;
  final double aspectRatio;
  final void Function()? onReady;
  final void Function()? onEnded;

  const YouTubeTrailerPlayer({
    super.key,
    this.controller,
    required this.videoId,
    this.autoPlay = true,
    this.mute = true,
    this.aspectRatio = 16 / 9,
    this.onReady,
    this.onEnded,
  });

  @override
  State<YouTubeTrailerPlayer> createState() => _YouTubeTrailerPlayerState();
}

class _YouTubeTrailerPlayerState extends State<YouTubeTrailerPlayer> {
  late final WebViewController _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void didUpdateWidget(covariant YouTubeTrailerPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _loadVideo(widget.videoId);
    }
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
              _initYouTubePlayer();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_buildEmbedUrl(widget.videoId)));
  }

  void _loadVideo(String videoId) {
    widget.controller?.reset();
    _isLoading = true;
    _webViewController.loadRequest(Uri.parse(_buildEmbedUrl(videoId)));
  }

  String _buildEmbedUrl(String videoId) {
    final params = <String, String>{
      'autoplay': widget.autoPlay ? '1' : '0',
      'mute': widget.mute ? '1' : '0',
      'controls': '0',
      'modestbranding': '1',
      'rel': '0',
      'showinfo': '0',
      'iv_load_policy': '3',
      'playsinline': '1',
      'enablejsapi': '1',
      'origin': 'https://www.youtube.com',
    };
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return 'https://www.youtube.com/embed/$videoId?$query';
  }

  void _initYouTubePlayer() {
    const js = '''
      var tag = document.createElement('script');
      tag.src = "https://www.youtube.com/iframe_api";
      var firstScriptTag = document.getElementsByTagName('script')[0];
      firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

      window.ytPlayer = null;

      function onYouTubeIframeAPIReady() {
        window.ytPlayer = new YT.Player('ytplayer', {
          events: {
            'onReady': function(event) {
              event.target.playVideo();
              window.dispatchEvent(new CustomEvent('yt_ready'));
            },
            'onStateChange': function(event) {
              if (event.data === 0) {
                window.dispatchEvent(new CustomEvent('yt_ended'));
              }
            }
          }
        });
      }
    ''';
    _webViewController.runJavaScript(js);

    widget.controller?.attach(_webViewController);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        widget.controller?.markReady();
        widget.onReady?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
            ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isLoading ? 0.0 : 1.0,
            child: IgnorePointer(
              ignoring: _isLoading,
              child: HtmlElementView(viewType: 'youtube-$runtimeType-${widget.videoId}'),
            ),
          ),
          WebViewWidget(controller: _webViewController),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _webViewController.clearLocalStorage();
    _webViewController.clearCache();
    super.dispose();
  }
}