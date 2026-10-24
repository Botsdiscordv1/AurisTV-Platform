# 🚀 AurisTV v1.1.0 - Actualización Mayor: Sistema de Casting, Control Remoto D-Pad & Mejoras de TV

¡Nos complace anunciar una nueva iteración de **AurisTV v1.1.0** con importantes mejoras en la interfaz de Android TV (temas, fuentes, diseño responsivo, filas de contenido, avatares y perfiles), optimizaciones en el modelo de medios (`media_item`) y sincronización completa en todas las plataformas (**Móvil, Android TV y Web/Desktop**)!

---

## ✨ Novedades y Características Principales

- **Refinamientos Visuales y de Fuentes en Android TV:**
  - Nuevas fuentes y temas (`app_theme`), mejoras en `tv_responsive_utils`, filas de contenido (`content_row`, `editorial_content_row`, `wide_content_row`) y tarjetas con enfoque (`focusable_wide_card`, `skeletons`).
- **Sistema de Casting y Control Remoto D-Pad (`LocalCastForegroundService`, `dpad_remote_sheet`):**
  - Transmisión local y remota en segundo plano con soporte de superficies de video nativas y control remoto virtual.
- **Gestión Avanzada de Perfiles y Avatares (`profile_screen`, `avatar_selector_screen`):**
  - Pantallas de selección, edición y creación de perfiles optimizadas para control remoto y dispositivos móviles.
- **Soporte Multiplataforma Sincronizado (`v1.1.0+11`):**
  - Versión unificada con versionCode `11` en Móvil, Android TV y Web/Desktop.

---

## 🛠️ Correcciones de Errores y Mejoras de Rendimiento

- **Estabilidad de Enrutamiento y Datos:** Ajustes en `app_router`, repositorios y proveedores de autenticación e historial.
- **Empaquetado y Release:** Automatización limpia con `--split-per-abi`, `--dart-define=NATIVE_VIDEO_SURFACE=true` en Móvil y firma digital segura con `upload-keystore.jks`.

---

📥 *¡Actualiza a la versión v1.1.0 para disfrutar de la experiencia multimedia definitiva en AurisTV!*
