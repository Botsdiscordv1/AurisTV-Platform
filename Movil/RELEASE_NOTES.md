# 🚀 AurisTV v1.0.0 - Lanzamiento Oficial & Mejoras Multiplataforma

¡Nos complace anunciar el lanzamiento oficial de **AurisTV v1.0.0** con importantes mejoras, correcciones y optimizaciones en todas las plataformas (**Móvil, Android TV y Web/Desktop**)!

---

## ✨ Novedades y Características Principales

- **Gestión Avanzada de Perfiles y Avatares en Android TV:**
  - Pantalla completa de selección de perfiles.
  - Creación y edición de perfiles adaptada para control remoto.
  - Selector de avatares personalizados.
- **Reproductor de YouTube & Trailers Mejorado (Multiplataforma):**
  - Reemplazo del wrapper de iframe por un `WebViewController` directo con User-Agent de Chrome para solucionar errores de reproducción en trailers (Error 152-4).
  - Eliminación de parámetros problemáticos de origen y adición del botón de respaldo "Abrir en YouTube".
- **Mejoras en Providers y Ciclo de Vida (Riverpod):**
  - Ajustes en la inicialización de estados (`Future.microtask` en `initState`) para evitar modificaciones durante la construcción de widgets.
  - Corrección en constructores y *getters* de `ExtractResult` y `EpisodesResponse`.
- **Navegación y UI Optimizada para TV:**
  - Componentes de desplazamiento y enfoque mejorados (`tv_scroll`, `tv_focus_wrapper`).
  - Filas de contenido, atajos de categorías y banners rediseñados (`category_shortcuts_row`, `editorial_content_row`, `focusable_poster_card`).

---

## 🛠️ Correcciones de Errores y Optimizaciones Técnicas

- **Estabilidad General:** Corrección de errores de compilación y sincronización de estado en el núcleo compartido (`auris_core`).
- **Control Nativo:** Optimización de canales nativos para control de brillo y volumen en Android.
- **Empaquetado Multiplataforma:** Sincronización de versiones (`1.0.0+1`) y automatización limpia para APKs de Móvil, TV y binario ZIP de Windows Desktop.

---

📥 *¡Actualiza ahora para disfrutar de la experiencia multimedia definitiva con AurisTV en cualquiera de tus dispositivos!*
