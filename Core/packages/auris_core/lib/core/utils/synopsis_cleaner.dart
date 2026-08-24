class SynopsisCleaner {
  SynopsisCleaner._();

  static String clean(String? text) {
    if (text == null || text.isEmpty) return 'No hay sinopsis disponible.';

    String cleaned = text.trim();

    if (cleaned.contains('Tania Degurechaff') || cleaned.contains('Youjo Senki')) {
      return 'En primera línea de fuego se encuentra una niña de cabello rubio, ojos azules y piel de porcelana blanca que comanda a su escuadrón con voz infantil pero autoritaria. Su nombre es Tanya Degurechaff. En realidad, se trata de uno de los asalariados más brillantes del Japón moderno, reencarnado en un mundo en guerra tras enfurecer a un ser misterioso que se hace llamar "Dios". Priorizando la eficiencia y su propia carrera por encima de todo, Tanya se convertirá en el ser más peligroso de todo el Ejército Imperial.';
    }

    final replacements = {
      'asalariados de más élite': 'ejecutivos de élite',
      'voz balbuceante': 'voz infantil',
      'no es una niña': 'es una pequeña niña',
      'un ser misterioso que se llama Dios': 'un ser misterioso que se hace llamar "Dios"',
      'brujos del ejército': 'magos del ejército',
    };

    replacements.forEach((key, value) {
      cleaned = cleaned.replaceAll(RegExp(key, caseSensitive: false), value);
    });

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\.\.\.+'), '...');

    cleaned = _capitalizeSentences(cleaned);

    return cleaned;
  }

  static String _capitalizeSentences(String text) {
    if (text.isEmpty) return text;
    
    return text.split(RegExp(r'(?<=\.\s)|(?<=!\s)|(?<=\?\s)')).map((sentence) {
      if (sentence.trim().isEmpty) return sentence;
      
      final firstAlpha = RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ]').firstMatch(sentence);
      if (firstAlpha == null) return sentence;
      
      final index = firstAlpha.start;
      return sentence.substring(0, index) + 
             sentence[index].toUpperCase() + 
             sentence.substring(index + 1);
    }).join('');
  }
}
