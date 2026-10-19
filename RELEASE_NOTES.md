## 🚀 AurisTV v1.0.5 - Watch Next en Android/Google TV, rendimiento del Home y refinamientos

¡Lanzamos **AurisTV v1.0.5**! Esta versión integra la fila **"Continuar Viendo"** en el launcher de Android/Google TV, mejora la fluidez del Home con el D-pad y refina el reproductor y las pantallas de detalle.

---

### ✨ Novedades y Mejoras Destacadas

* 📺 **Watch Next en Android/Google TV (TV):**
  * La app publica "Continuar Viendo" en el launcher (canal `auristv/watchnext`).
  * Al pulsar una tarjeta se abre el contenido directamente; el botón **Atrás** vuelve al Home de la app.

* ⚡ **Rendimiento del Home (TV):**
  * D-pad más fluido: se eliminó el `Clip.antiAliasWithSaveLayer` de las tarjetas (menos capas GPU por frame).
  * El overlay de foco de las filas "wide" se construye una sola vez y solo se reposiciona (no se reconstruye la tarjeta en cada frame).

* 🎬 **Reproductor (TV):**
  * Pantalla de carga unificada ("Cargando contenido…").
  * El spinner del primer frame ya no desaparece antes de tiempo.

* 🖼️ **Pantallas de detalle (TV):**
  * Se evita mostrar el título/póster provisionales antes de cargar los metadatos (skeletons).

* 🎨 **Arranque y collage (Móvil, TV, Web/Desktop):**
  * El collage del Login se precarga durante el Splash y aparece lleno desde el primer frame.

---

### 📥 Descargas Directas (Assets)

* **`app-tv-*.apk`**: 📺 APK para Android/Google TV (usa `armeabi-v7a` en boxes de 32 bits).
* **`app-mobile-*.apk`**: 📱 APK para móviles Android.
* **`auristv-windows-x64.zip`**: 💻 Build para Windows Desktop.

> *¡Gracias por usar AurisTV!* 🍿🎬
