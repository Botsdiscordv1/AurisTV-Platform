# Adaptive Layout Improvement Plan

This plan aims to standardize and improve the adaptive layout of the AurisTV Web & Desktop application by introducing a formal breakpoint system and refactoring existing UI components to use it.

## User Review Required

> [!IMPORTANT]
> The implementation will introduce a new set of standardized breakpoints (BASE, SM, MD, LG, XL, XXL). Some existing manual width checks in `HomeScreen` and `HeroBanner` will be replaced, which might slightly alter the layout at specific transition points (e.g., from 920px to 768px/1024px).

## Proposed Changes

### [Auris Core]

#### [MODIFY] [responsive_utils.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/core/utils/responsive_utils.dart)
- Introduce a `Breakpoint` enum: `base` (<480), `sm` (≥480), `md` (≥768), `lg` (≥1024), `xl` (≥1280), `xxl` (≥1536).
- Add `getBreakpoint(BuildContext context)` method.
- Add helper methods like `isAtLeast(Breakpoint)`, `isAtMost(Breakpoint)`.
- Update `isMobile`, `isTablet`, `isDesktop` to align with these new breakpoints.
- Add an extension on `BuildContext` for easy access: `context.breakpoint`, `context.isMobile`, etc.

#### [MODIFY] [hero_banner.dart](file:///E:/AurisTV_plataformas/Core/packages/auris_core/lib/presentation/widgets/hero_banner.dart)
- Replace hardcoded `screenWidth < 768` checks with `context.isMobile` (using the new `md` threshold or specific breakpoint).
- Adjust internal paddings and aspect ratios based on the new breakpoints.

---

### [Web Desktop]

#### [MODIFY] [home_screen.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/features/home/presentation/home_screen.dart)
- Replace manual checks like `width < 1150` and `width < 920` with standardized breakpoint logic (e.g., `context.breakpoint <= Breakpoint.md`).
- Refactor `_buildTopNavContent` to use the new breakpoints for logo size, navigation height, and visibility of elements (grid, language selector, etc.).

#### [MODIFY] [min_width_wrapper.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/shared/widgets/min_width_wrapper.dart)
- Align the default `minWidth` with the `LG` breakpoint (1024).
- Add documentation explaining how it interacts with the new breakpoint system.

## Verification Plan

### Manual Verification
- Resize the browser window and verify that the layout transitions correctly at 480px, 768px, and 1024px.
- Verify that the `HeroBanner` switches between mobile and cinematic layouts at the `MD` (768px) boundary.
- Verify that the `HomeScreen` navigation bar elements (Grid, Auth button, etc.) hide/show as expected at the new breakpoints.
- Verify that the horizontal scroll (if enabled by `MinWidthWrapper`) only appears below the 1024px threshold on Desktop.
