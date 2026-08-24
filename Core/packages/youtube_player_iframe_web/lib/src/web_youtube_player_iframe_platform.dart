import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:youtube_player_iframe_web/src/web_youtube_player_iframe_controller.dart';

class WebYoutubePlayerIframePlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return WebYoutubePlayerIframeController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return YoutubePlayerIframeWeb(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return WebNavigationDelegate(params);
  }

  static void registerWith(Registrar registrar) {
    WebViewPlatform.instance = WebYoutubePlayerIframePlatform();
  }
}

class WebNavigationDelegate extends PlatformNavigationDelegate {
  WebNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
}
