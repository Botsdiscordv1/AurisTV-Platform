# Especificación del Sistema Editorial y UI (Sincronización Server-Client)

Este documento detalla las implementaciones visuales recientes en el frontend de AurisTV para que el agente encargado del servidor/base de datos pueda estructurar y enviar datos reales compatibles con la nueva experiencia de usuario.

---

## 1. Arquitectura de Tarjetas Editoriales

Se han estandarizado las dimensiones y comportamientos de las tarjetas para mantener una cuadrícula cinematográfica perfecta.

### Dimensiones Estándar
- **Aspect Ratio:** 2:3 (Vertical).
- **Desktop/Web:** 200px x 300px.
- **Móvil:** 140px x 210px.

### Comportamiento de Títulos (Sincronización Global)
- Todos los títulos largos utilizan un sistema de **Marquee Sincronizado**. 
- **Requerimiento Server:** Enviar títulos descriptivos completos. El frontend se encarga del scroll automático sin jitter.

---

## 2. Niveles de Rareza Editorial (Badges)

El diseño de la tarjeta varía drásticamente según el `EditorialBadge` asignado al `MediaItem`.

### ⭐ MÍTICO (`EditorialBadge.mythical`)
*Uso: Reservado para la sección "Títulos inolvidables" (Series legendarias).*
- **Visual:** Esquinas de geometría compleja (Estilo Aniyae).
- **Efectos:** Borde animado con flujo de neón (Púrpura y Cian) y barrido de luz dorado diagonal (7s).
- **Server:** Solo asignar a obras maestras históricas (ej. One Piece, Bleach, Evangelion).

### 👑 OBRA MAESTRA (`EditorialBadge.masterpiece`)
*Uso: Sección "Obras maestras".*
- **Visual:** Aura respiratoria de color púrpura profundo y esquinas de arcos triples.
- **Server:** Obras con alta calificación técnica y narrativa.

### 💎 OTRAS CATEGORÍAS (`Joyas ocultas`, `Imprescindibles`, etc.)
- **Visual:** Utilizan la `FocusablePosterCard` estándar de alta gama.
- **Server:** Proporcionar `rating` (double) y `subtitle` (ej. "24 Episodios", "Estreno").

---

## 3. Hero Banner (Destacados)

El banner principal ha sido optimizado para inmersión cinematográfica.

### Requerimientos de Datos por Item:
- **`bannerUrl`:** Imagen horizontal de alta resolución (mínimo 1080p).
- **`trailerKey`:** ID de YouTube para reproducción automática en background (Desktop).
- **`year`:** Año de emisión para el badge de recomendación.
---

## 5. Estructura de Datos Esperada (`MediaItem`)

Para que el frontend luzca estas mejoras, el objeto `MediaItem` enviado desde el servidor debe incluir:

```json
{
  "id": "string",
  "title": "string",
  "posterUrl": "url",
  "bannerUrl": "url",
  "trailerKey": "youtube_id",
  "rating": 8.5,
  "year": "2024",
  "badge": "mythical | masterpiece | essential | hiddenGem | classic",
  "subtitle": "string (ej. 'Finalizado • 12 Eps')"
}
```

---

**Nota para el Agente del Server:** 
Las secciones editoriales ya no son simples listas de "Trendings". Por favor, prioriza la curación manual o algorítmica basada en los badges definidos para alimentar las filas de `EditorialContentRow` en la Home.
