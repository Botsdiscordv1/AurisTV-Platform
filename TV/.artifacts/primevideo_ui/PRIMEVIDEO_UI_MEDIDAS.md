# Prime Video TV — Extracción de UI Home (evidencia)

## Origen y método

| Campo | Valor |
|---|---|
| Dispositivo | MiTV-AFKR0 (Xiaomi), Android 11 (API 30), **1920×1080 @ 320 dpi** |
| Conexión | `adb connect 192.168.18.8:5555` |
| Paquete | `com.amazon.amazonvideo.livingroom` v `6.24.12+v16.0.1.23-allAbis` (versionCode 606024120) |
| APK extraído | `base.apk` (5.17 MB) + `split_config.{armeabi_v7a,es,xhdpi}.apk` |
| Motor UI | **Amazon Ignite / IgnitionX** — render GPU propio (GLES2) + JavaScript, *no* vistas Android |
| Estado de la app | **Sin sesión** → modo *browse* ("Descubre lo que está disponible") |
| Root | No disponible (`su` ausente); `run-as` denegado (app no debuggable) |

**Limitación importante:** el APK es solo un *shell de arranque*. `search_android_classes`
devolvió **0 matches** para `Hero`, `Carousel`, `Section`, `SearchOverlay`, `CarouselRow`
(cobertura completa sobre 4318 clases) — la UI real **no está en el APK**: `appBootstrap.js`
la descarga de `api.amazonvideo.com` en runtime y la renderiza Ignite. Sin root no es posible
leer el bundle cacheado en `/data/data/...` (Permission denied).

Por eso las medidas son **empíricas**: capturas de pantalla (`screencap`) + perfil de píxeles
(`profile.ps1` / `imgdiff.ps1`) sobre el framebuffer real. Toda cifra marcada como *medida* se
obtuvo de un recuento de píxeles, no de estimación visual.

> Las coordenadas son relativas a 1920×1080 con **origen arriba-izquierda**.

---

## 0. Evidencia estática de apoyo

`assets/ignite-assets.tar` → `lua/appBootstrap.js` (33 KB) contiene la rejilla de diseño:

```
imageResolution  { width: 1920, height: 1080 }
errorMessageMarginLeft   : 144      ← coincide con el margen izquierdo medido
errorMessageMarginBottom : 127.5
FONT_FAMILY = "Amazon Ember", FONT_SIZE 28, FONT_WEIGHT 500
```

`appBootstrap.js` escala por razón de resolución
(`screenResolution.width / imageResolution.width`), es decir Prime usa una **rejilla de
diseño fija a 1920×1080** y escala linealmente.

---

## 1. Estructura del Home

```
┌──────────────────────────────────────────────────────────────┐
│  [rail]  Inicio  Películas  Series                (nav, NO sticky)  y 54..101
│          │                                                     │
│  🔍      │              HERO (imagen a sangre)                 │
│  ▦       │   título/logo · #N en Perú · CTA · dots             │ y ≈ 200..609
│  🛍      │                                                     │
│          └─────────────────────────────────────────────────────┘ y ≈ 610..620
│  Título de sección                                             y 633..652
│  ▭▭▭▭▭▭   filas de tarjetas                                     y 668..856
│  Título de sección                                             y 888..911
│  ▭▭▭▭▭▭                                                       y 923..
└──────────────────────────────────────────────────────────────┘
```

### 1.1 Rail izquierdo (fijo, fuera del scroll)

Medido en `u0.png` / `srch1.png`:

| Elemento | Medida |
|---|---|
| Iconos (buscar / menú / tienda) | centro **x ≈ 70**, y **483 / 540 / 596** → paso vertical **57** |
| Icono | ≈ **24–28 px** |
| Estado enfocado del icono | fondo redondeado gris ≈ **56×56** (buscado en `srch1`: x 44..99) |

Al pulsar **LEFT** el rail se expande en *drawer* (`b3.png`):

| Fila | y |
|---|---|
| Iniciar sesión | 396 |
| Buscar | 468 |
| Menú principal *(foco)* | 540 |
| Tienda | 613 |
| Configuración | 685 |

→ paso vertical **≈ 72**, fondo de foco cuadrado redondeado ≈ 56×56, etiqueta ≈ 26 px.

### 1.2 Top nav — **NO es sticky**

Medido en `u0.png`:

| Elemento | Medida |
|---|---|
| Pill "Inicio" (foco) | **88 × 48** en **(144, 54)** → borde redondeado ≈ 10 |
| "Películas" | glifos x 257..352 |
| "Series" | glifos x 393..456 |
| Tamaño de fuente | ≈ 26–28 |

La nav **se desplaza con la página**: en `d4.png` (scroll ≈ 661) y en `s1/s2` no hay rastro
de la nav en la cabecera.

### 1.3 Hero (grande)

| Elemento | Medida |
|---|---|
| Borde inferior del arte del hero | **y ≈ 610–620** (perfil x1660..1780: último píxel brillante **609**) |
| **Altura del hero** | **≈ 620 px** = **57,4 %** de 1080 |
| Bloque de contenido | x **144** (margen izquierdo), título ≈ y 200..355 |
| "#N en Perú" (verde) | ≈ y 390..415 |
| CTA "Ver con Prime" | caja ≈ **(144, 446) 517×115**, gris redondeado ≈ 8 |
| Dots indicator | centrados ≈ y **607**, ancho total ≈ 144 (x 897..1024) |
| Badge de edad | x 1770..1831, y 553..581 |
| "Aplican condiciones" | y ≈ 600 |

> **No existe hero compacto sticky.** En `d4.png` (scroll ≈ 661) la franja y 0..185 está
> ocupada por la fila Top10 cortada contra el borde superior — ni barra de nav ni hero
> compacto. El hero simplemente **se va con el scroll**.

### 1.4 Secciones — `u0.png` (perfil de filas, x144..1780, umbral 60)

```
span 54..617    nav + hero (bloque continuo)
span 633..652   título "Top 10 en Perú"        (altura de glifos = 20)
span 668..856   fila de tarjetas               (altura = 189)
span 888..911   título "Originals y Exclusivos"(altura = 24)
span 923..1010  fila siguiente (cortada)
```

| Relación | Medida |
|---|---|
| Margen izquierdo (título y nav) | **144 px** (7,5 % de 1920) |
| Título → tarjetas | **16 px** (652 → 668) |
| Tarjetas → título siguiente | **32 px** (856 → 888) |
| Título → tarjetas (2ª fila) | 12 px (911 → 923) |
| Pitch de sección (fila Top10) | **255 px** (633 → 888) |
| Pitch de sección (fila vertical) | **642 px** (217 → 859, `d4.png`) |
| Fuente de título | banda 20–24 px ⇒ **≈ 26–28 px** |

### 1.5 Formatos de tarjeta (medidos)

| Fila | Ancho | Alto | Ratio | Separación | Pitch |
|---|---|---|---|---|---|
| **Top 10** (`u0`, `d4`) | **335** | **189** | 16:9 | — | item **514** (cifra grande ≈ 110 + tarjeta) |
| **Vertical / póster** (`d4`) | **384** (x1204..1587) | **573** (y252..824) | 2:3 | **33** | **416–420** |
| **Horizontal normal** (`q2`) | **384** (144..518, 560..943…) | **230** (605..834) | ≈16:9 (216) | **32** | **416** |
| **Resultados de búsqueda** (`srch1`) | **336** (612..947, 980..1315…) | **189** (195..383) | 16:9 | **33** | **368** |

### 1.6 Comportamiento del foco (`d4.png`)

La tarjeta vertical enfocada **se expande en una tarjeta-hero horizontal**:

| | Medida |
|---|---|
| Tarjeta enfocada | x **137..1174** (≈ **1037 × 590**, 16:9) con título + insignias + CTA superpuestos |
| Vecina sin foco | 384 × 573 |
| Escala | ≈ 1037/384 → la enfocada reencuadra, no sólo escala |
| Aro | blanco, ≈ 2–3 px |

### 1.7 Search overlay (`srch1.png`)

**No es una pantalla: es un overlay a pantalla completa** sobre el Home en negro sólido.

| Bloque | Medida |
|---|---|
| Fondo | negro puro, cubre hero + secciones; **el rail izquierdo persiste** (buscador enfocado = fondo gris redondeado x44..99) |
| Panel de teclado | **x 144..540** (396 de ancho) |
| Tecla (foco) | **66 × 66** — x 144..209, y 153..218 |
| Paso de teclas | **66** en X (177, 243, 309, 375, 441, 508) y **≈66** en Y (185, 255, 324, 387, 450, 516) |
| Rejilla | **6 columnas** × 6 filas + fila espacio/borrar + botón **"Borrar"** |
| Botón "Borrar" | x 144..543, y ≈ 618..661 (alto ≈ 44) |
| Título de resultados | x **612**, banda y **160..184** (≈ 26–28 px) |
| Tarjetas de resultados | y **195..383**, **336×189**, gap 33, pitch 368 |
| Campo de texto | **no hay** — la búsqueda se compone con el teclado en pantalla |

---

## 2. Comparativa con la UI actual de Auris TV

| Token | Auris (actual) | Prime (medido) | Δ |
|---|---|---|---|
| Margen izquierdo | 57,6 (3 %) | **144** (7,5 %) | **×2,5** |
| Topbar | sticky, `sp(72)`, pills 36 | nav **no sticky**, pill **48** en y54 | distinto modelo |
| Hero | aspecto **2.4** → 1920/2.4 = **800 px** | **≈ 620 px** (57,4 %) | **−22,5 %** |
| Hero compact sticky | `sp(275)` + reservas **235 / 205** | **no existe** | — |
| Póster vertical | **140 × 210** | **384 × 573** | **×2,74** |
| Banner 16:9 | **300 × 169** | **384 × 216** (Top10: 335×189) | **×1,28** |
| Póster grande | 270 × 405 | (foco expande a 1037×590) | — |
| Fuente de título de sección | **18** | **26–28** | **×1,45** |
| Separación entre tarjetas | **14** | **32–33** | **×2,3** |
| Título → tarjetas | 16 | **16** | ✓ |
| Tarjetas → título | 12 | **32** | ×2,7 |
| Buscador | `TextField` + micrófono + `GridView` | **teclado en pantalla** + panel de resultados | modelo distinto |

### Inconsistencia existente en Auris (a corregir)

La franja del hero compacto usa **tres valores distintos** para lo mismo:

- `home_screen.dart:509` reserva **235 px**
- `tv_scroll.dart` ancla con **205 px**
- `hero_banner.dart` pinta `compactHeroHeight` = **275 px**

---

## 3. Artefactos

| Archivo | Descripción |
|---|---|
| `primevideo_apk/base.apk` + 3 splits | APK extraído por `adb pull` |
| `primevideo_ignite/lua/appBootstrap.js` | Bootstrap Ignite (rejilla de diseño) |
| `u0.png` … `u4.png` | Home en la parte superior (rotación de hero) |
| `t1..t5.png` | Nav hacia arriba en el Home |
| `d1..d4.png` | Descenso: hero → hero parcial → secciones |
| `s0..s2.png`, `q1/q2.png`, `p0/p1.png` | Estados de scroll profundo |
| `b1..b3.png` | Rail izquierdo expandido (drawer) |
| `sb1.png`, `srch1.png` | **Search overlay** |
| `profile.ps1`, `imgdiff.ps1` | Utilidades de medición de píxeles |

**Confianza:** todas las cifras son *observadas* (recuento de píxeles sobre capturas reales)
salvo las marcas *≈*, que son inferidas del perfil. **Desconocido:** el Home con sesión
iniciada (puede diferir) y cualquier estado intermedio de scroll entre 45 y 661 px.
