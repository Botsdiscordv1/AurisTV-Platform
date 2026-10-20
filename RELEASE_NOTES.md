## 🚀 AurisTV v1.0.7 - Temporadas corregidas, Continuar Viendo más fiable y foco del Home mejorado

¡Lanzamos **AurisTV v1.0.7**! Esta versión corrige los episodios de series cuyo título termina en "X", arregla títulos e imágenes de **Continuar Viendo** y mejora la navegación con D-pad en TV.

---

### ✨ Novedades y Mejoras Destacadas

* 🎞️ **Episodios sin saltos de temporada:**
  * La detección de temporada ya no interpreta la letra final "X" como temporada 10 ("Doctora X", "Project X"). Antes se pedía la T10 y el listado salía vacío; ahora carga la temporada correcta.
  * Los romanos (`II`…`IX`) siguen funcionando igual, y la "X" solo cuenta si viene marcada como "Season X"/"Temporada X".

* 🕹️ **Continuar Viendo más fiable:**
  * Si el historial no guardó el título, la tarjeta muestra el título real (`metadataTitle`/episodio) en vez de "Contenido".
  * En películas, el banner y el logo se corrigen aunque el póster ya fuera el correcto; el still del episodio se conserva en series.

* 🔤 **Fallback de logo:**
  * Si el logo no carga (404/error de red), se muestra el título sobre el arte en las tarjetas del Home, Continuar Viendo y Biblioteca TV.

* 🎮 **Navegación con D-pad (TV):**
  * Memoria de foco por sección: al subir/bajar con el D-pad se restaura la última tarjeta enfocada de cada fila.
  * Salto directo a la sección siguiente/anterior desde la primera o última tarjeta.

* 📚 **Biblioteca (TV):**
  * Tarjetas navegables con D-pad, borde de foco y apertura con Enter/SELECT, con el mismo anclaje de scroll que las filas del Home.

* 🖼️ **Hero (TV):**
  * Logo reducido del 45% al 38% del ancho para no tapar el arte de fondo.

---

### 📥 Descargas Directas (Assets)

* **`app-tv-*.apk`**: 📺 APK para Android/Google TV (usa `armeabi-v7a` en boxes de 32 bits).
* **`app-mobile-*.apk`**: 📱 APK para móviles Android.
* **`auristv-windows-x64.zip`**: 💻 Build para Windows Desktop.

> *¡Gracias por usar AurisTV!* 🍿🎬
