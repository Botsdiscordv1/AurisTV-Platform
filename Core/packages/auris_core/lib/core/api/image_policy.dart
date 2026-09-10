/// Define las políticas de dimensionamiento de imágenes para toda la plataforma.
/// Centraliza los tamaños para optimizar el consumo de ancho de banda y RAM.
enum ImageSize {
  /// Tamaño minúsculo (150px) - Avatares, iconos pequeños.
  tiny(150),
  
  /// Tamaño de póster estándar (500px) - Grids de búsqueda, carruseles de Home.
  poster(500),
  
  /// Tamaño de banner/hero (1280px) - Cabeceras, Extras (OP/ED).
  banner(1280),
  
  /// Calidad máxima (1920px o original) - Backdrops a pantalla completa.
  full(1920),
  
  /// Sin redimensionamiento.
  original(null);

  final int? width;
  const ImageSize(this.width);
}

class AurisImagePolicy {
  /// Devuelve el ancho recomendado para un tipo de uso.
  static int? getWidth(ImageSize size) => size.width;

  /// Devuelve la calidad recomendada (0-100) para weserv.
  static int getQuality(ImageSize size) {
    switch (size) {
      case ImageSize.tiny: return 75;
      case ImageSize.poster: return 82;
      case ImageSize.banner: return 85;
      case ImageSize.full: return 90;
      case ImageSize.original: return 100;
    }
  }
}
