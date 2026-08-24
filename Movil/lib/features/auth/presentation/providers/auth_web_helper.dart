import 'auth_web_helper_io.dart'
    if (dart.library.js_interop) 'auth_web_helper_web.dart' as impl;
import 'package:auris_core/auris_core.dart';

abstract class AuthWebHelper {
  String getOrigin();
  void launchWebAuth({
    required String url,
    required ConnectionType type,
    required String redirectUrl,
    required Function(String code) onCodeReceived,
  });
}

AuthWebHelper getAuthWebHelper() => impl.getAuthWebHelperImpl();
