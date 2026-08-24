import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class HttpRequestFactory {
  const HttpRequestFactory();

  Future<Response> request(
    Uri uri, {
    required LoadRequestMethod method,
    Map<String, String>? headers,
    Uint8List? data,
  }) async {
    final request = RequestInit(
      method: method.serialize(),
      headers: headers.jsify()! as HeadersInit,
      body: data?.toJS,
    );

    return window.fetch(uri.toString().toJS, request).toDart;
  }
}
