# POS Products navigation and seven-day receipt history — Repair handoff

## Confirmed defects

1. The **Products** tile inside Inventory used an inline handler that only cleared the search/filter. Stocktaking opened a route, but Products never navigated.
2. The source product provider required a nonempty search term, previously making an empty catalog appear even when products existed.
3. The POS Sales History screen offered a seven-day filter, while restrictive live `public.sales` policies invoked `private.sales_history_access()` and limited ordinary POS access to the current business-local day. This blocked older receipts despite a client-side seven-day filter.
4. Production has four sales dated October 17–19, 2026, including three tied to the active manager membership. These records were not removed or changed.

## POS changes in this branch (PR #29)

- The Inventory **Products** tile now pushes `ProductSearchScreen(catalogOnly: true)` using standard Navigator; the catalog is a separate page with its own title, search, stock filters, rows, and product-detail tap navigation. Back returns to the Inventory navigation tiles.
- Stocktaking still opens its existing, authorized stocktaking workflow unchanged.
- Empty query now loads the catalog for the selected business/branch.
- POS Sales History calls `get_pos_recent_sales` with business and branch and retrieves paginated, server-authorized receipts, rather than relying on raw SELECT from `public.sales`.
- The default sales filter is seven days. Custom ranges cannot exceed the seven-day accessible window. Server business-local dates define the inclusive window.

## Companion backend change — not deployed

Owner App repository migration:
`supabase/migrations/20261022130000_pos_scoped_seven_day_sales_history.sql`

The new `public.get_pos_recent_sales` RPC checks:
- Authenticated user and active business membership, active employee, POS authority
- Business and account closure restrictions
- Business-specific timezone and last seven business-local calendar days
- Current branch membership/assignment, with no cross-business or cross-branch receipts
- The user's own sale receipts, unless an explicit `view_finance` grant authorizes branch-wide operational receipt history
- Bounded pagination, with sale-items nested into existing POS Sale models

The existing restrictive RLS remains untouched, so other applications and existing read endpoints retain their previous boundaries.

**Deployment order:** Review and explicitly approve the SQL migration, deploy it to Supabase, then merge/release PR #29. PR #29 must not be released before the RPC is available, because its Sales History route depends on the new endpoint.

## Remaining verification

No Flutter build or runtime tests were run. Device verification required for Products navigation, Back, catalog loading/filtering, product details, branch switching, seven-day receipts, and cross-employee/branch isolation. Backend RPC must be verified under a real authenticated manager and a non-permitted user after approval.
