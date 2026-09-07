# Plan de Limpieza de Fuentes

Este plan detalla la limpieza de las fuentes de contenido en el proyecto AurisTV, limitándolas únicamente a las especificadas como activas por el usuario.

## User Review Required

> [!IMPORTANT]
> No se mencionaron fuentes activas para el servidor de **KDramas (puerto 3002)**. Por ahora, mantendré la infraestructura de KDramas pero eliminaré los "hints" antiguos si no se confirma su actividad. ¿Existen fuentes activas para el puerto 3002?

## Proposed Changes

### [Component: API & Endpoints]

#### [MODIFY] [api_endpoints.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/core/api/api_endpoints.dart)
- Actualizar `animeHints` para incluir solo: `jkanime`, `animeav1`, `animed23`, `animejara`.
- Actualizar `movieHints` para incluir solo: `gnulahd`, `onlypelis`, `pelispedia`.

### [Component: Utils]

#### [MODIFY] [source_utils.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/core/utils/source_utils.dart)
- Limpiar `buildEpisodeUrl` eliminando lógica de fuentes obsoletas (`katanime`, `animegratis`, `aniyae`).
- Simplificar `simplifySourceName` y `_sourceDisplayOrder` eliminando fuentes inactivas.

### [Component: Providers]

#### [MODIFY] [content_providers.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/providers/content_providers.dart)
- Eliminar la inferencia de "similares" basada en la URL de `aniyae`.

#### [MODIFY] [home_provider.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/providers/home_provider.dart)
- Limpiar la lógica de detección de tipo de contenido en `_mapEditorialItemToMediaItem` y `_mapSearchResultToMediaItem`, eliminando referencias a fuentes inactivas (`flv`, `katanime`, `animegratis`).

## Verification Plan

### Manual Verification
- Verificar que el mapeo de categorías en la búsqueda siga funcionando correctamente para las fuentes activas.
- Comprobar que los nombres simplificados (JKA, AV1, etc.) se muestren correctamente en la UI.
