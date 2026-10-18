# TREXVEN POS source independence — 17 October 2026

The source separation is implemented. POS owns its own operational package and
design-system package inside this project. Neither app now consumes the other
app's package directories. This is a static source/dependency handover, not a
build or runtime certificate.

## Original and current dependency structure

Previously:

```text
trexvenpos/pubspec.yaml
  -> ../Trexven/packages/trexven_operations
       -> ../trexven_design_system (inside Main)
  -> ../Trexven/packages/trexven_design_system

Trexven/pubspec.yaml
  -> packages/trexven_operations
  -> packages/trexven_design_system
```

Now:

```text
trexvenpos/
  pubspec.yaml
    -> packages/trexven_operations
         -> ../trexven_design_system (inside POS/packages)
    -> packages/trexven_design_system
  lib/src/ui/                 (existing POS theme and components)
  packages/
    trexven_operations/       (independent POS-owned files)
    trexven_design_system/    (independent POS-owned files)

Trexven/                     (unchanged by this task)
  pubspec.yaml
    -> packages/trexven_operations
    -> packages/trexven_design_system
```

Package names and existing `package:trexven_operations/...` and
`package:trexven_design_system/...` imports are retained. Package resolution now
selects this project's files, not Main's similarly named files. Identical Dart
package names do not make the physical files shared.

Inspection covered both apps' pubspecs, resolved package roots and nested
package declarations, POS's lockfile and package graph, Dart imports/exports/
parts including conditional imports, IDE configuration and direct file paths.
The resolved POS configuration has 131 packages. Exactly two resolved dependencies
were Main-owned, and the only nested local package edge is operations to the
design system. No additional Main-owned dependency was found.

The pre-existing live-restart test also read a fixture from Main. It now reads
the POS-local `.batch2-tools/batch9_live_restart_fixture.json`, optionally
overridden by the `LIVE_RESTART_FIXTURE` Dart environment value. No fixture,
credentials or database contents were copied. The test remains skipped without
an explicit `LIVE_RESTART_PHASE`; it was not run.

## Package contents added

There is one POS copy of each package: 26 Dart files, two package manifests and
two new package READMEs, for 30 package files total.

```text
packages/trexven_design_system/
  pubspec.yaml
  README.md
  lib/trexven_design_system.dart
  lib/src/components/actions.dart
  lib/src/components/forms.dart
  lib/src/components/surfaces.dart
  lib/src/theme/presentation.dart
  lib/src/theme/tokens.dart
  lib/src/theme/trexven_theme.dart

packages/trexven_operations/
  pubspec.yaml
  README.md
  lib/trexven_operations.dart
  lib/src/cash_shift_screen.dart
  lib/src/customer_presentation.dart
  lib/src/durable_state.dart
  lib/src/employee_access_screen.dart
  lib/src/encrypted_state.dart
  lib/src/encrypted_state_native.dart
  lib/src/encrypted_state_unsupported.dart
  lib/src/financial_operations_details.dart
  lib/src/financial_operations_screen.dart
  lib/src/financial_operations_support.dart
  lib/src/inventory_operations_screen.dart
  lib/src/inventory_operations_views.dart
  lib/src/notification_center_screen.dart
  lib/src/operation_journal.dart
  lib/src/operations_client.dart
  lib/src/payment_confirmation_dialog.dart
  lib/src/stock_count_batch.dart
  lib/src/text_controller_scope.dart
```

Four unused files and their exports were deliberately omitted after checking
POS source/tests and retained package imports: `account_operations_screen.dart`,
`operational_permissions_screen.dart`, `entitlements.dart`, `metric_content.dart`.
The package dependencies were not expanded. Keeping the two established package
boundaries preserves public imports and existing internal parts without a larger
workflow rewrite. Required files retain some Owner-capable branches to avoid
unnecessary refactoring; those branches are local POS source and have no Main
source dependency.

No build artifacts, caches, backup project, symlink, junction, hard-linked files
or Git package dependency was introduced. Physical real paths of both new
packages are inside POS, and every package file has a link count of one.

## Existing POS files modified

| File | Change |
|---|---|
| `pubspec.yaml` | Both package paths now start with `packages/`. |
| `pubspec.lock` | Only the same two path values changed; versions and resolved third-party dependencies retained. |
| `.dart_tool/package_config.json` | Both resolved package roots now point to `../packages/...`, relative to `.dart_tool`. |
| `.idea/libraries/Dart_Packages.xml` | Operations paths corrected; local design-system library entry and root added. |
| `test/pending_sale_live_restart_test.dart` | Removed Main fixture path; POS-local/configurable fixture location. |
| `lib/src/ui/theme/pos_theme.dart` | Input label typography standardized to 14px. |

The package graph and plugin metadata need no path rewrite beyond these changes:
package names/dependency edges remain the same, and neither contains a remaining
Main source location. Generated configuration was updated directly; no dependency
solver, dependency installation or `flutter pub get` was run.

Three obsolete incremental-build metadata files referencing the former Main
sources were invalidated inside `.dart_tool/flutter_build/1c4fe3f67683e1b54f98adbcedff32ab/`:
`kernel_snapshot_program.stamp`, `kernel_snapshot_program.d` and `.filecache`.
Existing compiled artifacts were not copied or treated as validation evidence.

## Main protection and backend preservation

No files were written in the Main project. Before/after SHA-256 comparison found
zero changes across 756 inspected Main files: application/package source,
assets, tests, platform source/configuration, backend source and root files,
excluding generated caches and IDE state. Main's dependencies and package
directories remain intact.

Both apps still default to `https://ufehcfrlygqvminfjumf.supabase.co`, with their
existing environment override behavior. POS's Supabase initialization,
configuration, authentication, branch/permission code, models, repositories,
offline queue, pending-sale storage and recovery remain unchanged. Forty-six
existing POS application Dart files match their pre-separation hashes; the only
application-source edit in this task is the input label size.

The copied `operations_client.dart`, operation journal, encryption/durable-state
code, customer presentation and stock-count batching match the original bytes.
No RPC name, argument map, authorization rule, retry identity, transaction,
local-storage identity or Supabase integration was changed. UI-source changes
inside seven copied operational files consist solely of removing invalid
`const` qualifiers from padding constructors using runtime styling.

No database calls, production data changes, tables, migrations, RLS changes,
Edge Function changes/deployments or new backend project were made. Backend
preservation is established by source comparison; live workflows were not run.

## Independent POS UI status

The previously implemented POS redesign is retained inside POS-owned code:
hybrid light/dark themes, deep navy/electric blue palette, compact components,
limited premium surfaces, forms, dialogs, bottom sheets, navigation and reduced-
motion handling. Credit/Returns, inventory/stocktaking, cash shifts, payment,
notifications and employee access now render from this project's own packages.
Future edits to these POS files cannot change Main's separate source files.

Checkout, Confirm Payment and Sale Completion remain separate stages. Barcode
scanning retains Angel Scan branding without adding Owner Angel AI behavior.
Existing operational routes and permissions remain in place.

After separation, source review corrected 29 invalid constant padding
declarations across seven POS-owned operational files. Those declarations call
runtime theme-spacing helpers, so they cannot be constant expressions. The
precise locations are in `POS_LOCAL_UI_SOURCE_CORRECTIONS_20261017.json`.
The app input label size was also brought onto the approved 14px text scale.
These edits did not touch Main or change backend behavior.

The historical UI handover remains at `TREXVEN_POS_UI_IMPLEMENTATION_20261017.md`.
Its shared-package paths and impact describe the earlier state; this report and
the new manifest supersede that ownership information. The earlier screen/modal
inventory still describes the retained UI implementation. Historical evidence
and this read-only migration audit naturally mention Main; they are not POS
runtime/build dependencies.

Expenses remains the previously documented functional blocker: no attributed
branch/cash-expense backend contract was implemented. Its explicit unavailable
screen is retained. Separation does not authorize a backend change or invent an
expense workflow.

## Static evidence and limits

`POS_SOURCE_SEPARATION_BASELINE_20261017.json` records pre-change file hashes and
resolved package roots. `POS_SOURCE_SEPARATION_MANIFEST_20261017.json` records:

- Zero Main file changes and zero Main-owned resolved POS dependencies.
- All three local dependency paths resolve inside POS.
- No Main source path in inspected application/package/test Dart files.
- All local and cached-package import/export/part targets inspected exist.
- No remaining constant constructors containing the runtime presentation helper
  in the source pattern inspected.
- Copies' original and installed SHA-256 values, all added/modified source files,
  generated configuration hashes, invalidated metadata and physical ownership.
- Exact comparison showing only two path values changed in root pubspec/lockfile.
- No unexpected operational-source difference after allowing only the specified
  padding `const` corrections and removing unused barrel exports.

No Flutter build, analyzer, formatter, test, integration test, emulator or app
launch was run. These static checks are not a Dart compiler/type checker and do
not prove runtime compatibility, visual layout, device behavior or backend
transaction success. The Node helper in this artifacts folder is an inspection/
migration tool, not a runtime component or an automated application test.

## Manual verification required

Use the normal POS dependency-resolution/build workflow when ready; generated
metadata should continue resolving the local package paths. Confirm that the
project can resolve/build with Main absent from its sibling location. No rename
or movement of Main was performed during this task.

On authorized accounts and appropriate fixtures, check:

1. Employee login, permission visibility, branch selection and denied actions.
2. Product search/editing, Angel Scan barcode lookup and catalog navigation.
3. Stocktake creation/count/review and authorized inventory adjustment flows.
4. Checkout, payment-method switching, split payment, cash tendered/change,
   electronic confirmation, confirmed completion and receipt access.
5. Credit creation/repayment, approvals where permitted, return/refund history
   and correct backend records in both apps.
6. Cash drawer open/movements/close, handover and reconciliation permissions.
7. Offline sales, synchronization, interrupted-sale restart/retry and absence
   of duplicate receipts or stock movements. Supply a disposable local fixture
   if manually using the opt-in live-restart test.
8. Notifications, employee access, System/Light/Dark modes, keyboard/small-screen
   layouts, large text and reduced motion.

Independent copies can now evolve separately; future operational/backend
contract changes must be applied deliberately to each app where required.
No source-independence blocker remains from this inspection. Runtime verification
and the existing expense-backend gap remain open.
