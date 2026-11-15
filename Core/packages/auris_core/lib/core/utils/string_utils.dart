import 'package:flutter/services.dart';

/// Utilidades para manipulación de strings en AurisTV.
class AurisStringUtils {
  /// Capitaliza solo la primera letra del texto (útil para queries de búsqueda).
  /// 
  /// Ejemplo: "resident evil" -> "Resident evil"
  /// Si la letra ya es mayúscula o el texto empieza con un símbolo, no se modifica.
  static String capitalizeSearchQuery(String text) {
    if (text.isEmpty) return text;

    // Solo capitalizamos el primer carácter de todo el texto
    final firstChar = text[0];
    if (firstChar.toUpperCase() != firstChar) {
      return firstChar.toUpperCase() + text.substring(1);
    }

    return text;
  }

  /// Formatea una duración en milisegundos a un string compacto de tiempo restante.
  /// 
  /// Ejemplo: 77 min -> "1h 17 min"
  /// 45 min -> "45 min"
  static String formatRemainingTime(int milliseconds) {
    if (milliseconds <= 0) return '';
    
    final minutes = (milliseconds / 60000).ceil();
    if (minutes < 60) {
      return '$minutes min';
    }
    
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    
    if (remainingMinutes == 0) return '${hours}h';
    
    return '${hours}h $remainingMinutes min';
  }

  /// Formatea una fecha ISO o corta al formato legible en español.
  ///
  /// Ejemplo: "2026-10-11" -> "11 oct 2026"
  /// "11-10-26" -> "11 oct 2026"
  static String formatDisplayDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'N/A';
    final clean = raw.trim();

    try {
      DateTime? dt = DateTime.tryParse(clean);
      if (dt == null) {
        final parts = clean.split(RegExp(r'[-/.]'));
        if (parts.length == 3) {
          int? p1 = int.tryParse(parts[0]);
          int? p2 = int.tryParse(parts[1]);
          int? p3 = int.tryParse(parts[2]);

          if (p1 != null && p2 != null && p3 != null) {
            if (p1 > 1900) {
              dt = DateTime(p1, p2, p3);
            } else if (p3 > 1900) {
              dt = DateTime(p3, p2, p1);
            } else if (p3 < 100) {
              int fullYear = p3 < 50 ? 2000 + p3 : 1900 + p3;
              dt = DateTime(fullYear, p2, p1);
            }
          }
        }
      }

      if (dt != null) {
        const months = [
          'ene', 'feb', 'mar', 'abr', 'may', 'jun',
          'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
        ];
        final monthStr = months[dt.month - 1];
        return '${dt.day} $monthStr ${dt.year}';
      }
    } catch (_) {}

    return clean;
  }

  /// Formatea el título del episodio combinando el número y el título crudo de forma limpia,
  /// evitando duplicar el número de episodio si ya viene en el título (ej: "2.ª noche...", "Episodio 2", "E2 - ...").
  static String formatEpisodeTitle(int epNumber, String? rawTitle) {
    final String titleStr = (rawTitle != null && rawTitle.trim().isNotEmpty)
        ? rawTitle.trim()
        : 'Episodio $epNumber';

    if (epNumber <= 0) return titleStr;

    final String lower = titleStr.toLowerCase();
    final String numStr = epNumber.toString();
    final String paddedNumStr = epNumber < 10 ? '0$epNumber' : numStr;

    final bool startsWithNumber =
        titleStr.startsWith(numStr) ||
        titleStr.startsWith(paddedNumStr) ||
        lower.startsWith('e$numStr') ||
        lower.startsWith('e$paddedNumStr') ||
        lower.startsWith('e.$numStr') ||
        lower.startsWith('e.$paddedNumStr') ||
        lower.startsWith('ep $numStr') ||
        lower.startsWith('ep. $numStr') ||
        lower.startsWith('ep.$numStr') ||
        lower.startsWith('ep0') ||
        lower.startsWith('ep $paddedNumStr') ||
        lower.startsWith('episodio') ||
        lower.startsWith('capitulo') ||
        lower.startsWith('cap ') ||
        lower.startsWith('cap. ') ||
        RegExp('^(e|ep|cap|episodio)?\\.?\\s*0*$epNumber[^0-9]', caseSensitive: false).hasMatch(titleStr);

    if (startsWithNumber) {
      return titleStr;
    }

    return 'E$epNumber - $titleStr';
  }
}

/// Helper global de formateo de fecha.
String formatDisplayDate(String? raw) => AurisStringUtils.formatDisplayDate(raw);

/// Helper global de formateo de título de episodio.
String formatEpisodeTitle(int epNumber, String? rawTitle) =>
    AurisStringUtils.formatEpisodeTitle(epNumber, rawTitle);

/// Formateador para campos de texto que capitaliza solo la primera letra automáticamente.
class CapitalizeFirstLetterFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = AurisStringUtils.capitalizeSearchQuery(newValue.text);
    
    // Mantenemos la posición del cursor si el texto cambió por capitalización
    if (newText != newValue.text) {
      return newValue.copyWith(
        text: newText,
        selection: newValue.selection,
      );
    }
    
    return newValue;
  }
}
