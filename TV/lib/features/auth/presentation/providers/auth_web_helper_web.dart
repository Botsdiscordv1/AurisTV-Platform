import 'dart:async';
import 'package:web/web.dart' as web;
import 'auth_web_helper.dart';
import 'package:auris_core/auris_core.dart';

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
      final dynamic rawData = event.data;
      if (rawData is! Map) return;
      
      final Map data = rawData;
      if (data['type'] == 'authorization_response') {
        final responseUrl = data['response'] as String;
        final uri = Uri.parse(responseUrl);
        final code = uri.queryParameters['code'];
        
        if (code != null) {
          onCodeReceived(code);
        }
        sub?.cancel();
      }
    });
  }
}

AuthWebHelper getAuthWebHelperImpl() => AuthWebHelperWeb();
