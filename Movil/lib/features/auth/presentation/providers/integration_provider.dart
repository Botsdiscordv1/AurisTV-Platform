import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:auris_core/auris_core.dart';
import 'auth_web_helper.dart';

final integrationProvider = StateNotifierProvider<IntegrationNotifier, void>((ref) {
  return IntegrationNotifier(ref);
});

class IntegrationNotifier extends StateNotifier<void> {
  final Ref _ref;
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Dio _dio = Dio();
  final _webHelper = getAuthWebHelper();

  IntegrationNotifier(this._ref) : super(null);

  Future<void> connectAnilist() async {
    final String baseUrl = kIsWeb ? _webHelper.getOrigin() : 'auristv';
    final String redirectUrl = kIsWeb ? '$baseUrl/auth.html' : 'auristv://auth';
    const String clientId = '47461';

    if (kIsWeb) {
      // Senior Web: Usar un flujo más limpio para navegadores
      final authUrl = 'https://anilist.co/api/v2/oauth/authorize'
          '?client_id=$clientId'
          '&redirect_uri=${Uri.encodeComponent(redirectUrl)}'
          '&response_type=code';
      
      debugPrint('Lanzando Auth Web: $authUrl');
      _webHelper.launchWebAuth(
        url: authUrl,
        type: ConnectionType.anilist,
        redirectUrl: redirectUrl,
        onCodeReceived: (code) async {
          debugPrint('Código recibido para AniList en Web: $code');
          await _exchangeCodeAndSave(ConnectionType.anilist, code, redirectUrl);
          _ref.invalidate(authProvider);
        },
      );
      return;
    }

    try {
      final AuthorizationTokenResponse? result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId,
          redirectUrl,
          clientSecret: 'pVT1qkvvPgKx0LITjRjyxEUj7p0y1w902cWhXuJV',
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: 'https://anilist.co/api/v2/oauth/authorize',
            tokenEndpoint: 'https://anilist.co/api/v2/oauth/token',
          ),
          scopes: [],
        ),
      );

      if (result != null && result.accessToken != null) {
        final username = await _fetchUserInfo(ConnectionType.anilist, result.accessToken!);
        await _saveConnection(
          ConnectionType.anilist,
          result.accessToken!,
          result.refreshToken,
          username,
        );
      }
    } catch (e) {
      debugPrint('Error en Auth AniList: $e');
    }
  }

  Future<void> connectSimkl() async {
    final String baseUrl = kIsWeb ? _webHelper.getOrigin() : 'auristv';
    final String redirectUrl = kIsWeb ? '$baseUrl/auth.html' : 'auristv://auth';
    const String clientId = '94c50a3ed9065c424642fde877285505424b4a1349fc6ef467992f4075c1e115';

    if (kIsWeb) {
      final authUrl = 'https://simkl.com/oauth/authorize?client_id=$clientId&redirect_uri=${Uri.encodeComponent(redirectUrl)}&response_type=code';
      _webHelper.launchWebAuth(
        url: authUrl,
        type: ConnectionType.simkl,
        redirectUrl: redirectUrl,
        onCodeReceived: (code) async {
          debugPrint('Código recibido para Simkl en Web: $code');
          await _exchangeCodeAndSave(ConnectionType.simkl, code, redirectUrl);
          _ref.invalidate(authProvider);
        },
      );
      return;
    }

    try {
      final AuthorizationTokenResponse? result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId,
          redirectUrl,
          clientSecret: 'daf68331ba4eee2b5d7b1df9a68e544ba4544f649fd3601c4eecaf97fa9101b3',
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: 'https://simkl.com/oauth/authorize',
            tokenEndpoint: 'https://api.simkl.com/oauth/token',
          ),
          scopes: [],
        ),
      );

      if (result != null && result.accessToken != null) {
        final username = await _fetchUserInfo(ConnectionType.simkl, result.accessToken!);
        await _saveConnection(
          ConnectionType.simkl,
          result.accessToken!,
          result.refreshToken,
          username,
        );
      }
    } catch (e) {
      debugPrint('Error en Auth Simkl: $e');
    }
  }

  Future<void> _exchangeCodeAndSave(ConnectionType type, String code, String redirectUrl) async {
    try {
      String tokenEndpoint = '';
      String clientId = '';
      String clientSecret = '';

      if (type == ConnectionType.anilist) {
        tokenEndpoint = 'https://anilist.co/api/v2/oauth/token';
        clientId = '47461';
        clientSecret = 'pVT1qkvvPgKx0LITjRjyxEUj7p0y1w902cWhXuJV';
      } else {
        tokenEndpoint = 'https://api.simkl.com/oauth/token';
        clientId = '94c50a3ed9065c424642fde877285505424b4a1349fc6ef467992f4075c1e115';
        clientSecret = 'daf68331ba4eee2b5d7b1df9a68e544ba4544f649fd3601c4eecaf97fa9101b3';
      }

      final response = await _dio.post(
        tokenEndpoint, 
        data: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'client_secret': clientSecret,
          'redirect_uri': redirectUrl,
          'code': code,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'Accept': 'application/json'},
        ),
      );

      final accessToken = response.data['access_token'];
      final refreshToken = response.data['refresh_token'];

      if (accessToken != null) {
        final username = await _fetchUserInfo(type, accessToken);
        await _saveConnection(type, accessToken, refreshToken, username);
      }
    } catch (e) {
      debugPrint('Error intercambiando código: $e');
    }
  }

  Future<String> _fetchUserInfo(ConnectionType type, String token) async {
    try {
      if (type == ConnectionType.anilist) {
        final response = await _dio.post(
          'https://graphql.anilist.co',
          data: {
            'query': '{ Viewer { name } }',
          },
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        return response.data['data']['Viewer']['name'] ?? 'AnilistUser';
      } else {
        final response = await _dio.get(
          'https://api.simkl.com/users/settings',
          options: Options(headers: {
            'Authorization': 'Bearer $token',
            'simkl-api-key': '94c50a3ed9065c424642fde877285505424b4a1349fc6ef467992f4075c1e115',
          }),
        );
        return response.data['user']?['name'] ?? 'SimklUser';
      }
    } catch (e) {
      debugPrint('Error obteniendo info de usuario: $e');
      return '${type.name}User';
    }
  }

  Future<void> _saveConnection(ConnectionType type, String token, String? refresh, String username) async {
    // Save to Secure Storage
    await _storage.write(key: '${type.name}_token', value: token);
    if (refresh != null) {
      await _storage.write(key: '${type.name}_refresh', value: refresh);
    }

    // Update the UserAccount state in authProvider
    final currentUser = _ref.read(authProvider) ?? UserAccount(id: 'local_user');
    
    final updatedConnections = Map<ConnectionType, ExternalConnection>.from(currentUser.connections);
    updatedConnections[type] = ExternalConnection(
      type: type,
      accessToken: token,
      refreshToken: refresh,
      username: username,
      lastSynced: DateTime.now(),
    );
    
    // Senior: Usar el nuevo método de actualización persistente
    _ref.read(authProvider.notifier).updateConnections(updatedConnections);
  }
}
