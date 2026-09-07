import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../auris_core.dart';
import 'auth_provider.dart';
import 'favorites_provider.dart';

final notificationServiceProvider = Provider((ref) => NotificationService(ref));

class NotificationService {
  final Ref ref;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  NotificationService(this.ref);

  Future<void> init() async {
    // 1. Inicializar Firebase (Solo si no está inicializado)
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      debugPrint('[Notifications] Firebase init error: $e');
      return;
    }

    // 2. Configurar Notificaciones Locales (Foreground)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationClick(details.payload);
      },
    );

    // 3. Solicitar Permisos
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Token Registration
    final token = await messaging.getToken();
    if (token != null) {
      _registerToken(token);
    }

    messaging.onTokenRefresh.listen(_registerToken);

    // 5. Handlers de Mensajes
    FirebaseMessaging.onMessage.listen(_showLocalNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((msg) => _handleNotificationClick(msg.data['payload']));
    
    // Background handler debe ser una función top-level (definida fuera de la clase)
    // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 6. Sincronizar Favoritos (Auto-suscripción a Temas)
    _initFavoritesSync();
  }

  void _registerToken(String token) {
    final user = ref.read(authProvider);
    if (user != null && user.id != null) {
      final repo = ref.read(aurisRepositoryProvider);
      final platform = kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios');
      repo.registerDeviceToken(user.id!, token, platform);
    }
  }

  void _initFavoritesSync() {
    // Escuchamos cambios en los favoritos para suscribir/desuscribir al usuario
    ref.listen(favoritesProvider, (previous, next) {
      final oldIds = previous?.map((f) => f.id).toSet() ?? {};
      final newIds = next.map((f) => f.id).toSet();

      final toSubscribe = newIds.difference(oldIds);
      final toUnsubscribe = oldIds.difference(newIds);

      final user = ref.read(authProvider);
      if (user != null && user.id != null) {
        final repo = ref.read(aurisRepositoryProvider);
        
        for (final id in toSubscribe) {
          final topic = _cleanTopicId(id);
          repo.subscribeToTopic(user.id!, topic);
          FirebaseMessaging.instance.subscribeToTopic(topic);
        }

        for (final id in toUnsubscribe) {
          final topic = _cleanTopicId(id);
          repo.unsubscribeFromTopic(user.id!, topic);
          FirebaseMessaging.instance.unsubscribeFromTopic(topic);
        }
      }
    });
  }

  String _cleanTopicId(String id) {
    // Los tópicos de Firebase solo permiten [a-zA-Z0-9-_.~%]{1,900}
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9-_]'), '_');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'auristv_updates',
            'Nuevos Episodios',
            channelDescription: 'Notificaciones de nuevos capítulos de tus favoritos',
            importance: Importance.max,
            priority: Priority.high,
            icon: android?.smallIcon,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: message.data['payload'],
      );
    }
  }

  void _handleNotificationClick(String? payload) {
    if (payload == null) return;
    
    try {
      // El payload debería ser una URI de ruteo (ej: /content/Mushoku%20Tensei)
      // ref.read(routerProvider).push(payload);
      debugPrint('[Notifications] Handled click with payload: $payload');
    } catch (e) {
      debugPrint('[Notifications] Click handler error: $e');
    }
  }
}
