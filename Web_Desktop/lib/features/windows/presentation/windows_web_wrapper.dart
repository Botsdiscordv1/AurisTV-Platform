import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _initWebView();
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
    // El WinWebViewController se encarga de su limpieza nativa
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
