import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/auth/user_account.dart';

class DeviceActivationService {
  static const String _table = 'device_activations';
  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generateCode() {
    final rand = Random.secure();
    return List.generate(6, (index) => _chars[rand.nextInt(_chars.length)]).join();
  }

  static Future<bool> createActivationSession(String code) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from(_table).upsert({
        'code': code.toUpperCase().trim(),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      if (e.toString().contains('PGRST205') || e.toString().contains('device_activations')) {
        debugPrint('[DeviceActivationService] ⚠️ ATENCIÓN: Falta crear la tabla "device_activations" en Supabase.');
      } else {
        debugPrint('[DeviceActivationService] Error creando sesión: $e');
      }
      return false;
    }
  }

  static Future<UserAccount?> checkActivationStatus(String code) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from(_table)
          .select()
          .eq('code', code.toUpperCase().trim())
          .maybeSingle();

      if (response != null && response['status'] == 'activated' && response['user_data'] != null) {
        final userData = response['user_data'];
        final map = userData is Map ? Map<String, dynamic>.from(userData) : <String, dynamic>{};
        if (map.isNotEmpty) {
          return UserAccount.fromJson(map);
        }
      }
    } catch (e) {
      if (e.toString().contains('PGRST205') || e.toString().contains('device_activations')) {
        debugPrint('[DeviceActivationService] ⚠️ Tabla "device_activations" no encontrada en Supabase.');
      } else {
        debugPrint('[DeviceActivationService] Error verificando código: $e');
      }
    }
    return null;
  }

  static Future<bool> activateDevice(String code, UserAccount user) async {
    try {
      final supabase = Supabase.instance.client;
      final cleanCode = code.toUpperCase().trim();

      await supabase.from(_table).upsert({
        'code': cleanCode,
        'status': 'activated',
        'user_id': user.id,
        'user_data': user.toJson(),
        'activated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('[DeviceActivationService] Error activando dispositivo: $e');
      return false;
    }
  }
}
