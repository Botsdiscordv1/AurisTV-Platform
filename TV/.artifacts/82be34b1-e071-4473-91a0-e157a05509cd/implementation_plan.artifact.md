# Login Screen Redesign (Netflix-style TV UI)

Redesign the `LoginScreen` to provide a TV-optimized experience inspired by the Netflix login flow. This includes a QR code/numeric code option ("Use Phone") and a traditional form option ("Use Remote").

## User Review Required

> [!IMPORTANT]
> The "Use Phone" method requires a backend flow to generate a pairing code and wait for the user to authenticate on another device. I will implement the UI for this and mock the code generation. The actual pairing logic will need to be connected to your Supabase/Backend functions.

## Proposed Changes

### Auth Feature

#### [MODIFY] [login_screen.dart](file:///E:/AurisTV_Google/lib/features/auth/presentation/login_screen.dart)
- Update UI to a landscape-optimized TV layout.
- Implement a state toggle between `usePhone` and `useRemote` modes.
- Add `QrImageView` for the "Use Phone" section.
- Redesign the form fields for "Use Remote" to be more visible on TV screens.
- Add a "Netflix-style" logo in the top right.

## Verification Plan

### Manual Verification
- Run the app and navigate to the Login screen.
- Verify the layout matches the provided reference (Logo on top-right, title center, toggle buttons).
- Test switching between "Usar Teléfono" and "Usar Control".
- Ensure the QR code is legible.
- Ensure form fields are accessible via remote control (D-pad navigation).
