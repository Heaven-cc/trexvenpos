# TREXVEN POS UI audit — 17 October 2026

Status: AUDIT ONLY. No application implementation has started.

The current user instruction, “only for the pos audit first before implement,” governs this stage. The attached implementation brief was read as the target specification, not as permission to skip the audit stage. The latest screenshot, Screenshot 2026-10-17 062935.png, is the visual reference.

## Scope and evidence

- Enumerated all 42 Dart files under this POS project's lib directory and traced the active entry points, role-aware tabs, pushed pages, dialogs, sheets, recovery gates and shared views used by POS.
- Inspected the existing theme, forms, actions and surfaces in trexven_design_system, and POS-reachable inventory, financial, payment, cash drawer, notification and employee-access views in trexven_operations. These packages were read only.
- Reviewed POS providers/repository connections where needed to establish what the UI actually displays; no backend calls or production access were used for this audit.
- Source inspection only. No Flutter/Dart analyzer, formatter, tests, builds, dependency installation, app launch, emulator, screenshot generation or business transactions.
- The supplied picture is a design reference, not evidence of the current running app. No rendered-screen compliance or device performance is claimed.

Evidence paths below use:
- POS: C:/Users/USER/AndroidStudioProjects/trexvenpos/
- DS: C:/Users/USER/AndroidStudioProjects/Trexven/packages/trexven_design_system/lib/src/
- OPS: C:/Users/USER/AndroidStudioProjects/Trexven/packages/trexven_operations/lib/src/

## Audit result

The app has a useful existing design-system foundation. This should be extended for POS rather than replaced wholesale. Local POS screens already use theme colors extensively, Material icons and shared text controls. The main sources of inconsistency are older shared operational screens, duplicated screen-level layout styles, oversized action/transaction presentation, and missing or incomplete flows in the new brief.

No complete screen is certified COMPLIANT against all new requirements at this source-only stage. The table distinguishes screens whose structure should be retained and refined from those needing a larger redesign. Missing features are recorded separately instead of being described as implemented screens.

### Highest-priority findings

| ID | Priority | Finding and concrete evidence | Required POS outcome |
| --- | --- | --- | --- |
| A01 | High | POS consumes the same DS and operations packages as Owner. POS pubspec.yaml:31–35; lib/main.dart:48–51; payment_confirmation_dialog.dart is only an export. | Establish POS-only presentation ownership before editing shared defaults. A shared package edit can affect Owner even when initiated from POS. |
| A02 | High | Confirm Payment hardcodes a light palette, background and individual input styles. OPS/payment_confirmation_dialog.dart:25–29, 102–137, 244. | Theme-aware POS payment UI with a restrained premium summary; legible disabled, focus, validation and keyboard states. |
| A03 | High | All payment method forms are rendered together. Credit checkbox is available whenever online/allowCredit, rather than being enabled only for a positive unpaid balance. There is no customer selection/debt/available-limit panel. OPS/payment_confirmation_dialog.dart:409–509. | Expand the selected method only while retaining entered split-payment lines. Gate the credit request by the actual unpaid balance and existing permissions; show only real supported credit information. |
| A04 | High | Sales History always renders a recent-sales aggregate. Its provider reads authorized business/branch sales, not a cashier-only list. POS/recent_sales_screen.dart:105, 127–184; sales_provider.dart:15–28; sales_repository.dart:162–184. | Remove employee-facing aggregate performance from presentation while preserving permitted transaction and receipt access. This audit does not change underlying read permissions. |
| A05 | High | Home Expenses is “Integration pending” and only opens a snackbar. No POS expense entry or expense-history route/repository was found. POS/dashboard_screen.dart:151–156. | Treat Expenses/History as a real functional gap, not a recoloring exercise. Confirm existing supported expense contracts before implementing cash-only, server-timestamped, employee/branch-attributed UI. No invented RPCs or backdating controls. |
| A06 | High | Cash Drawers and Employee Access/permission details retain fixed light surfaces and navy text. OPS/cash_shift_screen.dart:354–365; employee_access_screen.dart:8–19, 117–139, 608–610, 694–725. | Theme-aware POS presentations, compact operational rows, consistent forms and readable statuses. Preserve drawer, handover and permission rules exactly. |
| A07 | Medium | Shared fields already append a 16px bottom gap, while Login and Change Password add another 16px. DS/forms.dart:48–73, 128; POS/login_screen.dart:178–198; employee_settings_screen.dart:438–475. | One form spacing owner. Target 12px field-to-field separation, allowing label/help/error space to grow. |
| A08 | Medium | TrexvenInputDecoration stores its label in fieldLabel, not the normal InputDecoration.labelText. Raw inventory condition dropdown uses this decoration without the external-label wrapper. Quick Add barcode decoration.copyWith also risks losing the specialized label and falling back to its hint. DS/forms.dart:15–27, 77–87; OPS/inventory_operations_screen.dart:304–306; POS/quick_add_screen.dart:515–538. | Use the standard dropdown/field frame or explicit persistent labels in the POS presentation. Preserve validators and controllers. Verify label state after copying decorations. |
| A09 | Medium | Product search has no visible selling price in its rows; its custom header also lacks a back button when the same screen is pushed from Home. POS/product_search_screen.dart:77–110, 324–373. | Context-aware tab/pushed header, plus authorized price presentation using existing permitted pricing reads. Preserve inventory-only employee access and pending-price states. |
| A10 | Medium | Scanner controls are 46×46 with no tooltip/explicit semantic label; overlay copy uses outlineVariant, which becomes a dark border color in dark mode. Continuous scan animation repeats at 1800ms with no reduced-motion branch. POS/scanner_screen.dart:49–57, 480–482, 571–590. | Keep the camera-specific dark overlay and Angel Scan label; use readable overlay roles, at least 48px targets, named controls, and reduced-motion handling. Camera recognition behavior is unchanged. |
| A11 | Medium | Receipt/completion UI is a generic dialog with receipt ID, one method label, items and total; offline receipt prominently lists product IDs. POS/checkout_screen.dart:228–245, 274–301. | A distinct completion presentation after backend confirmation, real payment/credit breakdown where returned, receipt access and New Sale action. Keep offline receipts explicitly Pending Sync. |
| A12 | Medium | Repeated custom empty/error/loading blocks coexist with existing shared states; some error/recovery columns are centered without scrolling. POS/recent_sales_screen.dart:89, 310–470; pending_sale_provider.dart:237–291; branch_context.dart:105–146. | Standard POS states with consistent actions and small-screen/text-scale-safe scrolling. Recovery warnings must remain visible. |

## Current tokens compared with the requested standard

| Element | Current source | POS target |
| --- | --- | --- |
| Theme modes | System/Light/Dark with persisted preference already present | Retain the existing preference behavior |
| Main blue | #2563EB light; #8EB5FF dark primary | #326BF3 action brand; #91B5FF soft accent with deliberate text contrast |
| Dark background / surface | #0F172A / #1E293B | #0C1426 / #18243D; elevated #22314D |
| Light background | #F5F7FC | Already matches |
| Light text / secondary | #0F172A / #526179 | #17233E / #64748B |
| Dark text / secondary | #F1F5F9 / #B0BED0 | #F8FAFC / #9EAECA |
| Border | #CBD5E1 light; #475569 dark | #DCE3EF light; #344460 dark |
| Font | Roboto; google_fonts dependency exists but no Inter use was found | Retain Roboto as the allowed existing equivalent; no font dependency needed |
| Titles | Global title token 24; display 30; Home greeting 25 | Pages 20–22; sections 16–18; financial amounts 20–28 |
| Forms / sections | fieldGap 16; sectionGap 24; local extra gaps | Fields 12; sections 16–20; shared 4px scale |
| Cards | Common radius 16 and padding 16 already useful | Retain 14–18 radius, 12–16 padding; reduce nested/standalone action cards |
| Buttons / inputs | Shared field/button radius 14; some screen buttons use card radius 16; payment uses 11 | Buttons 12–14, inputs consistent 12–14; one implementation per family |
| Inputs | Shared frame minHeight 48; no measured 48–52 guarantee for every configuration | 48–52 at normal scale for single-line controls; allow growth for text scaling, help/errors and multiline content |
| Sheets | Shared top radius 20; Sale Details overrides to 28 | Consistent 20–24 and keyboard/system-inset handling |
| Motion | Local 180ms controls; shared pressable 100ms; default route/dialog transitions | Central 150/200/250ms tokens and consistent curves; respect reduced motion |

Source: DS/theme/tokens.dart and DS/theme/trexven_theme.dart. Local colors alone are not the primary problem: a source scan found only one hexadecimal Color constructor in POS lib (a checkout shadow), but substantial fixed palettes remain in its imported operational screens. Those imported screens must be included in POS acceptance checks.

The source scan also found 20 TrexvenTextField/TrexvenTextFormField call sites, zero raw editable-field declarations in local POS lib, 13 showDialog call sites, three showModalBottomSheet call sites and 11 literal font-size sites. These are declaration counts, not runtime widget or screen counts; loops can create multiple fields. They exclude imported package code.

## Screen and route inventory

NEEDS REFINEMENT means retain the useful layout/workflow and standardize identified details. NEEDS REDESIGN means the presentation needs a larger structural update. These are static findings; runtime accessibility/overflow still requires manual verification.

| Screen / user-facing flow | Current entry point / implementation | Classification | Specific disposition |
| --- | --- | --- | --- |
| Business loading | POS/lib/main.dart:57 | NEEDS REFINEMENT | Use the standard loading state; remove unique 28/26 padding. |
| Employee/Owner login | POS/login_screen.dart | NEEDS REFINEMENT | Keep Employee ID/PIN/password and Owner switch; reduce brand/form gaps, duplicate field spacing and 16px button radius. |
| Restore/switch authorized business | Login context list; POS/pos_shell.dart:411–474 | NEEDS REFINEMENT | Keep authorized choices and context checks; unify chooser/dialog/list styles. |
| Select branch and assignment error/empty states | POS/auth/branch_context.dart:86 | NEEDS REFINEMENT | Group compact rows; scroll-safe states and standard header. Preserve cart/branch safeguards. |
| Pending-sale recovery gate | POS/pending_sale_provider.dart:237 | NEEDS REFINEMENT | Structured readable warning/actions, scroll-safe layout and explicit in-progress state. Keep original request recovery. |
| POS shell/navigation | POS/pos_shell.dart:22–76 | NEEDS REFINEMENT | Preserve role-aware Home / Inventory / More, lazy visited stack and context keys; unify header, navigation metrics and motion. |
| Home | POS/dashboard_screen.dart | NEEDS REDESIGN | Compact main scan action, tighter quick actions, usable cart footer, real expense status; no business performance banner. |
| Inventory / Product Search | POS/product_search_screen.dart | NEEDS REFINEMENT | Keep grouped 12px rows, images, stock filters and debounce; refine title, price access, pushed-page back control and shared states. |
| Product details | POS/product_detail_screen.dart | NEEDS REFINEMENT | Keep compact 72px image/header and selected-product retry; reduce vertical card stacking, unify badges and information rows. |
| Quick Add Product | POS/quick_add_screen.dart | NEEDS REFINEMENT | Shorter pending notice and grouped form; fix label-copy case. Keep pending-review product creation. |
| Existing product / barcode not found sheets | Quick Add and POS/scanner_screen.dart:153 | NEEDS REFINEMENT | One sheet style, smaller status illustration, clear existing/quick-add actions and safe insets. |
| Edit product / variants / stock adjustment | POS/catalog_edit_screen.dart | NEEDS REFINEMENT | Group metadata, pricing, variants and audited adjustment sections; readable labels; retain supported fields, grants and retry intents. |
| Stock-movement viewer | POS/catalog_edit_screen.dart:240 | NEEDS REFINEMENT | Standard scrollable details dialog and human-readable movement rows; retain real audit entries. |
| Angel Scan | POS/scanner_screen.dart | NEEDS REFINEMENT | Retain camera framing and barcode workflow; overlay contrast, semantics, touch targets, small-height and reduced-motion handling. |
| Checkout | POS/checkout_screen.dart | NEEDS REFINEMENT | Keep cart, prices, discount grants, quantity controls and responsive footer. Tighten summary; make Proceed to Payment hierarchy clear and avoid duplicated method selection across steps. |
| Confirm Payment | POS export → OPS/payment_confirmation_dialog.dart | NEEDS REDESIGN | Theme-aware premium summary, selected-method expansion, retained splits, amount shortcuts/change display, real credit request/status UI. |
| Online Sale Completion | POS/checkout_screen.dart:274 | NEEDS REDESIGN | Dedicated completion presentation with real receipt/payment details; backend-confirmed finalization remains the prerequisite. |
| Offline cash receipt | POS/checkout_screen.dart:228 | NEEDS REFINEMENT | Human-readable receipt and pending status; technical IDs secondary/selectable for support. Do not display as finalized online. |
| Sales History | POS/recent_sales_screen.dart | NEEDS REDESIGN | Remove employee aggregate, compact transaction rows, scalable state layout; audit missing search/filter controls against supported records. |
| Sale Details / receipt sheet | POS/recent_sales_screen.dart:473 | NEEDS REFINEMENT | Standard sheet radius, readable product names and payment details, wrapping large amounts instead of rigid trailing columns. |
| Operations hub | POS/operations_screen.dart | NEEDS REFINEMENT | Replace individual bordered action cards with compact grouped operation rows; preserve permission predicates and destinations. |
| Stocktaking & Inventory landing / View all sessions | POS inventory adapter → OPS/inventory_operations_screen.dart | NEEDS REFINEMENT | Keep current compact stock summary, Start stocktake, grouped management rows and sessions preview; consolidate spacing, statuses and form labels. |
| Stocktake session / count / review | OPS/inventory_operations_views.dart:5 | NEEDS REFINEMENT | Keep saved versions, assignment guards, barcode/bulk entry and separate approval; standardize count/status rows and action grouping. |
| Inventory product picker and stock action forms | OPS/inventory_operations_views.dart:316; screen fields() | NEEDS REFINEMENT | Use standard search, dropdown labels and keyboard-aware sheet sizing. Keep quantity/condition/reason validation. |
| Credit & Returns | POS credit adapter → OPS/financial_operations_screen.dart | NEEDS REFINEMENT | Preserve existing Credit/Returns split, restricted employee summaries and secondary approvals/recovery; consolidate cards, tabs, badges and states. |
| Customer Credit Details / repayment history | OPS/financial_operations_details.dart:4 | NEEDS REFINEMENT | Retain selected credit sale, original/repaid/return-adjusted amounts and Record repayment; tighten hierarchy and component reuse. |
| Credit approvals / offline financial reconciliation | OPS/financial_operations_screen.dart:1123 | NEEDS REFINEMENT | Retain secondary sections, actual status and permission-gated actions; compact request rows and clear failures. |
| Credit Limits | OPS/financial_operations_details.dart:358 | NEEDS REFINEMENT | Owner session only; keep real business/branch exposure semantics. Do not label them individual customer allowances. |
| Return request / inspection / refund / repayment dialogs | OPS financial screen and support files | NEEDS REFINEMENT | Preserve original-item quantities, separate inspection/approval, debt-versus-refund math and evidence; standardize form/dialog family. |
| Offline Cash & Synchronization | POS/offline_cash_screen.dart | NEEDS REFINEMENT | Separate catalog, queue and recovery sections; monetary formatting and standard error/empty states; retain encrypted queue identity. |
| Shared Cash Drawers / shifts / handovers | OPS/cash_shift_screen.dart | NEEDS REDESIGN | Replace fixed light palette and repeated cards with compact, theme-aware operations, shift rows and consistent dialogs. |
| More / profile summary | POS/pos_shell.dart:301 | NEEDS REFINEMENT | Keep grouped menu/navigation and role visibility; consolidate bespoke menu/settings row variants and profile block spacing. |
| My Settings / profile / theme | POS/employee_settings_screen.dart:44 | NEEDS REFINEMENT | Retain current identity fields and saved System/Light/Dark; responsive appearance chooser and standard settings rows. |
| Change password | POS/employee_settings_screen.dart:347 | NEEDS REFINEMENT | Remove doubled gaps, add consistent visibility semantics/loading/error presentation; keep reauthentication and queue retention behavior. |
| Device Notifications & Recovery | POS/employee_settings_screen.dart:562 | NEEDS REFINEMENT | Compact notices and transaction rows, shared states; marking read must continue to leave transactions intact. |
| Business Notifications | OPS/notification_center_screen.dart | NEEDS REFINEMENT | Standard empty/error/retry presentation and readable read/unread rows; preserve notification scope and authorized navigation. |
| Employees & permissions | OPS/employee_access_screen.dart:22 | NEEDS REDESIGN | Theme-aware compact team list and header; remove fixed light surfaces and unique status styles. |
| Permission detail / permission-action sheet | OPS/employee_access_screen.dart:375, 608 | NEEDS REDESIGN | Theme-aware grouped permission controls, standard sheet/state components. Preserve verified-owner gate and explicit grants. |
| Help & Safe Recovery | POS/pos_shell.dart:586 | NEEDS REFINEMENT | Standard accessible dialog/close action; retain recovery guidance. |
| About / licenses | POS/pos_shell.dart:601 | NEEDS REFINEMENT | Keep existing system flow and real build-version fallback; apply POS dialog styling where available. |
| Sign-out / cancellation confirmations | Home, More, pending recovery and operations | NEEDS REFINEMENT | One confirmation family with explicit destructive/loading behavior; retain no-money-moved and recovery disclosures. |

### Missing or limited features in the brief

| Requested area | Current source finding | Constraint for implementation |
| --- | --- | --- |
| Expense entry and Expense History | Placeholder only; no wired POS screens | Requires supported existing backend contracts and a POS presenter. No schema/RPC changes authorized by this UI task. |
| Per-customer credit limits / available customer allowance | Current shared credit view explicitly models business/branch exposure, not an individual allowance | Do not manufacture a customer limit, approval switch or available-credit number from exposure totals. |
| Checkout customer selection and existing-debt summary | Existing PaymentDraft captures debtor name/contact/due date; no lookup/debt summary in the dialog | Use only permitted existing reads and actual record semantics; preserve the exact saved approval payload/recovery. |
| Cash tendered / automatic change | Current payment validator rejects recorded payments exceeding the sale total | If adding tender/change presentation, separate tendered cash from the settled payment allocation. Do not change settlement math or treat change as revenue. |
| Full Add Product form from the brief | Quick Add currently creates a pending product from name/barcode/part number/brand; Edit Product has more metadata/unit/image URL/variant controls and authorized price/adjustment fields | Keep quick-add review workflow; do not silently grant stock/pricing authority or assume image upload exists. |
| Sales search/filter UI | No search field or filter controls in current RecentSalesScreen | Add only frontend controls over authorized data; retain complete/accurate result and receipt semantics. |

## Existing reusable components and consolidation map

Do not build 25 unrelated wrappers simply to satisfy names. Prefer existing implementations and centralized theme styling when behavior is identical.

| Requested family | Existing foundation | POS audit disposition |
| --- | --- | --- |
| Button | TrexvenButton; Material filled/outlined/text themes; TrexvenPressable | Consolidate variants and loading/disabled behavior; do not keep per-screen styleFrom overrides. |
| Text field | TrexvenTextField, TrexvenTextFormField, external labels | Reuse, with POS spacing/label consistency; do not regress validation. |
| Amount field | Shared moneyCents validation; otherwise ordinary text fields | Add a presentation adapter over existing parsing; preserve cursor/raw input and validation. |
| Search field | TrexvenFieldVariant.search | Reuse one search family across product/customer/session lists. |
| Dropdown | TrexvenDropdown | Reuse rather than raw dropdown plus specialized decoration. |
| Checkbox / switch | Material controls with partial local overrides | One POS theme and consistent label/disabled/error states; wrappers only if useful. |
| Card | TrexvenCard, TrexvenTapCard; bespoke credit/inventory cards | Reuse compact surface rules; preserve premium surfaces as exceptions. |
| Glass card | No standardized exported glass component found | One POS premium summary component; no blur on scrolling lists or critical information. |
| App bar | Global AppBarTheme; repeated subtitle headers | Consolidate POS header conventions and context-aware back behavior. |
| Bottom sheet / dialog | TrexvenBottomSheet, TrexvenDialog and global themes | Consolidate presentation, safe areas, keyboard, close/confirm semantics and transitions. |
| Status badge | Several custom badges/pills in products, credit, stock and employees | One semantic status family with text and appropriate contrast. |
| Transaction row / list tile | TrexvenProductRow, TrexvenSettingsTile plus many private row variants | Reuse consistent row layout/amount wrapping without changing record semantics. |
| Filter chip / segmented control | Material ChoiceChip; custom credit tabs | Central POS styles and accessible selected states. |
| Date picker | TrexvenDateField and themed Material picker | Reuse where legitimate (credit due date); no editable/backdated expense timestamp. |
| Empty / loading / error | TrexvenEmptyState, TrexvenLoading, TrexvenErrorState | Reuse with scroll-safe screen containers; no blanket raw exception text. |
| Navigation bar | Existing NavigationBar and role-based PosShell | Preserve architecture, standardize metrics/icons/motion. |
| Confirmation panel | Ad hoc confirmation dialogs and payment notices | One family with real progress/disabled states; critical warnings remain explicit. |
| Payment-method selector | Local checkout selector and shared payment forms | One POS selector/presentation; retain split amounts when changing selected method. |
| Credit-approval section | Payment checkbox plus real repository approval request/status handling | Surface actual request lifecycle, no fake approved/verified states. |

## Motion, icons and responsiveness

- Material Icons are already the active family. cupertino_icons is a dependency, but no CupertinoIcons or FontAwesome usage was found in POS lib. Consolidate outlined/rounded variants and sizes, rather than installing an icon package.
- Shared TrexvenPressable hardcodes 100ms; local checkout/search use 180ms. MaterialPageRoute and default dialogs/sheets do not have a centralized TREXVEN motion specification.
- The scanner's 1800ms repeating guide is a scanning affordance, not a slow page transition. It should honor reduced motion; changing it blindly to 200ms would be inappropriate.
- Existing text-scale adaptations in Checkout, the cart bar, financial metric pair and inventory summary are useful and should be retained.
- Specific static risk sites: scanner Column/Spacer layout on short screens; 46px camera buttons; fixed width/height quantity text; three payment options in a row; 500px sales empty-state box; unbounded financial trailing columns; 70%-height product picker plus keyboard padding; multi-line subtitle app bars at default toolbar height.
- These are code-level risks, not measured device failures. Do not certify input height, contrast across all states, no overflow, keyboard visibility or blur performance without user runtime validation.

## POS-only implementation boundaries

The existing root theme is shared and several target screens are actually implemented outside the POS checkout. Changing their shared defaults would affect Owner. Merely wrapping a fixed-light screen with a new Theme will not override its explicit white backgrounds/navy TextStyles.

Recommended POS-owned structure:

- lib/src/ui/trexven_ui.dart — public POS UI barrel.
- lib/src/ui/theme/ — POS palette, text roles, 4px spacing, radii, elevation and motion tokens; light/dark ThemeData.
- lib/src/ui/components/ — reuse/adapt existing controls and states; add only missing POS-specific presentation families.
- Existing lib/src/features/... files remain the navigation/state integration points.

Do not copy the Owner project or fork financial/inventory controllers. Keep OperationsClient, sale/approval/queue providers, request IDs, recovery receipts and existing backend argument maps authoritative. The shared operational pages require an explicit POS-specific presentation boundary; any optional shared extension must preserve Owner defaults and must be separately scoped before touching those shared files. For this audit, every shared file remains read only.

No backend migration, RLS/grant change, Edge Function deployment, entitlement change, permission expansion, business activation or financial/stock mutation belongs to this UI work.

## Recommended implementation order

1. Freeze the existing POS workflow and route inventory. Establish a POS-only theme/presentation boundary and reuse the available Roboto/Material foundation.
2. Add POS tokens and standardize fields, buttons, dialogs, sheets and states. Resolve duplicate gaps and label handling before migrating screens.
3. Refine shell/navigation, Login, Home, Search, Product Details, Quick Add and Edit Product.
4. Redesign Confirm Payment and Completion while keeping Checkout separate. Preserve exact payment allocations, credit authorization and recovery.
5. Refine Sales History and receipts; remove employee performance totals. Wire Expenses only after verifying its real existing frontend/backend contract.
6. Refine stocktaking/credit and isolate the fixed-light cash/employee presentations without modifying Owner behavior.
7. Migrate settings, notifications, help, recovery and all secondary modal flows. Recheck every table row for consistent light/dark presentation.

This is a proposed sequence, not completed implementation.

## Manual acceptance after implementation

The user will perform runtime testing. Required coverage:

- Both themes and system theme switching; ordinary phone widths including 320px; increased text scaling; keyboard open; navigation/system insets.
- Every editable field: label, typed text, hint, focus, disabled state, validation/help text, currency/quantity input and cursor position.
- Long names, large and fractional amounts, missing images, pending prices, long transaction lists and empty/error/loading states.
- Role-aware tabs/actions, original branch/context changes, existing Employee ID/PIN/password authentication and sensitive manager grants.
- Checkout → Confirm Payment → Completion remain distinct. Split amounts survive switching methods. Credit is unpaid debt, not collected money; approval and electronic verification remain genuine.
- Receipt finalization, interrupted checkout, original-request retry, offline pending sync, no duplicate collection, drawer assignment and queues retained.
- Existing count/approval/reconciliation, repayment, return/refund and employee-permission workflows remain intact.
- Screen readers and named icon controls, suitable touch targets and reduced-motion preferences.

## Deliverable and change log

Created only: .artifacts/TREXVEN_POS_UI_AUDIT_20261017.md.

No app source, shared package source, dependencies, backend or other TREXVEN application was modified. No build, analyzer or automated test was run. No redesign is reported as implemented or runtime-verified.

