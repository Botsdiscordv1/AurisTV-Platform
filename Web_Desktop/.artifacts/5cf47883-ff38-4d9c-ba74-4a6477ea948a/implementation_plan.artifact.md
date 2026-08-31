# Plan de Mejora de URLs (Enrutamiento Profesional)

Este plan detalla la migración de las rutas actuales a unas más semánticas y profesionales, optimizadas para Web, siguiendo el estándar de las plataformas de streaming modernas.

## User Review Required

> [!IMPORTANT]
> Se cambiarán las rutas base de la aplicación. Aunque el enrutamiento interno funcionará igual, si el usuario tiene marcadores (bookmarks) en su navegador con las URLs viejas (ej: `/search`), estas dejarán de funcionar a menos que implementemos redirecciones. Para este plan, nos enfocaremos en actualizar la navegación interna.

> [!NOTE]
> La ruta de reproducción se integrará bajo `/media/:title/:episode` para que sea más natural, similar a `animeav1.com`.

## Proposed Changes

### [Core] [app_router.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/core/router/app_router.dart)

#### [MODIFY] [app_router.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/core/router/app_router.dart)
- Actualizar `/search` a `/catalogo`.
- Actualizar `/schedule` a `/horario`.
- Actualizar `/content/:title` a `/media/:title`.
- Actualizar `/player/:contentId` a `/media/:title/ver` o una estructura anidada. Decidiremos usar `/media/:title/ver` para el reproductor para mantener consistencia cuando no hay un número de episodio claro, o `/media/:title/:episode` si el episodio existe.

---

### [Features] Navegación y Pantallas

#### [MODIFY] [content_screen.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/features/content/presentation/content_screen.dart)
- Actualizar todas las llamadas a `context.push('/player/...')` por la nueva estructura.
- Actualizar redirecciones internas.

#### [MODIFY] [home_screen.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/features/home/presentation/home_screen.dart)
- Cambiar botones de acceso rápido a `/catalogo` y `/horario`.

#### [MODIFY] [explore_screen.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/features/explore/presentation/explore_screen.dart)
- Actualizar navegación a fichas de contenido.

#### [MODIFY] [search_screen.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/features/search/presentation/search_screen.dart)
- Actualizar navegación a fichas de contenido.

#### [MODIFY] [main_navigation_wrapper.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/shared/widgets/main_navigation_wrapper.dart)
- Actualizar lógica de resaltado de iconos (ShellRoute) para que reconozca `/catalogo`.

## Verification Plan

### Automated Tests
- No hay tests de integración de rutas actualmente, se verificará mediante compilación.

### Manual Verification
1. Abrir la web en el navegador.
2. Navegar a "Catálogo" y verificar que la URL diga `/catalogo`.
3. Navegar a "Horario" y verificar `/horario`.
4. Abrir un anime y verificar que la URL sea `/media/nombre-del-anime`.
5. Reproducir un episodio y verificar la URL de reproducción.
