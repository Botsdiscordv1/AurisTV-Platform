#                                              🚀 AurisTV v1.1.0 - Actualización Mayor: Sistema de Casting & Control Remoto D-Pad

¡Nos complace anunciar el lanzamiento de **AurisTV v1.1.0**! Esta importante actualización mayor introduce el nuevo **Sistema de Casting local/remoto**, hojas flotantes de control D-Pad, optimizaciones nativas de reproducción de video en superficie, gestión avanzada de perfiles y avatares, y sincronización completa en todas las plataformas (**Móvil, Android TV y Web/Desktop**).

---

## ✨ Novedades y Características Principales

- **Sistema de Casting y Reproducción Remota (`cast_mode_view`, `cast_picker_sheet`, `LocalCastForegroundService`):**
  - Nuevo módulo de transmisión local y remota con soporte en segundo plano, selector de dispositivos y vistas dedicadas de casting.
- **Control Remoto D-Pad y Hojas Flotantes (`dpad_remote_sheet`, `remote_device`, `remote_control_provider`):**
  - Interfaz intuitiva de control remoto virtual con navegación D-Pad para gestionar dispositivos conectados de forma fluida.
- **Optimizaciones de Superficie de Video Nativa y Reproductor (`mobile_video_surface`, `player_screen`):**
  - Renderizado mejorado de video nativo utilizando superficies dedicadas (`native_video_surface_binder`, `video_surface_config`).
- **Gestión de Perfiles y Avatares (`profile_screen`, `avatar_selector_screen`):**
  - Nuevos flujos y pantallas de configuración, edición y selección de avatares de usuario.
- **Soporte Multiplataforma Sincronizado (`v1.1.0+10`):**
  - Versión unificada con versionCode `10` en Móvil, Android TV y Web/Desktop.

---

## 🛠️ Correcciones de Errores y Mejoras de Rendimiento

- **Estabilidad de Enrutamiento y Reproducción:** Correcciones en la gestión de estado con Riverpod y transiciones de enrutamiento (`app_router`).
- **Empaquetado y Release:** Automatización limpia con `--split-per-abi` y firma digital segura con el keystore oficial de producción (`upload-keystore.jks`).

---

📥 *¡Actualiza a la versión v1.1.0 para disfrutar de la experiencia multimedia definitiva con Casting y Control Remoto en AurisTV!*
