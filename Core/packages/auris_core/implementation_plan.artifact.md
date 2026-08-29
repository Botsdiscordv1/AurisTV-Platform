# Plan de Implementación: Automatización de Proxy de Imágenes en Modelos del Core

Este plan detalla los cambios necesarios para automatizar la llamada a `ApiEndpoints.proxyImage()` en los factories `fromJson` de todos los modelos de datos del core. Esto asegurará que cualquier imagen consumida por los clientes (Mobile, Web, TV) pase por el proxy cuando sea necesario para evitar problemas de CORS y bloqueos de red.

## Cambios Propuestos

Se modificarán los modelos en `auris_core` para envolver todas las URLs de imágenes con `ApiEndpoints.proxyImage()`.

### [Componente] auris_core / Models

#### [MODIFY] [search_result.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/models/server/search_result.dart)
- Agregar import de `api_endpoints.dart`.
- Modificar `SearchResult.fromJson` para procesar `thumbnail`, `banner` y `logo`.

#### [MODIFY] [anime_detail.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/models/server/anime_detail.dart)
- Agregar import de `api_endpoints.dart`.
- Modificar `AnimeDetail.fromJson` para `poster`, `backdrop`, `banner` y `logo`.
- Modificar `CharacterInfo.fromJson` para `image`.
- Modificar `VoiceActorInfo.fromJson` para `image`.
- Modificar `TrailerInfo.fromJson` para `thumbnail`.
- Modificar `RelationInfo.fromJson` para `poster`.
- Modificar `RecommendationInfo.fromJson` para `poster`.
- Modificar `AnimeThemeInfo.fromJson` para `imageUrl`.

#### [MODIFY] [movie_detail.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/models/server/movie_detail.dart)
- Agregar import de `api_endpoints.dart`.
- Modificar `MovieDetail.fromJson` para `poster`, `backdrop` y `logo`.
- Modificar `SeasonInfo.fromJson` para `poster`.
- Modificar `PlatformInfo.fromJson` para `logo`.

#### [MODIFY] [gallery.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/models/server/gallery.dart)
- Agregar import de `api_endpoints.dart`.
- Modificar `GalleryImage.fromJson` para `url`.

#### [MODIFY] [omdb_episode.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/models/server/omdb_episode.dart)
- Agregar import de `api_endpoints.dart`.
- Modificar `OmdbEpisode.fromJson` para `thumbnail`.

#### [MODIFY] [schedule.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/models/server/schedule.dart)
- Agregar import de `api_endpoints.dart`.
- Modificar `ScheduleItem.fromJson` para `coverImage` y `banner`.

#### [MODIFY] [editorial_section.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/data/models/server/editorial_section.dart)
- Agregar import de `api_endpoints.dart`.
- Modificar `EditorialItem.fromJson` para `posterUrl` y `bannerUrl`.

## Plan de Verificación

### Verificación Manual
1. Abrir la aplicación en Web (si es posible) y verificar que las imágenes de búsqueda y detalle cargan correctamente a través del proxy.
2. Inspeccionar el tráfico de red para confirmar que las URLs de imágenes ahora incluyen `/api/proxy/image?url=...`.
3. Verificar en Android que los dominios bloqueados (como jkanime) ahora cargan imágenes gracias al proxy.
