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
  static const String _versionJsonUrl = 'https://raw.githubusercontent.com/Botsdiscordv1/AurisTV-Platform/main/version.json';

  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final dio = Dio();
      final url = '$_versionJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      final response = await dio.get(url);
      
      if (response.statusCode == 200) {
        final dynamic rawData = response.data;
        final Map<String, dynamic> data = rawData is String 
            ? jsonDecode(rawData) 
            : Map<String, dynamic>.from(rawData);

        final String latestVersion = data['latestVersion'] ?? '1.0.0';
        final String minSupportedVersion = data['minSupportedVersion'] ?? '1.0.0';
        final String releaseNotes = data['releaseNotes'] ?? 'Nuevas mejoras y correcciones.';
        final String updateUrl = data['updateUrl'] ?? 'https://github.com/Botsdiscordv1/AurisTV-Platform/releases/latest';

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        print('UpdateCheck -> Current: $currentVersion, Latest: $latestVersion');

        if (_isVersionNewer(currentVersion, latestVersion)) {
          final isForced = _isVersionNewer(currentVersion, minSupportedVersion);
          return AppUpdateInfo(
            latestVersion: latestVersion,
            releaseNotes: releaseNotes,
            updateUrl: updateUrl,
            forceUpdate: isForced,
          );
        }
      }
    } catch (e) {
      print('Error comprobando actualizaciones: $e');
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
