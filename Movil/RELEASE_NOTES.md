# 🚀 AurisTV v1.0.9 - Corrección de Instalación en TV Box & Actualización Multiplataforma

¡Nos complace anunciar el lanzamiento de **AurisTV v1.0.9**! Esta actualización soluciona el error *"No se puede instalar la aplicación"* al instalar la versión de TV en TV Boxes genéricas o personalizadas, cambiando el requisito de hardware Leanback a opcional.

---

## ✨ Novedades y Características Principales

- **Compatibilidad Ampliada con TV Boxes (`AndroidManifest.xml`):**
  - Cambio de `android.software.leanback` de `required="true"` a `required="false"`. Esto permite que el APK de TV se instale exitosamente en cualquier TV Box (incluso aquellas con firmwares modificados o que no reportan formalmente la característica Leanback al sistema).
- **Soporte Multiplataforma Sincronizado (`v1.0.9+9`):**
  - Versión unificada con versionCode `9` en Móvil, Android TV y Web/Desktop.

---

## 🛠️ Correcciones de Errores y Mejoras de Rendimiento

- **Instalación de TV APK:** Resuelto el bloqueo de paquetes al instalar en TV Boxes que no son dispositivos certificados de Google TV.
- **Empaquetado y Release:** Automatización limpia con `--split-per-abi` y firma digital segura con el keystore oficial de producción (`upload-keystore.jks`).

---

📥 *¡Actualiza a la versión v1.0.9 para instalar sin problemas en tu TV Box!*
