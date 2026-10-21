# POS Inventory and Seven-Day Sales History — Repair Handoff

## Findings verified against live Supabase (read-only)

- `public.products` has 1 product. POS `ProductSearchNotifier.search()` explicitly returned an empty list when the search query was empty; `ProductSearchScreen` also bypassed results whenever the query was empty. The Inventory **Products** tab therefore appeared inaccessible without a typed search.
- `public.sales` contains 4 transactions dated October 17–19, 2026. Thus records exist within the latest 7-day calendar window as of October 22, 2026.
- POS Sales History currently calls `getAuthorizedBusinessSales()` and shows records filtered in Flutter. Before this repair the repository requested all accessible history rather than a 7-day bounded query.
- `private.sales_history_access(business, sold_at)` currently grants non-owner POS access through a same-business-day check unless they have `view_finance`. However, `public.sales` also has other permissive SELECT policies. A same-day limitation in this helper is **not proof** of a complete denial, because permissive policies are OR-combined. Effective permissions and employee context must be verified before any policy change.
- The product projection columns are granted individually to `authenticated` except sensitive `cost_price`; the absence of blanket table SELECT is intentional and is not a catalog read bug.

## Implemented in Flutter

1. Empty search now fetches the first catalog page in the active business and selected branch. The display now renders results immediately, and refresh works without a query.
2. No-products messaging reflects an empty catalog rather than prompting for search.
3. Sales repository accepts an optional server-side `created_at` lower bound and POS recent-sales provider supplies the beginning of the last seven local calendar days. Existing business/branch filters and RLS remain in effect. No sales amounts are added to POS Home.

## Backend action requiring separate authorization

If seven-day sales are still invisible to an authorized employee, inspect the effective `sales` and `sale_items` SELECT grants, all permissive RLS policies, `private.sales_history_access`, `private.branch_record_access`, and the actual logged-in employee-to-business membership mapping. Do not blindly change `private.sales_history_access` from one to seven days: it may expose all branch history to ordinary staff because the helper currently lacks employee identity and `sales` has permissive legacy policies.

Prepare a forward-only, tested RLS design that provides:
- Employees: their own authorized receipts from the last seven **business-local** days, with business and branch scope.
- Managers: branch history only if explicitly granted.
- Owners: full history only in the Owner App, not overall POS financial totals.
- No cost/profit disclosure, cross-branch or cross-business access, or unauthorized list/aggregate leakage.
- Correct behavior when `created_at` and `sold_at` differ, including timezone/DST and midnight boundaries.
- Existence and matching of `sales.employee_id` to the active membership, and `sale_items` visibility through the same authorized parent sale.

Review and approve database changes before deployment. Do not silently grant `view_finance` or `view_inventory` to resolve an issue.

## Device verification needed

- In the POS Inventory tab with an active manager and a selected branch, confirm Products immediately lists the existing product and opens its details.
- Verify blank search, typed search, clear search, branch switching, retry, stock quantities, and price visibility.
- In Sales History, select 7 days; verify Oct 17–19 receipts visible if authorized; no current-day-only truncation, no cross-branch receipts, and no business-wide financial totals.
- No local Flutter build or runtime tests were performed.
