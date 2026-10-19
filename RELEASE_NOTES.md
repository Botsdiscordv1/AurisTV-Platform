## 🚀 AurisTV v1.0.6 - Animaciones del Home estilo Netflix TV y arreglos de foco con D-pad

¡Lanzamos **AurisTV v1.0.6**! Esta versión pule la navegación con D-pad del Home (animaciones de foco, scroll y cápsulas del topbar) y corrige el foco al entrar en "Continuar Viendo" y otras filas anchas.

---

### ✨ Novedades y Mejoras Destacadas

* 📺 **Navegación del Home (TV):**
  * Cápsulas del topbar con animación de foco tipo Netflix: la cápsula activa hace un "pop" (`1.0 → 1.08`, 150 ms) y los iconos/avatar responden al instante.
  * Scroll vertical entre secciones y horizontal entre tarjetas con **duración proporcional a la distancia** (curva `easeOutCubic`), en lugar de una duración fija: movimientos cortos más ágiles y saltos largos más suaves.

* 🎯 **Foco determinista en filas (TV):**
  * Al bajar/subir con el D-pad, **"Continuar Viendo"** (y las filas anchas de tendencias/estrenos) ahora enfocan siempre la **primera** tarjeta, igual que el resto de secciones "wide".

* 🎬 **Transiciones (TV):**
  * El Hero revela sinopsis y botones con un fundido suave (sin saltos de layout) al recibir el foco.
  * Player: transición compacto → pantalla completa más fluida (`180 ms`, `easeOutCubic`).

* 🧩 **Core:**
  * Parámetros de animación (`animationDuration`/`animationCurve`) expuestos en el panel adaptativo para ajustar la transición del player.

---

### 📥 Descargas Directas (Assets)

* **`app-tv-*.apk`**: 📺 APK para Android/Google TV (usa `armeabi-v7a` en boxes de 32 bits).
* **`app-mobile-*.apk`**: 📱 APK para móviles Android.
* **`auristv-windows-x64.zip`**: 💻 Build para Windows Desktop.

> *¡Gracias por usar AurisTV!* 🍿🎬
