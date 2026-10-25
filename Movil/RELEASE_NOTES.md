# 🚀 AurisTV v1.1.1 - Actualización Mayor: Módulo de Deportes & Mejoras Multiplataforma

¡Nos complace anunciar el lanzamiento de **AurisTV v1.1.1**! Esta importante actualización introduce el nuevo **módulo de Deportes** (`content_sports.dart`, `sports_card`), expansión de pruebas unitarias y e2e, mejoras en los proveedores de inicio y reproductor, y optimizaciones de UI en todas las plataformas (**Móvil, Android TV y Web/Desktop**).

---

## ✨ Novedades y Características Principales

- **Nuevo Módulo de Deportes (`content_sports.dart`, `sports_card`, `content_sport_screen`):**
  - Soporte completo para eventos, tarjetas e interfaces dedicadas al contenido deportivo en el ecosistema AurisTV.
- **Ampliación de Pruebas Unitarias y de Integración (`auris_core/test`):**
  - Nuevas suites de pruebas automatizadas (`detail_view_tracking_test`, `e2e_personalization_cycle_test`, `home_provider_personalization_test`, `user_event_tracker_test`).
- **Mejoras en Providers y Repositorios (`home_provider`, `auris_repository_impl`):**
  - Optimización en la carga de datos, composición de secciones y seguimiento de eventos de usuario.
- **Refinamientos Visuales y de Diseño (`adaptive_detail_layout`, `detail_backdrop`, `focusable_poster_card`):**
  - Mejoras estéticas y de navegación en tarjetas y pantallas de detalle en Móvil, TV y Web/Desktop.
- **Soporte Multiplataforma Sincronizado (`v1.1.1+12`):**
  - Versión unificada con versionCode `12` en Móvil, Android TV y Web/Desktop.

---

## 🛠️ Correcciones de Errores y Mejoras de Rendimiento

- **Estabilidad General:** Correcciones de estado en reproductor, transiciones de pantalla de inicio y sincronización de datos.
- **Empaquetado y Release:** Automatización limpia con `--split-per-abi`, `--dart-define=NATIVE_VIDEO_SURFACE=true` en Móvil y firma digital segura con el keystore oficial de producción (`upload-keystore.jks`).

---

📥 *¡Actualiza a la versión v1.1.1 para disfrutar de la experiencia multimedia y deportiva definitiva con AurisTV!*
