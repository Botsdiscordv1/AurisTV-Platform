# Plan de Mejora: Búsqueda Híbrida y Pulido de SearchScreen

Este plan se enfoca en perfeccionar la integración del historial local en la búsqueda, asegurando que los resultados inmediatos tengan la misma riqueza visual que los del servidor y optimizando el rendimiento de la parrilla de resultados.

## User Review Required

> [!IMPORTANT]
> Se añadirá un nuevo campo `progress` al modelo `SearchResult` en el Core. Esto permite que el motor de búsqueda "inyecte" el progreso directamente, evitando que la UI tenga que buscar en el historial en cada frame de scroll.

## Proposed Changes

### [Component: Core - Models & Logic]

#### [MODIFY] [search_result.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/models/server/search_result.dart)
- Añadir `final double? progress;` a la clase `SearchResult`.
- Actualizar `copyWith`, `fromJson` y `toJson` para soportar este campo.

#### [MODIFY] [search_progressive.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/providers/search_progressive.dart)
- En `_loadLocalResults`, mapear los campos faltantes desde `PlaybackHistory`: `kind`, `type`, `season` y el nuevo campo `progress`.
- Asegurar que la `quality` se marque como `'Historial'` para que el resolver de metadatos pueda identificarlo.

#### [MODIFY] [content_metadata_resolver.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/core/utils/content_metadata_resolver.dart)
- Actualizar `resolveMetadata` para que, si detecta `quality == 'Historial'`, priorice una etiqueta visual distintiva (ej. "VISTO" o "EN HISTORIAL").
- Ajustar los colores del `ContentMetadata` para que los ítems del historial usen un tono que los diferencie sutilmente (ej. `Color(0xFF2A2A2A)` del design system).

---

### [Component: Web/Desktop - Presentation]

#### [MODIFY] [search_screen.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/features/search/presentation/search_screen.dart)
- Eliminar la lógica de búsqueda manual de progreso dentro del `itemBuilder`.
- Usar directamente `result.progress` para alimentar el `FocusablePosterCard`.
- Esto reducirá la carga del hilo de UI durante el scroll rápido.

## Verification Plan

### Manual Verification
1. **Metadata Check**: Escribir un término que esté en el historial (ej: "Yo") y verificar que ahora aparezca la etiqueta "TV ANIME" (o la correspondiente) y no solo la barra de progreso.
2. **Badge Visual**: Confirmar que los resultados del historial se distinguen visualmente de los resultados "frescos" del servidor.
3. **Smoothness**: Realizar scroll rápido en una búsqueda con muchos resultados y verificar que no hay micro-tirones (jank) gracias a la eliminación del look-up manual de progreso.
