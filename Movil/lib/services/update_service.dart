import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String releaseNotes;
  final String updateUrl;
  final bool forceUpdate;

  AppUpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.updateUrl,
    required this.forceUpdate,
  });
}

class UpdateService {
  // Endpoint oficial de GitHub para obtener la última release publicada
  static const String _githubApiUrl = 'https://api.github.com/repos/Botsdiscordv1/AurisTV-Platform/releases/latest';

  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final dio = Dio();
      final url = '$_githubApiUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      final response = await dio.get(
        url,
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
        ),
      );
      
      if (response.statusCode == 200) {
        final dynamic rawData = response.data;
        final Map<String, dynamic> data = rawData is String 
            ? jsonDecode(rawData) 
            : Map<String, dynamic>.from(rawData);

        final String tagName = data['tag_name'] ?? 'v1.0.0';
        // Remover 'v' inicial si está presente (ej: v1.0.1 -> 1.0.1)
        final String latestVersion = tagName.startsWith('v') || tagName.startsWith('V') 
            ? tagName.substring(1) 
            : tagName;

        final String releaseNotes = data['body'] ?? '• Se han realizado mejoras de rendimiento y correcciones de errores.';
        final String updateUrl = data['html_url'] ?? 'https://github.com/Botsdiscordv1/AurisTV-Platform/releases/latest';

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        print('GitHub Release Check -> Current: $currentVersion, Latest: $latestVersion');

        if (_isVersionNewer(currentVersion, latestVersion)) {
          return AppUpdateInfo(
            latestVersion: latestVersion,
            releaseNotes: releaseNotes,
            updateUrl: updateUrl,
            forceUpdate: false,
          );
        }
      }
    } catch (e) {
      print('Error comprobando actualizaciones desde GitHub API: $e');
    }
    return null;
  }

  static bool _isVersionNewer(String current, String latest) {
    try {
      current = current.split('+').first;
      latest = latest.split('+').first;

      List<int> currParts = current.split('.').map(int.parse).toList();
      List<int> latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        int c = i < currParts.length ? currParts[i] : 0;
        int l = i < latestParts.length ? latestParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (e) {
      print('Error in _isVersionNewer: $e');
    }
    return false;
  }

  static Future<void> launchUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
