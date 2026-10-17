import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Un APK publicado en la release de GitHub.
class AppUpdateAsset {
  final String name;
  final String url;
  final int size;

  const AppUpdateAsset({
    required this.name,
    required this.url,
    required this.size,
  });
}

/// Resultado del chequeo de actualización.
class AppUpdateInfo {
  final String latestVersion;
  final String releaseNotes;
  final String releaseUrl;
  final bool forceUpdate;
  final List<AppUpdateAsset> assets;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.releaseUrl,
    required this.forceUpdate,
    required this.assets,
  });
}

/// Comprueba la última release en GitHub y resuelve la descarga del APK
/// correspondiente a la arquitectura (ABI) instalada.
///
/// La app que consume esto indica su [flavor] ("mobile" o "tv") para elegir el
/// APK correcto entre los artefactos del release (`app-mobile-*` / `app-tv-*`).
class AppUpdateService {
  AppUpdateService._();

  /// Endpoint oficial de GitHub para la última release publicada.
  static const String githubApiUrl =
      'https://api.github.com/repos/Botsdiscordv1/AurisTV-Platform/releases/latest';

  static const String _fallbackReleaseUrl =
      'https://github.com/Botsdiscordv1/AurisTV-Platform/releases/latest';

  /// Canal nativo implementado en MainActivity.kt de las apps Android.
  static const MethodChannel _installChannel =
      MethodChannel('auristv/install');

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final dio = Dio();
      final url = '$githubApiUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      final response = await dio.get(
        url,
        options: Options(headers: {'Accept': 'application/vnd.github.v3+json'}),
      );

      if (response.statusCode == 200) {
        final dynamic rawData = response.data;
        final Map<String, dynamic> data = rawData is String
            ? jsonDecode(rawData) as Map<String, dynamic>
            : Map<String, dynamic>.from(rawData as Map);

        final String tagName = (data['tag_name'] ?? 'v1.0.0').toString();
        final String latestVersion =
            (tagName.startsWith('v') || tagName.startsWith('V'))
                ? tagName.substring(1)
                : tagName;

        final String releaseNotes = (data['body'] ??
                '• Se han realizado mejoras de rendimiento y correcciones de errores.')
            .toString();
        final String releaseUrl =
            (data['html_url'] ?? _fallbackReleaseUrl).toString();

        final List<AppUpdateAsset> assets = <AppUpdateAsset>[];
        final dynamic rawAssets = data['assets'];
        if (rawAssets is List) {
          for (final dynamic item in rawAssets) {
            if (item is Map) {
              final String name = (item['name'] ?? '').toString();
              final String downloadUrl =
                  (item['browser_download_url'] ?? '').toString();
              final Object? size = item['size'];
              final int bytes = size is int
                  ? size
                  : int.tryParse('$size') ?? 0;
              if (name.isNotEmpty && downloadUrl.isNotEmpty) {
                assets.add(AppUpdateAsset(
                  name: name,
                  url: downloadUrl,
                  size: bytes,
                ));
              }
            }
          }
        }

        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final String currentVersion = packageInfo.version;

        if (_isVersionNewer(currentVersion, latestVersion)) {
          return AppUpdateInfo(
            latestVersion: latestVersion,
            releaseNotes: releaseNotes,
            releaseUrl: releaseUrl,
            forceUpdate: false,
            assets: assets,
          );
        }
      }
    } catch (e) {
      debugPrint('Error comprobando actualizaciones desde GitHub API: $e');
    }
    return null;
  }

  static bool _isVersionNewer(String current, String latest) {
    try {
      current = current.split('+').first;
      latest = latest.split('+').first;

      final List<int> currParts = current.split('.').map(int.parse).toList();
      final List<int> latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final int c = i < currParts.length ? currParts[i] : 0;
        final int l = i < latestParts.length ? latestParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (e) {
      debugPrint('Error in _isVersionNewer: $e');
    }
    return false;
  }

  /// ABI preferente del dispositivo (solo Android). Ej: "arm64-v8a".
  static Future<String?> currentAbi() async {
    if (!isAndroid) return null;
    try {
      final AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
      return info.supportedAbis.isEmpty ? null : info.supportedAbis.first;
    } catch (e) {
      debugPrint('No se pudo detectar el ABI: $e');
      return null;
    }
  }

  /// Elige el APK del release que corresponde a [flavor] y [abi].
  static AppUpdateAsset? pickAsset(
    List<AppUpdateAsset> assets,
    String flavor,
    String? abi,
  ) {
    final String prefix = 'app-$flavor-app-';
    final List<AppUpdateAsset> candidates = assets
        .where((a) => a.name.startsWith(prefix) && a.name.endsWith('.apk'))
        .toList();
    if (candidates.isEmpty) return null;

    if (abi != null && abi.isNotEmpty) {
      final List<AppUpdateAsset> exact =
          candidates.where((a) => a.name.contains(abi)).toList();
      if (exact.isNotEmpty) return exact.first;
    }

    for (final String preferred in const ['arm64-v8a', 'armeabi-v7a', 'x86_64']) {
      final List<AppUpdateAsset> match =
          candidates.where((a) => a.name.contains(preferred)).toList();
      if (match.isNotEmpty) return match.first;
    }
    return candidates.first;
  }

  static Future<void> launchReleaseUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('No se pudo abrir la URL del release: $e');
    }
  }

  /// ¿Tiene la app permiso para instalar paquetes desconocidos?
  static Future<bool> canInstallPackages() async {
    if (!isAndroid) return false;
    try {
      return await _installChannel.invokeMethod<bool>('canInstall') ?? false;
    } catch (e) {
      debugPrint('canInstall error: $e');
      return false;
    }
  }

  /// Abre los ajustes del sistema para conceder "Instalar apps desconocidas".
  static Future<void> openInstallSettings() async {
    if (!isAndroid) return;
    try {
      await _installChannel.invokeMethod('openInstallSettings');
    } catch (e) {
      debugPrint('openInstallSettings error: $e');
    }
  }

  /// Lanza el instalador del sistema con el APK descargado en [path].
  static Future<bool> installApk(String path) async {
    if (!isAndroid) return false;
    try {
      return await _installChannel
              .invokeMethod<bool>('installApk', {'path': path}) ??
          false;
    } catch (e) {
      debugPrint('installApk error: $e');
      return false;
    }
  }

  /// Ruta de destino del APK de actualización en el almacenamiento de la app.
  static Future<String> resolveDownloadPath(String fileName) async {
    final dir = await getExternalStorageDirectory() ??
        await getTemporaryDirectory();
    return '${dir.path}/$fileName';
  }
}

enum AppUpdateDownloadStatus { idle, downloading, downloaded, error }

/// Gestor global de la descarga del APK. Sobrevive al cierre del diálogo para
/// que la descarga continúe en segundo plano ("Ocultar").
class AppUpdateDownloader extends ChangeNotifier {
  AppUpdateDownloader._();

  static final AppUpdateDownloader instance = AppUpdateDownloader._();

  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  AppUpdateDownloadStatus status = AppUpdateDownloadStatus.idle;
  AppUpdateInfo? info;
  AppUpdateAsset? asset;
  String? filePath;
  String? error;
  int received = 0;
  int total = 0;

  /// Indica si el diálogo de actualización está visible (para ocultar el banner).
  bool isDialogOpen = false;

  double get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;

  bool get isActive => status != AppUpdateDownloadStatus.idle;

  Future<void> start(AppUpdateInfo updateInfo, AppUpdateAsset updateAsset) async {
    if (status == AppUpdateDownloadStatus.downloading) return;

    info = updateInfo;
    asset = updateAsset;
    status = AppUpdateDownloadStatus.downloading;
    error = null;
    filePath = null;
    received = 0;
    total = updateAsset.size;
    notifyListeners();

    try {
      final String path = await AppUpdateService.resolveDownloadPath(updateAsset.name);
      _cancelToken = CancelToken();
      await _dio.download(
        updateAsset.url,
        path,
        cancelToken: _cancelToken,
        onReceiveProgress: (int count, int size) {
          received = count;
          total = size > 0 ? size : updateAsset.size;
          notifyListeners();
        },
      );
      filePath = path;
      status = AppUpdateDownloadStatus.downloaded;
      notifyListeners();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        status = AppUpdateDownloadStatus.idle;
        received = 0;
        total = 0;
      } else {
        error = e.message ?? 'Error de descarga';
        status = AppUpdateDownloadStatus.error;
      }
      notifyListeners();
    } catch (e) {
      error = '$e';
      status = AppUpdateDownloadStatus.error;
      notifyListeners();
    } finally {
      _cancelToken = null;
    }
  }

  /// Cancela y descarta la descarga en curso.
  void cancel() {
    _cancelToken?.cancel('user');
    status = AppUpdateDownloadStatus.idle;
    received = 0;
    total = 0;
    notifyListeners();
  }

  /// Vuelve al estado inicial (descarte del resultado ya terminado).
  void reset() {
    status = AppUpdateDownloadStatus.idle;
    info = null;
    asset = null;
    filePath = null;
    error = null;
    received = 0;
    total = 0;
    notifyListeners();
  }

  /// Intenta abrir el instalador con el APK ya descargado.
  Future<bool> install() async {
    final String? path = filePath;
    if (path == null) return false;
    return AppUpdateService.installApk(path);
  }
}
