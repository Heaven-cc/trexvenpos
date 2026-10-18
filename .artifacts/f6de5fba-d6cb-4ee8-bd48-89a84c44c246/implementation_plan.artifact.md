# Expert iOS Redesign — Trexven POS (Apple Design Language)

As an expert iOS developer, I am refactoring the **entire** Trexven POS suite to strictly adhere to Apple's Human Interface Guidelines (HIG) and the modern "Liquid Glass" design system. This isn't just a skin; it's a fundamental rebuild of the user experience to prioritize clarity, hierarchy, and physical presence.

## User Review Required

> [!IMPORTANT]
> **Vibrancy & Depth**: We are implementing a "Material-First" architecture. This uses `BackdropFilter` layers (Ultra Thin to Thick) to create semantic depth.
> **Physics-Based UI**: All interactions will use iOS-native physics (Bouncing, Rubber-banding) and precise Haptic feedback patterns.
> **Font Stack**: We will implement a custom `SF Pro` compatible font hierarchy to ensure premium legibility and weight balance.

## Proposed Changes

### 1. The Canvas: Global Scene & Materials [DONE]

#### [NEW] [apple_design_system.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/core/apple_design_system.dart) [DONE]
#### [NEW] [apple_layout_utils.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/core/apple_layout_utils.dart) [DONE]

---

### 2. High-Fidelity Feature Refactoring [DONE]

#### [MODIFY] [main.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/main.dart) [DONE]
#### [MODIFY] [login_screen.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/auth/login_screen.dart) [DONE]
#### [MODIFY] [dashboard_screen.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/pos/dashboard_screen.dart) [DONE]
#### [MODIFY] [product_search_screen.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/inventory/product_search_screen.dart) [DONE]
#### [MODIFY] [product_detail_screen.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/inventory/product_detail_screen.dart) [DONE]
#### [MODIFY] [checkout_screen.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/pos/checkout_screen.dart) [DONE]
#### [MODIFY] [recent_sales_screen.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/pos/recent_sales_screen.dart) [DONE]
#### [MODIFY] [business_selection_screen.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/auth/business_selection_screen.dart) [DONE]
#### [MODIFY] [quick_add_screen.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/inventory/quick_add_screen.dart) [DONE]
#### [MODIFY] [scanner_screen.dart](file:///C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/inventory/scanner_screen.dart) [DONE]

---

### 3. iOS Interaction Patterns [DONE]

#### [NEW] Reusable Expert Components [DONE]

## Verification Plan

### Automated Tests
- Audit against HIG contrast ratios.
- Verify "Liquid Glass" blur intensity levels.

### Manual Verification (Expert Review)
- **Fluidity**: Verify 60/120fps animations on all transitions.
- **Responsiveness**: Ensure the "Touch & Hold" interaction feels substantial.
- **Dark Mode**: High-fidelity dark mode verification (System Gray hierarchy).
