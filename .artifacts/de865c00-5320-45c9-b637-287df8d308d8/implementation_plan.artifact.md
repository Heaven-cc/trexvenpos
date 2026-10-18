# Revert Design to Original State

Revert all "Apple-style" design changes, including glassmorphism, custom typography, and the "Apple Design System" wrappers. This will restore the app to a standard Material 3 look and feel.

## User Review Required

> [!IMPORTANT]
> This action will remove the glassmorphism effects, custom background gradients, and the unified "Apple" design system. The app will return to a standard Material Design appearance.

## Proposed Changes

### [Core]

#### [MODIFY] [main.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/main.dart)
- Remove `AppleBackgroundScene` and `_appleTheme` that uses custom Apple colors.
- Restore a standard `MaterialApp` with default `ThemeData`.
- Remove imports of `apple_design_system.dart`.

#### [DELETE] [apple_design_system.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/core/apple_design_system.dart)
#### [DELETE] [apple_layout_utils.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/core/apple_layout_utils.dart)
#### [DELETE] [apple_components.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/core/widgets/apple_components.dart)

### [Features]

#### [MODIFY] [login_screen.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/auth/login_screen.dart)
- Replace `AppleDesign.glassMaterial` with standard `Card` or `Container`.
- Replace `AppleTextField` and `AppleButton` with `TextField` and `ElevatedButton`.
- Remove Apple-specific layout padding.

#### [MODIFY] [dashboard_screen.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/pos/dashboard_screen.dart)
- Remove `AppleDashboardTile` and replace with standard `Card` or `InkWell` based tiles.
- Remove `AppleDesign.glassMaterial` from the bottom shelf.
- Remove background transparency.

#### [MODIFY] [Inventory Screens](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/inventory/)
- `product_detail_screen.dart`: Remove `AppleDesign` usages.
- `product_search_screen.dart`: Remove `AppleDesign` usages.
- `quick_add_screen.dart`: Remove `AppleDesign` usages.
- `scanner_screen.dart`: Remove `AppleDesign` usages.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no imports of deleted files remain.
- Build the app to verify no compilation errors.

### Manual Verification
- Verify that the login screen and dashboard look like standard Material apps without the blurred background.
