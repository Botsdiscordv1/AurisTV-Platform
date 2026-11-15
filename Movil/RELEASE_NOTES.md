# 🚀 AurisTV v1.1.6 - Actualización Mayor: Watch Screen Base, Clean Embedded Player & Mejoras Multiplataforma

¡Nos complace anunciar el lanzamiento oficial de **AurisTV v1.1.6**! Esta importante actualización trae consigo mejoras avanzadas en la pantalla de watch (`watch_screen_base`, `clean_embedded_player`, `watch_top_bar`, `watch_episode_metadata`, `watch_playlist_sidebar`), aceleración de streams, enrutamiento y sincronización completa en todas las plataformas (**Móvil, Android TV y Web/Desktop**).

---

## ✨ Novedades y Características Principales

- **Refinamiento de Reproducción y Watch Screen (`watch_screen_base`, `clean_embedded_player`):**
  - Nuevos widgets de barra superior (`watch_top_bar`), metadatos de episodios (`watch_episode_metadata`), sidebar de playlist (`watch_playlist_sidebar`) y reproductor embebido limpio optimizado para una experiencia inmersiva.
- **Aceleración y Validación de Streams (`auris_chunked_stream_accelerator`, `url_security_validator`):**
  - Mejoras en la seguridad de URLs y aceleración de carga de streaming en `auris_core`.
- **Soporte Multiplataforma Sincronizado (`v1.1.6+17`):**
  - Versión unificada con versionCode `17` en Móvil, Android TV y Web/Desktop.

---

## 🛠️ Correcciones de Errores y Mejoras de Rendimiento

- **Estabilidad General:** Correcciones de estado en proveedores de reproductor y transiciones de enrutamiento (`app_router`).
- **Empaquetado y Release:** Automatización limpia con `--split-per-abi`, `--dart-define=NATIVE_VIDEO_SURFACE=true` en Móvil y firma digital segura con el keystore oficial de producción (`upload-keystore.jks`).

---

📥 *¡Actualiza a la versión v1.1.6 para disfrutar de la experiencia multimedia definitiva con AurisTV!*
