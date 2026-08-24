import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'content_type.dart';
import 'http_request_factory.dart';

@immutable
class WebYoutubePlayerIframeControllerCreationParams
    extends PlatformWebViewControllerCreationParams {
  WebYoutubePlayerIframeControllerCreationParams({
    this.httpRequestFactory = const HttpRequestFactory(),
    this.credentialless = false,
  }) : super();

  WebYoutubePlayerIframeControllerCreationParams.fromPlatformWebViewControllerCreationParams(
    PlatformWebViewControllerCreationParams params, {
    HttpRequestFactory httpRequestFactory = const HttpRequestFactory(),
    bool credentialless = false,
  }) : this(
         httpRequestFactory: httpRequestFactory,
         credentialless: credentialless,
       );

  final HttpRequestFactory httpRequestFactory;
  final bool credentialless;

  static int _nextIFrameId = 0;

  @visibleForTesting
  late final YoutubeIframeElement ytiFrame = YoutubeIframeElement(
    id: _nextIFrameId++,
  )..credentialless = credentialless;
}

class WebYoutubePlayerIframeController extends PlatformWebViewController {
  WebYoutubePlayerIframeController(
    PlatformWebViewControllerCreationParams params,
  ) : super.implementation(
        params is WebYoutubePlayerIframeControllerCreationParams
            ? params
            : WebYoutubePlayerIframeControllerCreationParams.fromPlatformWebViewControllerCreationParams(
                params,
              ),
      );

  WebYoutubePlayerIframeControllerCreationParams get _params {
    return params as WebYoutubePlayerIframeControllerCreationParams;
  }

  JavaScriptChannelParams? _javaScriptChannelParams;
  StreamSubscription<MessageEvent>? _messageSubscription;

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) {
    _params.ytiFrame.srcdoc = html;
    return SynchronousFuture(null);
  }

  @override
  Future<void> runJavaScript(String javaScript) {
    _params.ytiFrame.runFunction(javaScript.replaceAll('"', '<<quote>>'));
    return SynchronousFuture(null);
  }

  @override
  Future<String> runJavaScriptReturningResult(String javaScript) async {
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    final function = javaScript.replaceAll('"', '<<quote>>');

    final completer = Completer<String>();
    final subscription = window.onMessage.listen((event) {
      final data = jsonDecode(event.data.dartify() as String);

      if (data is Map && data.containsKey(key)) {
        completer.complete(data[key].toString());
      }
    });

    _params.ytiFrame.runFunction(function, key: key);

    final result = await completer.future;
    subscription.cancel();

    return result;
  }

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) {
    _javaScriptChannelParams = javaScriptChannelParams;
    return SynchronousFuture(null);
  }

  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) {
    return SynchronousFuture(null);
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> setUserAgent(String? userAgent) async {}

  @override
  Future<void> enableZoom(bool enabled) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    if (!params.uri.hasScheme) {
      throw ArgumentError(
        'LoadRequestParams#uri is required to have a scheme.',
      );
    }

    if (params.headers.isEmpty &&
        (params.body == null || params.body!.isEmpty) &&
        params.method == LoadRequestMethod.get) {
      _params.ytiFrame.src = params.uri.toString();
    } else {
      await _updateIFrameFromXhr(params);
    }
  }

  Future<void> _updateIFrameFromXhr(LoadRequestParams params) async {
    final response = await _params.httpRequestFactory.request(
      params.uri,
      method: params.method,
      headers: params.headers,
      data: params.body,
    );

    final header = response.headers.get('content-type') ?? 'text/html';
    final contentType = ContentType.parse(header);
    final encoding = Encoding.getByName(contentType.charset) ?? utf8;

    final responseText = await response.text().toDart;

    _params.ytiFrame.src = Uri.dataFromString(
      responseText.toDart,
      mimeType: contentType.mimeType,
      encoding: encoding,
    ).toString();
  }
}

class YoutubePlayerIframeWeb extends PlatformWebViewWidget {
  YoutubePlayerIframeWeb(super.params)
    : _controller = params.controller as WebYoutubePlayerIframeController,
      super.implementation() {
    platformViewRegistry.registerViewFactory(
      _controller._params.ytiFrame.id,
      (int viewId) => _controller._params.ytiFrame,
    );
  }

  final WebYoutubePlayerIframeController _controller;

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: params.key,
      viewType: (params.controller as WebYoutubePlayerIframeController)
          ._params
          .ytiFrame
          .id,
      onPlatformViewCreated: (_) {
        final channelParams = _controller._javaScriptChannelParams;

        if (channelParams != null) {
          _controller._messageSubscription?.cancel();
          _controller._messageSubscription = window.onMessage.listen((event) {
            channelParams.onMessageReceived(
              JavaScriptMessage(message: event.data.dartify() as String),
            );
          });
        }
      },
    );
  }
}

extension type YoutubeIframeElement._(HTMLIFrameElement element) {
  YoutubeIframeElement({required int id})
    : element = HTMLIFrameElement()
        ..id = 'youtube-$id'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..allow = 'autoplay; fullscreen; encrypted-media; picture-in-picture; accelerometer; gyroscope; web-share';

  String get id => element.id;

  set src(String value) => element.src = value;

  set srcdoc(String value) {
    element.srcdoc = value.toJS;
    element.src = Uri.dataFromString(
      value,
      mimeType: 'text/html',
      encoding: utf8,
    ).toString();
  }

  set credentialless(bool value) {
    element['credentialless'] = value.toJS;
  }

  void runFunction(String function, {String? key}) {
    element.contentWindow?.postMessage(
      '{"key": "$key", "function": "$function"}'.toJS,
      '*'.toJS,
    );
  }
}
