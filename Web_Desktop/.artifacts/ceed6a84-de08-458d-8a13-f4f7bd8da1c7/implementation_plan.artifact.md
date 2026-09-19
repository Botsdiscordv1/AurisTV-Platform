# Fix Navigation Crash on Mobile/Tablet

The app crashes when tapping the Profile/Settings icon in the bottom navigation bar on mobile/tablet devices. This happens because the `MainNavigationWrapper` tries to navigate to the 4th branch (index 3) of the `StatefulShellRoute`, but only 3 branches are defined in `app_router.dart`.

## Proposed Changes

### [core]

#### [MODIFY] [app_router.dart](file:///E:/AurisTV_plataformas/Web_Desktop/lib/core/router/app_router.dart)
- Add a 4th `StatefulShellBranch` to the `StatefulShellRoute` for the `/settings` path.
- Remove the redundant `/settings` `GoRoute` defined outside the `StatefulShellRoute` to ensure it is handled correctly within the navigation shell.

## Verification Plan

### Automated Tests
- Not applicable for this UI navigation fix.

### Manual Verification
1. Run the app on a mobile emulator or resize the browser to trigger the mobile layout (bottom navigation bar).
2. Tap on the 4th icon (Profile/User).
3. Verify that the app navigates to the Settings screen without crashing.
4. Verify that the Home, Search, and Explore tabs still work correctly.
