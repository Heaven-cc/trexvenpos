# POS Inventory Products and date-filtered Sales History — Handoff

## Merged separately
Products navigation and empty-search catalog loading were isolated into [POS PR #30](https://github.com/Heaven-cc/trexvenpos/pull/30), merged into `main`. Its dedicated route opens when the Products tile is tapped; Stocktaking remains a separate workflow.

## Pending Sales History work (this PR #29)
Supabase production has four sales from October 17–19, 2026. The current restrictive raw-table RLS limits ordinary POS sales reads to the same business-local day. Filtering a raw list on the client cannot reliably show Yesterday or 7 Days.

The frontend now calls the prepared `public.get_pos_recent_sales` RPC using the selected filter:
- Today: sales from the current **business-local** date.
- Yesterday: sales from the previous **business-local** date.
- 7 Days: the current day plus the previous six business-local dates.
- Custom: any selected start/end calendar dates (not limited to seven days).
- All: all authorized available sales with server-side pagination.

The backend does the authoritative timezone conversion and date filtering. Client filtering is limited to receipt/product text and payment type. The provider key includes filter and custom dates so changing a chip issues a new query.

## Backend dependency — not deployed
[Owner PR #5](https://github.com/Heaven-cc/Trexven/pull/5) prepares a forward-only SQL migration in `supabase/migrations/20261022130000_pos_scoped_seven_day_sales_history.sql`. The endpoint accepts `p_filter`, `p_start_date`, and `p_end_date`, checks the authenticated user, active employee/business membership, business-local dates, current branch assignment, and `pos_access`. Ordinary staff see only their own receipts; `view_finance` enables authorized branch-wide receipts, never cross-business or cross-branch.

The endpoint is SECURITY DEFINER and has an authenticated-only EXECUTE grant, with all membership/branch/role checks internal. Existing table RLS policies are not changed.

**Deployment order:** Review and approve the companion migration, deploy it, verify under authorized and unauthorized employee sessions, then merge/release POS PR #29. Merging this PR without deploying the RPC will break Sales History because the frontend expects the new endpoint.

No Flutter builds/tests or production mutations were performed.
