import 'auth_web_helper.dart';
import 'package:auris_core/auris_core.dart';

class AuthWebHelperIO implements AuthWebHelper {
  @override
  String getOrigin() => '';

  @override
  void launchWebAuth({
    required String url,
    required ConnectionType type,
    required String redirectUrl,
    required Function(String code) onCodeReceived,
  }) {
    // No-op on IO (Mobile/Desktop use FlutterAppAuth)
  }
}

AuthWebHelper getAuthWebHelperImpl() => AuthWebHelperIO();
