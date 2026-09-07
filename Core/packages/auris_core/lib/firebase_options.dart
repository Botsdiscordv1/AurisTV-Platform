import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Senior Firebase Configuration: Autogenerado manualmente para soportar 
/// la arquitectura triple-plataforma de AurisTV.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDjBjcs5NoI_ZUjPRx_J0wLgE7kqBXRHLs',
    appId: '1:551312224458:web:9b25b062d8c8063d948433',
    messagingSenderId: '551312224458',
    projectId: 'device-streaming-da6dfeda',
    authDomain: 'device-streaming-da6dfeda.firebaseapp.com',
    storageBucket: 'device-streaming-da6dfeda.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDjBjcs5NoI_ZUjPRx_J0wLgE7kqBXRHLs',
    appId: '1:551312224458:android:7d6d5f7a2b9c3e4f', // Este valor vendrá del google-services.json
    messagingSenderId: '551312224458',
    projectId: 'device-streaming-da6dfeda',
    storageBucket: 'device-streaming-da6dfeda.firebasestorage.app',
  );
}
