# Refactor de Carga Paralela en Detalle (Ficha)

Optimizar la carga de la pantalla de detalle ("ficha") disparando las peticiones de episodios (fast), reparto (cast) y relacionados (relations) en paralelo en lugar de esperar a una respuesta única pesada.

## User Review Required

> [!IMPORTANT]
> Se han añadido nuevos endpoints `/api/cast` y `/api/relations` que deben estar soportados por el backend.
> La lógica de `episodes?fast=1` asume que el backend ignora cast/relations en este modo para reducir latencia.

## Proposed Changes

### [Component Name] Core / API

#### [MODIFY] [api_endpoints.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/core/api/api_endpoints.dart)
- Añadir constantes para `cast` y `relations`.

### [Component Name] Data / Repository

#### [MODIFY] [auris_repository.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/repositories/auris_repository.dart)
- Añadir métodos `getCast(String url)` y `getRelations(String url)`.
- Actualizar `getEpisodes` para aceptar el parámetro `fast`.

#### [MODIFY] [auris_repository_impl.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/repositories/impl/auris_repository_impl.dart)
- Implementar `getCast` y `getRelations`.
- Actualizar `getEpisodes` para enviar `fast=1` si se solicita.

### [Component Name] Data / Models

#### [MODIFY] [unified_content_state.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/models/unified_content_state.dart)
- Añadir `AsyncValue<List<CastInfo>> cast` al estado unificado.

### [Component Name] Data / Providers

#### [MODIFY] [content_providers.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/providers/content_providers.dart)
- Actualizar `EpisodesParams` para incluir `fast`.
- Añadir `castProvider` y `relationsProvider`.
- Actualizar `episodesProvider` para manejar el reintento sin `fast` si falla con `fast: true`.

#### [MODIFY] [unified_content_notifier.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/providers/unified_content_notifier.dart)
- Orquestar las 3 llamadas en paralelo dentro de `unifiedContentProvider`.
- Mapear los resultados al `UnifiedContentState`.

## Verification Plan

### Manual Verification
- Abrir una ficha de serie/anime y verificar que el player y la lista de capítulos cargan rápidamente (vía `fast=1`).
- Verificar que el carrusel de reparto (Cast) aparece poco después de forma independiente.
- Verificar que la fila de relacionados aparece al final de forma independiente.
- Probar con fuentes que no devuelven relacionados (ej. OnlyPelis) y verificar que la fila se oculta correctamente.
- Verificar que al hacer click en un actor se dispara la búsqueda de créditos correctamente.
