# TREXVEN POS design system

This private package is owned by TREXVEN POS. Its source is physically inside
this POS project. It has no dependency on the TREXVEN Main application.

POS consumes `packages/trexven_design_system`; its local operations package
consumes `../trexven_design_system`. Keep the existing Dart package name so
application imports remain compatible. Change these files independently of
any similarly named package in another project.

The package owns theme tokens, base light/dark themes, forms, actions, cards,
dialogs, bottom sheets and loading/empty/error components. The POS application
adds its approved palette, spacing and motion through `lib/src/ui/theme/pos_theme.dart`
and installs `TrexvenPresentation.pos` at its root. That marker selects compact
POS presentation in this project's own components and operational screens.

Do not copy caches, build outputs or generated package configuration into this
package. Do not replace its local source with a filesystem link to another app.

Source was separated without running builds, analyzers, formatters or tests.
Previous shared-package runtime results do not certify this independent copy.
