# TREXVEN POS implementation handover — 17 October 2026

The approved audit has been implemented in the existing POS source, with the expense-contract exception described below. No new Flutter project, duplicated repository, new dependency, downloaded asset or build output was created.

This is a source implementation handover, not a build/test/runtime certificate. No application compilation, analyzer, formatter, automated test, app launch or emulator was run.

## Scope and shared-package impact

There are 36 changed/new source files: 23 POS-owned files and 13 shared presentation files. Six are new source files; no operational controller, data repository, ledger or backend was copied.

The POS root installs TrexvenPresentation.pos inside MaterialApp.builder, supplying the POS premium gradient. The Owner application does not install this marker. Shared color, typography, spacing, form-gap and motion helpers return the original values when the marker is absent. Explicit alternative widgets (payment, picker, compact cash summary/shift rows, notification states and inventory dropdown labels) use a POS branch and retain their legacy Owner branch.

The original shared theme/tokens remain unchanged:
- DS/lib/src/theme/trexven_theme.dart
- DS/lib/src/theme/tokens.dart

No Owner application file under Trexven/lib was modified. The authorized shared package extensions were modified; they are not claimed to be untouched. Code inspection establishes the opt-in boundary. Owner runtime regression validation has not been run.

Path shorthand:
- POS = this project's root.
- DS = ../Trexven/packages/trexven_design_system/
- OPS = ../Trexven/packages/trexven_operations/

## New POS design system

- lib/src/ui/trexven_ui.dart: POS UI entry point.
- lib/src/ui/theme/pos_theme.dart: light/dark ThemeData, Roboto text roles, palette, 4px spacing, shapes, motion and premium gradient.
- lib/src/ui/components/pos_components.dart: compact surfaces, premium glass-style surface, semantic status badge, shared action row and scroll-safe state view.
- DS/lib/src/theme/presentation.dart: small optional presentation boundary consumed by shared widgets; no Owner theme defaults changed.

Palette: dark #0C1426 / #18243D / #22314D, action blue #326BF3, accent #91B5FF, dark text #F8FAFC / #9EAECA and border #344460; light #F5F7FC / #FFFFFF / #EDF2FA, text #17233E / #64748B and border #DCE3EF. Semantic error/success/warning roles remain readable in both modes.

Normal text roles are 12/14/16/18/20/22/28. Cards use compact 12–16px padding and 16px default corners; standard buttons and inputs use 12px corners. Editable controls retain a 48px minimum and grow for labels, multiline text, validation and accessibility scaling. Their rendered dimensions still require manual checking.

Existing TrexvenTextField, TrexvenTextFormField, TrexvenDropdown, TrexvenLoading, TrexvenEmptyState and Material components are reused. POS action/settings/menu rows now share one presentation instead of separate visual implementations. Primary, secondary and confirmation actions use centralized button/dialog/sheet styling. Obsolete Home card classes, the unused Sales landing and the duplicate Checkout payment-method selector were removed.

Glass styling is limited to payment/completion summaries: navy/blue gradient, slight translucency and thin highlight border. There is no BackdropFilter/large scrolling blur or decorative business-performance banner.

## Navigation, motion and input changes

Home / Inventory / More, their permissions, visited stack and context keys are retained. The pushed Product Search now exposes Back while its tab instance remains a tab. Home uses compact grouped actions and a transaction-cart footer. About retains real build metadata and the license flow.

Motion tokens are 150ms feedback, 200ms components/dialogs and 250ms pages/sheets, using a restrained ease-out curve. POS routes fade; shared dialogs/sheets receive animation settings only inside the POS marker. Navigation follows the component duration. Reduced-motion handling suppresses transitions and pauses the existing scanner guide at a static midpoint; its original 1800ms scanning cadence is otherwise retained.

Input fixes:
- Removed doubled Login/Change Password spacing and standardized gaps.
- Kept the Quick Add barcode label explicit when its decoration is copied.
- POS stock-condition/branch dropdowns use the persistent-label wrapper; legacy Owner widgets are retained.
- All shared form labels use the POS text color in POS mode.
- Existing validators/controllers/parsing remain in place. Amount inputs keep raw editing text and cursor behavior; formatted totals are separate.
- Camera controls have named 48px targets. Password and quantity controls have descriptive tooltips.
- Fixed loading-spinner and success/error notice foreground roles for dark mode.
- Branch/recovery/search error and empty states are scroll-safe; the POS inventory picker scrolls its header and lazy product list above the keyboard.

## Checkout, payment and completion

These remain distinct:
1. Checkout: products, quantities, authorized prices/discounts, total and Proceed to Payment.
2. Confirm Payment: selected method, retained split allocations, credit request and actual-payment acknowledgment.
3. Sale Completion: shown after the existing submission returns its confirmed receipt, with receipt access and New Sale.

The new payment presentation is enabled only in POS. The legacy Owner layout stays available. Both views call the same submission validator; payment/credit authorization has not been forked.

Cash, Bank Transfer and POS Terminal have three selectable chips. Only the selected form is expanded; switching does not discard another method's amount/reference. Cash shortcuts update tendered cash. Cash applied is capped by the remaining sale allocation, and the remainder is displayed as change. Only the applied payment lines go to the existing transaction contract; tender/change presentation metadata is not sent as extra revenue or a new backend field.

Credit is selectable only with a positive unpaid balance and stays separate from collected money. The existing debtor/contact/due-date fields and exact-sale approval/recovery workflow are retained. Existing business/branch exposure rules are described accurately; no individual customer allowance or fake approval is shown. The verification checkbox remains explicitly cashier acknowledgment, not provider settlement.

Completion uses returned payment/credit details when available. It does not reconstruct unknown split payments or substitute a zero for a missing payment amount. Cash tender/change is shown when captured in the current checkout; the existing backend/retained receipt does not persist that presentation metadata, so it may be absent after a restart/recovery. Receipt acknowledgment still follows the original confirmed operation.

Sales History no longer displays employee-facing aggregate performance. It has local search over authorized receipt/product/method data, method filters, lazy compact rows and individual receipt details. It continues using the same authorized provider and backend records.

## Expense integration — blocked by verified existing contract

A read-only production metadata query confirmed:
- public.expenses has id, business_id, employee_id, category, description, amount, payment_method and created_at (default now()); it has no branch_id.
- No public/private function name containing expense exists.
- Its restrictive policies require view_finance and the legacy NULL-branch record boundary.
- No expense-specific trigger enforces the actor/cash attribution or records the corresponding drawer/financial movement; the listed business-write trigger is an Admin access boundary.

A direct table insert would not satisfy the requested branch attribution and transaction-integrity contract. No insert was implemented and no production schema, policy or function was changed.

Home now opens a themed, explicit Expenses-unavailable screen instead of the integration-pending snackbar. Expense entry and Expense History are not claimed as implemented.

Required separate backend work: an authorized, idempotent cash-expense transaction with server-validated employee/business/branch, actual server timestamp/configured business day, authorized cash-drawer/ledger/audit linkage, and permission-scoped history reads. Do not activate an insert UI until that contract is supplied and authorized.

Other supported-workflow limits:
- Existing credit limits are business/branch exposure. No per-customer available allowance is invented.
- Quick Add keeps the supported pending-review fields; authorized editing still exposes the existing metadata/unit/image URL/variant/price/stock controls. No image-upload service or expanded product-creation authority was invented.
- Existing direct reads do not provide an independently verified provider-settlement status; the UI does not fabricate it.

## Screen-by-screen implementation report

All rows below are source-implemented/refined, with runtime verification pending. There are 41 audited screen/modal flows plus the explicit expense blocker. “No blocker” refers to presentation implementation, not proof of runtime behavior.

Manual verification codes:
- M1: light/dark, 320px/small-height screens, large text, insets, contrast, semantics and reduced motion.
- M2: keyboards, labels, focus/disabled/error/helper states, cursor and validation.
- M3: real authorized checkout/splits/credit/receipts/amounts and role visibility.
- M4: camera permission/scanning, product selection/counts, adjustments and stock workflows.
- M5: employee/manager/Owner grants, branch switching/revocation and shared Owner fallback.
- M6: interrupted request, retry/idempotency, offline queue/sync and original-account recovery.

| Screen | Previous audit | Files | Implemented changes | Shared impact | Preserved functionality | Remaining blocker | Manual |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Business loading | NEEDS REFINEMENT | main.dart; UI theme | Shared loading and POS theme | POS only / inherited opt-in theme | Auth/business loading gate | None for presentation | M1 |
| Employee/Owner login | NEEDS REFINEMENT | login_screen.dart; DS/forms/actions | Smaller branding, unified fields/buttons, labels and visibility tooltips | Opt-in POS presentation; Owner fallback retained | Employee ID/PIN/password, Owner switch | None for presentation | M1 M2 M5 |
| Restore/switch authorized business | NEEDS REFINEMENT | login_screen.dart; pos_shell.dart | Unified chooser/dialog styling and motion | POS only / inherited opt-in theme | Authorized context choices and pending-sale restrictions | None for presentation | M1 M5 M6 |
| Select branch and assignment error/empty states | NEEDS REFINEMENT | auth/branch_context.dart | Grouped branch rows; scroll-safe retry/empty states | POS only / inherited opt-in theme | Original branch/cart selection guards | None for presentation | M1 M5 |
| Pending-sale recovery gate | NEEDS REFINEMENT | pending_sale_provider.dart | Scroll-safe recovery panel and clear actions | POS only / inherited opt-in theme | Original request, cancellation disclosure, receipt recovery | None for presentation | M1 M3 M6 |
| POS shell/navigation | NEEDS REFINEMENT | pos_shell.dart; UI theme | Same tabs, standardized navigation and fade motion; unused landing removed | POS only / inherited opt-in theme | Role-aware tabs, lazy visited stack and context keys | None for presentation | M1 M5 |
| Home | NEEDS REDESIGN | dashboard_screen.dart; POS components | Compact scan button, grouped actions and cart footer | POS only / inherited opt-in theme | Verified scan-to-cart guards and permitted routes | None for presentation | M1 M3 M5 |
| Inventory / Product Search | NEEDS REFINEMENT | product_search_screen.dart | Back affordance when pushed, authorized prices, compact rows, standard states | POS only / inherited opt-in theme | Original search debounce, stock filters and product selection | None for presentation | M1 M2 M5 |
| Product details | NEEDS REFINEMENT | product_detail_screen.dart | Compact spacing, badges, price/error hierarchy and readable notices | POS only / inherited opt-in theme | Same price load/retry, authorized add-to-cart and edit navigation | None for presentation | M1 M3 M5 |
| Quick Add Product | NEEDS REFINEMENT | quick_add_screen.dart; DS/forms | Compact pending notice, persistent barcode label, unified fields | Opt-in POS presentation; Owner fallback retained | Same four-field pending-review creation contract | Advanced creation fields remain outside existing pending-create contract | M1 M2 M5 |
| Existing product / barcode not found sheets | NEEDS REFINEMENT | quick_add_screen.dart; scanner_screen.dart | Consistent sheet theme, safe spacing and 250ms/reduced motion | POS only / inherited opt-in theme | Existing barcode/not-found/duplicate-product choices | None for presentation | M1 M2 M4 |
| Edit product / variants / stock adjustment | NEEDS REFINEMENT | catalog_edit_screen.dart | Metadata/variant/adjustment headings, descriptive labels, multiline description | POS only / inherited opt-in theme | Existing fields, validators, grants and durable retry intents | None for presentation | M1 M2 M4 M5 |
| Stock-movement viewer | NEEDS REFINEMENT | catalog_edit_screen.dart | Themed scrollable movement dialog, uniform motion and rows | POS only / inherited opt-in theme | Actual stock audit entries and product scoping | None for presentation | M1 M4 |
| Angel Scan | NEEDS REFINEMENT | scanner_screen.dart | Scrollable overlay controls, 48px named targets, clear contrast and reduced motion | POS only / inherited opt-in theme | Camera/barcode matching, repeat-scan and Angel Scan branding only | None for presentation | M1 M4 |
| Checkout | NEEDS REFINEMENT | checkout_screen.dart | Cart remains separate; one Proceed to Payment step and standard controls | POS only / inherited opt-in theme | Cart math, price/discount grants, recovery guards and queue paths | None for presentation | M1 M2 M3 M6 |
| Confirm Payment | NEEDS REDESIGN | OPS/payment_confirmation_dialog.dart | POS-only premium summary, selected method, retained splits, tender/change and real credit request | Opt-in POS presentation; Owner fallback retained | One common validator; existing payment evidence and approval workflow | None for presentation | M1 M2 M3 M6 |
| Online Sale Completion | NEEDS REDESIGN | checkout_screen.dart; sale_completion_dialog.dart | Distinct confirmed receipt stage, breakdown, View Receipt and New Sale | POS only / inherited opt-in theme | Shown after existing submission returns; original receipt acknowledgment remains | None for presentation | M1 M3 M6 |
| Offline cash receipt | NEEDS REFINEMENT | checkout_screen.dart | Human-readable pending cash receipt and applied amount | POS only / inherited opt-in theme | Explicit Pending Sync; original request retained | None for presentation | M1 M3 M6 |
| Sales History | NEEDS REDESIGN | recent_sales_screen.dart | Aggregate removed; lazy compact list with accurate local search/method filters | POS only / inherited opt-in theme | Same authorized sales provider and original receipt records | None for presentation | M1 M3 M5 |
| Sale Details / receipt sheet | NEEDS REFINEMENT | recent_sales_screen.dart | Standard sheet, product names, wrapping individual amounts and receipt reference | POS only / inherited opt-in theme | Actual transaction/item details; no invented breakdown | None for presentation | M1 M3 |
| Operations hub | NEEDS REFINEMENT | operations_screen.dart | Compact action-row family, no separate giant action cards | POS only / inherited opt-in theme | Same permissions, adapters and destinations | None for presentation | M1 M5 |
| Stocktaking & Inventory landing / View all sessions | NEEDS REFINEMENT | Inventory adapter; OPS/inventory_operations_screen.dart | POS theme/spacing, consistent rows/labels, explicit view-only states | Opt-in POS presentation; Owner fallback retained | Existing active-session summaries, branch capability and write guards | None for presentation | M1 M4 M5 |
| Stocktake session / count / review | NEEDS REFINEMENT | OPS/inventory_operations_views.dart | Uniform count/status text, spacing and action surfaces | Opt-in POS presentation; Owner fallback retained | Versions, assignments, later-movement reconciliation and separate approval | None for presentation | M1 M4 M5 M6 |
| Inventory product picker and stock action forms | NEEDS REFINEMENT | OPS/inventory_operations_screen.dart / views.dart | POS persistent dropdowns and scrollable keyboard-aware product picker | Opt-in POS presentation; Owner fallback retained | Original selection, quantity, condition/reason validation and callbacks | None for presentation | M1 M2 M4 |
| Credit & Returns | NEEDS REFINEMENT | Credit adapter; OPS/financial_operations_screen.dart | POS palette/spacing and consistent tabs/cards/secondary sections | Opt-in POS presentation; Owner fallback retained | Role-limited summaries and existing Credit/Returns split | None for presentation | M1 M3 M5 |
| Customer Credit Details / repayment history | NEEDS REFINEMENT | OPS/financial_operations_details.dart / support.dart | Compact text roles, fields and detail/history presentation | Opt-in POS presentation; Owner fallback retained | Original selected sale, repayments, adjustments, due date and receipts | None for presentation | M1 M2 M3 |
| Credit approvals / offline financial reconciliation | NEEDS REFINEMENT | OPS/financial_operations_screen.dart | Unified request/status/reconciliation presentation | Opt-in POS presentation; Owner fallback retained | Actual approval decisions and sensitive action grants | None for presentation | M1 M3 M5 |
| Credit Limits | NEEDS REFINEMENT | OPS/financial_operations_details.dart | Compact exposure/policy presentation | Opt-in POS presentation; Owner fallback retained | Owner-only existing business/branch exposure semantics | Individual allowances unsupported; existing exposure only | M1 M3 M5 |
| Return request / inspection / refund / repayment dialogs | NEEDS REFINEMENT | OPS/financial_operations_screen.dart / support.dart | Unified themed forms, labels, validation and dialog motion | Opt-in POS presentation; Owner fallback retained | Original items/quantities, inspection, refund/debt math and evidence | None for presentation | M1 M2 M3 M5 |
| Offline Cash & Synchronization | NEEDS REFINEMENT | offline_cash_screen.dart | Consistent cached search/queue sections and real empty state | POS only / inherited opt-in theme | Original encrypted queue, signed catalog, request identity and sync | None for presentation | M1 M2 M3 M6 |
| Shared Cash Drawers / shifts / handovers | NEEDS REDESIGN | OPS/cash_shift_screen.dart | POS theme, one compact count summary, expandable shift rows with visible expected balance; standard button targets | Opt-in POS presentation; Owner fallback retained | Original registers, drawer membership, cash movements, handovers and reconciliation | None for presentation | M1 M2 M3 M5 M6 |
| More / profile summary | NEEDS REFINEMENT | pos_shell.dart; POS components | Profile/menu spacing and consolidated action rows | POS only / inherited opt-in theme | Existing role visibility, business switching and routes | None for presentation | M1 M5 M6 |
| My Settings / profile / theme | NEEDS REFINEMENT | employee_settings_screen.dart | Standard profile rows and compact appearance popup | POS only / inherited opt-in theme | System/Light/Dark persistence body unchanged | None for presentation | M1 M2 M5 |
| Change password | NEEDS REFINEMENT | employee_settings_screen.dart | Removed doubled gaps; readable loading/error states and visibility tooltips | POS only / inherited opt-in theme | Existing reauthentication/password update; no queue clearing | None for presentation | M1 M2 M5 M6 |
| Device Notifications & Recovery | NEEDS REFINEMENT | employee_settings_screen.dart | Standard retry state, compact transaction alerts and consistent surfaces | POS only / inherited opt-in theme | Local read state continues not to clear sales | None for presentation | M1 M5 M6 |
| Business Notifications | NEEDS REFINEMENT | OPS/notification_center_screen.dart | POS-only standard empty/error/retry states and theme | Opt-in POS presentation; Owner fallback retained | Existing application scope, mark-read RPC and authorized destinations | None for presentation | M1 M5 |
| Employees & permissions | NEEDS REDESIGN | OPS/employee_access_screen.dart | POS-only palette, compact typography/spacing and lists | Opt-in POS presentation; Owner fallback retained | Existing employee reads and verified-owner permissions gate | None for presentation | M1 M5 |
| Permission detail / permission-action sheet | NEEDS REDESIGN | OPS/employee_access_screen.dart | POS-only themed permission sections/sheet and motion | Opt-in POS presentation; Owner fallback retained | Same explicit permission overrides and original RPC arguments | None for presentation | M1 M2 M5 |
| Help & Safe Recovery | NEEDS REFINEMENT | pos_shell.dart; UI theme | Standard dialog styling and 200ms/reduced motion | POS only / inherited opt-in theme | Original safe recovery guidance | None for presentation | M1 M6 |
| About / licenses | NEEDS REFINEMENT | pos_shell.dart; UI theme | Themed About dialog, original build metadata and licenses access | POS only / inherited opt-in theme | Real build-version fallback and existing license flow | None for presentation | M1 |
| Sign-out / cancellation confirmations | NEEDS REFINEMENT | Home/More/recovery/shared operational dialogs | Consistent surfaces, disabled states and scoped motion | POS only / inherited opt-in theme | Original sign-out, no-money-moved confirmation and recovery safeguards | None for presentation | M1 M3 M5 M6 |
| Expenses / Expense History | Identified functional gap | expense_support_screen.dart; dashboard_screen.dart | Explicit unavailable state and explanation | POS only | No fake records or writes | Missing attributed cash-expense backend contract; entry/history not implemented | Confirm unavailable state; backend work separate |

## Modified/new source inventory

- POS/lib/main.dart
- POS/lib/src/features/auth/branch_context.dart
- POS/lib/src/features/auth/login_screen.dart
- POS/lib/src/features/inventory/catalog_edit_screen.dart
- POS/lib/src/features/inventory/inventory_operations_screen.dart
- POS/lib/src/features/inventory/product_detail_screen.dart
- POS/lib/src/features/inventory/product_search_screen.dart
- POS/lib/src/features/inventory/quick_add_screen.dart
- POS/lib/src/features/inventory/scanner_screen.dart
- POS/lib/src/features/pos/checkout_screen.dart
- POS/lib/src/features/pos/credit_returns_screen.dart
- POS/lib/src/features/pos/dashboard_screen.dart
- POS/lib/src/features/pos/employee_settings_screen.dart
- POS/lib/src/features/pos/expense_support_screen.dart (new)
- POS/lib/src/features/pos/offline_cash_screen.dart
- POS/lib/src/features/pos/operations_screen.dart
- POS/lib/src/features/pos/pending_sale_provider.dart
- POS/lib/src/features/pos/pos_shell.dart
- POS/lib/src/features/pos/recent_sales_screen.dart
- POS/lib/src/features/pos/sale_completion_dialog.dart (new)
- POS/lib/src/ui/trexven_ui.dart (new)
- POS/lib/src/ui/components/pos_components.dart (new)
- POS/lib/src/ui/theme/pos_theme.dart (new)
- DS/lib/trexven_design_system.dart
- DS/lib/src/components/actions.dart
- DS/lib/src/components/forms.dart
- DS/lib/src/theme/presentation.dart (new)
- OPS/lib/src/cash_shift_screen.dart
- OPS/lib/src/employee_access_screen.dart
- OPS/lib/src/financial_operations_details.dart
- OPS/lib/src/financial_operations_screen.dart
- OPS/lib/src/financial_operations_support.dart
- OPS/lib/src/inventory_operations_screen.dart
- OPS/lib/src/inventory_operations_views.dart
- OPS/lib/src/notification_center_screen.dart
- OPS/lib/src/payment_confirmation_dialog.dart

The companion TREXVEN_POS_UI_SOURCE_MANIFEST_20261017.json records installed SHA256 values, new files and protected unchanged source fingerprints. The small POS_UI_SHARED_* JSON files are implementation-time atomic-write deltas, not backend migrations or scripts to reapply.

## Source review actually performed

- Installed source content was compared against the prepared changes, accounting for Windows line endings. Shared writes were complete, checksum-verified atomic replacements; no temporary shared source files remain.
- Relative import/export/part references were inspected: none missing.
- Delimiter/obvious punctuation consistency and component references were reviewed. This does not replace Dart compilation.
- Existing RPC call-site source arguments in changed files compare unchanged.
- Authentication/permission providers, cart logic, product/sales repositories, all models, encrypted storage/offline/pending services, OperationsClient, the operation journal and stock-count batch logic remain byte-identical to the starting source.
- The theme-preference implementation and branch-context business logic compare unchanged.
- No backend write, migration, RLS/grant change or Edge Function deployment occurred. The only production request for this task was the read-only expense metadata inspection.

No automated tests, builds, analyzers, formatters, app/emulator launch, device tests, live checkout or live inventory/financial mutation were run. There is no claim that all screens render without overflow or that the app compiles.

## User handover

Build and run the existing POS project using your normal workflow. Verify M1–M6 with authorized fixtures/accounts, especially split cash/change, electronic evidence, credit pending/approval, confirmed receipt acknowledgment, interruptions and offline retries. Check the Owner fallback separately when consuming the updated shared packages. Runtime observations may require follow-up corrections; no production transaction should be created merely to make this source report look tested.

