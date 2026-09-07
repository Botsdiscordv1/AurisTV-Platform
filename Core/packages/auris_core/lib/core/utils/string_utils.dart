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
}

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
