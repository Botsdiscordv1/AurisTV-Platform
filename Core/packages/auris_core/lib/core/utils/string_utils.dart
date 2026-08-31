import 'package:flutter/services.dart';

/// Utilidades para manipulación de strings en AurisTV.
class AurisStringUtils {
  /// Capitaliza la primera letra de cada palabra en un query de búsqueda.
  /// 
  /// Ejemplo: "resident evil" -> "Resident Evil"
  /// Si la letra ya es mayúscula, no se modifica.
  static String capitalizeSearchQuery(String text) {
    if (text.isEmpty) return text;

    final words = text.split(' ');
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      
      // Solo capitalizamos si el primer carácter es una letra minúscula
      final firstChar = word[0];
      if (firstChar.toUpperCase() != firstChar) {
        return firstChar.toUpperCase() + word.substring(1);
      }
      return word;
    });

    return capitalizedWords.join(' ');
  }
}

/// Formateador para campos de texto que capitaliza cada palabra automáticamente.
class CapitalizeWordsFormatter extends TextInputFormatter {
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
