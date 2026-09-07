# Consolidated Routing Implementation Plan

The user reported that the specific category URLs (`/inicio`, `/animes`, `/peliculas`, `/kdramas`) are causing errors. This plan will consolidate these categories into a single route (`/inicio`) and manage the category selection internally within the `HomeScreen` state.

## Proposed Changes

### [Core/Router]

#### [MODIFY] [app_router.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/core/router/app_router.dart)
- Remove the individual `GoRoute` definitions for `/animes`, `/peliculas`, `/series`, and `/kdramas`.
- Keep only `/inicio` as the primary entry point for the home branch.

### [Features/Home]

#### [MODIFY] [home_screen.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/features/home/presentation/home_screen.dart)
- Update `_handleCategoryChange` to update the `homeCategoryProvider` state directly instead of performing a `context.go(path)` navigation.
- Update `openHomeDetails` to use `/inicio` as the default return path since sub-routes will no longer exist.
- Update `didUpdateWidget` and `initState` logic to ensure category state is handled correctly without relying on route parameters if they are removed.

### [Shared/Widgets]

#### [MODIFY] [main_navigation_wrapper.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/shared/widgets/main_navigation_wrapper.dart)
- Simplify `isRootPath` check to only consider `/inicio` (and other main tabs like `/catalogo`, `/explore`, `/settings`) as root paths, removing the specific category routes.

### [Other Features]

#### [MODIFY] [login_screen.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/features/auth/presentation/login_screen.dart)
#### [MODIFY] [content_screen.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/features/content/presentation/content_screen.dart)
#### [MODIFY] [settings_screen.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/features/settings/presentation/settings_screen.dart)
- Replace any navigation calls to `/animes`, `/peliculas`, etc., with `/inicio`.

## Verification Plan

### Manual Verification
- Verify that clicking on "Animes", "Películas", etc., in the home navigation bar correctly switches the content without changing the browser's URL.
- Verify that navigating back from a media detail page returns to the home screen.
- Verify that the app still starts at the home screen by default.
