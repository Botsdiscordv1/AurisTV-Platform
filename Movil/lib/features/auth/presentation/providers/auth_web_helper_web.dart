import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'auth_web_helper.dart';
import 'package:auris_core/auris_core.dart';

@JS('JSON.stringify')
external String _jsStringify(JSAny obj);

class AuthWebHelperWeb implements AuthWebHelper {
  @override
  String getOrigin() => web.window.location.origin;

  @override
  void launchWebAuth({
    required String url,
    required ConnectionType type,
    required String redirectUrl,
    required Function(String code) onCodeReceived,
  }) {
    final web.Window? popup = web.window.open(url, 'auth', 'width=600,height=600');
    
    if (popup == null) return;

    StreamSubscription? sub;
    sub = web.window.onMessage.listen((event) {
      final JSAny? rawData = event.data;
      if (rawData == null) return;

      Map? data;
      if (rawData.isA<JSString>()) {
        try {
          final String str = (rawData as JSString).toDart;
          data = jsonDecode(str) as Map;
        } catch (_) {}
      } else if (rawData.isA<JSObject>()) {
        try {
          final String jsonStr = _jsStringify(rawData);
          data = jsonDecode(jsonStr) as Map;
        } catch (_) {}
      }

      if (data != null && data['type'] == 'authorization_response') {
        final responseUrl = data['response'] as String;
        final uri = Uri.parse(responseUrl.replaceFirst('#', '?')); // Normalizar fragments como query params
        
        final accessToken = uri.queryParameters['access_token'];
        final code = uri.queryParameters['code'];
        
        if (accessToken != null) {
          onCodeReceived('token:$accessToken');
        } else if (code != null) {
          onCodeReceived(code);
        }
        sub?.cancel();
      }
    });
  }
}

AuthWebHelper getAuthWebHelperImpl() => AuthWebHelperWeb();

