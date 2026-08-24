# AurisTV — Core & Assets

Este repositorio contiene el "cerebro" compartido y los recursos multimedia de **AurisTV**. 

La aplicación se ha dividido en proyectos independientes por plataforma para permitir una evolución estética y funcional específica, manteniendo toda la lógica de negocio centralizada aquí.

## Estructura del Repositorio

- **`packages/auris_core`**: Paquete compartido con toda la lógica de negocio.
  - Modelos de datos (Anilist, TMDB, Supabase).
  - Repositorio y lógica de scraping/extracción.
  - Providers de Riverpod para sesión, historial y favoritos.
- **`assets/`**: Recursos compartidos (iconos, imágenes de branding, avatares).
- **`docs/`**: Especificaciones técnicas y guías de diseño.

## Proyectos de Aplicación

Las aplicaciones finales consumen este Core y se encuentran en carpetas independientes:

1.  **Móvil (Android/iOS)**: Ubicado en `E:\AurisTV_plataformas\Movil`.
    *   Diseño nativo optimizado para interfaces táctiles.
    *   Control de hardware móvil (brillo, volumen nativo).
2.  **Web & Desktop (Windows)**: Ubicado en `E:\AurisTV_plataformas\Web_Desktop`.
    *   Diseño responsivo para navegadores.
    *   Contenedor de alto rendimiento para Windows.

## Cómo trabajar en el Core

Cualquier cambio en la lógica de red o persistencia debe realizarse dentro de `packages/auris_core`. 

Para que los cambios se reflejen en las apps, asegúrate de ejecutar `flutter pub get` en los proyectos de plataforma después de modificar el core.

---
**AurisTV** — *Anime, Series & KDramas*
