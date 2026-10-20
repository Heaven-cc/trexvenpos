# TREXVEN POS behavior implementation — 19 October 2026

## Scope and evidence

Base Owner master: 5215fd7e0d015da5d29cc1ce0ec4b733d92d352c.
Base POS main: 8a4c92141bada52f759e1423a8dbecb2e0152e37.
POS source PR: https://github.com/Heaven-cc/trexvenpos/pull/26
Backend source PR: https://github.com/Heaven-cc/Trexven/pull/1

The pushed POS commit is titled "Update POS dashboard and compatibility fixes", dated 19 October 2026 at 20:32:39 UTC. It is the same head visible in the preceding backend task. Its scanner icon replacement remains untouched; BranchContext's compatible optional defaults remain, with the POS call sites now explicitly enforcing role and retained-request checks. The approved dashboard layout remains.

This report distinguishes implemented source/contracts from runtime evidence. No Flutter build, analyzer, app test suite, device test, dependency download, clone, backup or local source artifact was created. Source/import inspection and read-only production catalog checks were performed. No sale, expense, refund, lease, transfer or device activity was fabricated to test behavior.

## Workflow checklist

| Workflow | Implemented change / existing contract retained | Still requires device validation |
|---|---|---|
| Checkout and recovery | Keep durable request guard; check branch before payment; restrict drawer picker to current branch; validate identity/branch again on confirmation; bound submission to 30 seconds; validate returned receipt context/amount; route unconfirmed checkout back to the global recovery gate; keep storage failures locked for recovery. | Interrupt payment/submission/receipt acknowledgement, then restart and recover without another payment. |
| Expenses | Existing approved form now calls record_pos_expense, uses server business date, supports an explicitly selected joined drawer or no drawer, prevents concurrent submissions, retains original request through failures, and reads own/explicit manager branch history with cursor pagination. No POS raw expense reads/writes. | Permission denial, timezone midnight, optional drawer, save timeout/replay and pagination. |
| Credit/repayments/refunds/returns | Existing exact-sale credit approval, partial payment/repayment, overdue account and return inspection flows remain. Drawer choices are branch scoped. POS approval uses new approve_pos_return, preserving debt-first/refund limits while offering optional sellable restocking with a required no-restock reason. Owner keeps approve_trexven_return. | Partial credit, approval/rejection, repayment and reversal, partial returns, debt reduction and both restock choices. |
| Inventory/stocktaking/branches | Existing role/price/status restrictions and branch stocktake RPCs retained. Search and scan-to-cart use available branch stock instead of catalog totals; stale search results are ignored after disposal. Stocktaking accepts recognized product IDs when no barcode exists. New branch transfer page dispatches from selected branch and records partial physical receipts separately. | Sell during stocktake; count/recount/approve; source dispatch/destination receipt; wrong-branch access; insufficient stock. |
| Offline cash/synchronization | Existing signed nonbranch scope remains. New branch scope/sync endpoints sign the exact branch/catalog, enforce current authorization during sync, preserve actual receipts and stock discrepancies, and support late drawer review. Native client checks device/clock/24-hour scope before cash confirmation; confirmed-at time remains with the intent. Automatic sync runs on reconnect/resume and periodically; successful receipts stay encrypted until acknowledged. | Airplane mode, clock rollback, expiry, restart, late sync, duplicate retries, original account, branch stock shortfall and receipt acknowledgement. |
| Employee permissions/access | Explicit expense/history/transfer grants remain required. No automatic grants or feature-flag changes. Branch/business switches check retained operations and carts. Cart is scoped to identity/business. New server-side device activity records authenticated member/device/branch/server time without revoking concurrent devices or granting access. | Revoke permissions/branch assignment, switch accounts/business, use multiple devices, inspect last-seen activity. |
| Notifications/history | New POS-only feed supports branch inventory/cash/credit/return and scoped employee updates, read/unread and visible-route polling. Notification actions route to authorized workflows; own access changes open profile. Own confirmed operational history is paginated and includes retained operation recovery. Sales receipts remain in Sales History. | Read/unread, wrong account/branch, permission revocation, opening routes, paging and original request recovery. |
| Authentication/session restoration | Initial restoration shows a loading gate; a retained session with failed access verification gets a retry/business-selection page instead of the login form. Business/branch preferences are hints validated against current server authorization. Auth context is retained during refresh; navigation resets when account/business context changes. Offline fallback remains signed-scope limited. | Cold launch, token refresh, expired session, network failure, revoked access, business/branch restoration and logout. |
| UI density | Dashboard action minimum height 116→100; scan padding 18→14; scan icon 36→28; theme headlineSmall 22→20. Approved colors, navigation, component structure and 48px controls retained; text scaling is not disabled. | Small Android screen and large accessibility text. |

## Production deployment

Project: ufehcfrlygqvminfjumf.

- Previously deployed: 20261019205934_pos_expenses_backend.
- Deployed this phase: 20261019212607_pos_workflow_contracts.
- Deployed this phase: 20261019212715_pos_notification_review_events.
- Deployed this phase: 20261019212931_pos_device_activity.

New public endpoints: approve_pos_return; issue_pos_branch_offline_scope; sync_pos_branch_offline_cash; get_pos_notifications; mark_pos_notification_read; get_pos_operation_history; register_pos_device.

New public endpoints use SECURITY DEFINER with empty search_path, explicit authenticated execution and anonymous execution revoked. Authorization comes from current memberships/permissions/branch checks, never preference values or user-editable metadata. The notification helper is private and direct anonymous/authenticated execution is revoked. pos_device_activity has RLS; authenticated clients have SELECT only under its own-or-owner policy, with writes through the authorized registration RPC.

The initial workflow migration attempt was rejected for missing function-definition separators. Catalog inspection confirmed zero new functions and zero migration entries after rejection. SQL was corrected before successful application; this failed attempt did not deploy partial contracts.

Read-only before/after counts: sales 4/4; expenses 0/0; returns 0/0; offline leases 0/0; cash_events 0/0; stock_transfers 0/0. The new device activity table has 0 rows at postflight.

Existing Owner-compatible definitions were hashed before/after and unchanged: approve_trexven_return, issue_trexven_offline_scope, sync_trexven_offline_cash, get_trexven_notifications, mark_trexven_notification_read, get_trexven_financial_summary, record_pos_expense and get_pos_expenses. No Owner Flutter file or existing shared backend function was rewritten.

Existing stocktake approval code applies counted-minus-expected deltas to current stock. It does not replace later sales movements with the old count snapshot. This was inspected in production, not exercised with a fabricated stocktake.

## Boundaries and remaining work

- These are implemented integrations, not a claim that device scenarios passed. Build/device acceptance remains with the user.
- PRs must be merged, or their branch checked out, before the user builds this source. Production SQL is already deployed.
- Owners must grant the applicable permissions. Branch transfers additionally require the existing inventory_transfers_enabled configuration, branch mappings and subscription entitlement. These were not enabled indiscriminately.
- Branch offline cash requires a successfully prepared signed catalog; it does not invent authority when a device has never connected.
- Sync is application-side polling/resume behavior, not a server job capable of reading a switched-off device. Permission/subscription/reconciliation failures retain original requests for authorized review.
- Device activity is last-seen telemetry, not proof a device is currently connected, and not a replacement authorization source.
- Notifications here are the in-app operational feed. Native push delivery was not added.
- Existing receipt display remains; PDF export and physical printing were not added by this behavior patch.
- No new frontend package dependencies or cross-repository frontend packages were introduced.

## Final static and access review

All 77 POS application/package Dart files were reviewed for relative import targets and basic string/delimiter consistency; no missing relative targets or delimiter issues were found. This lightweight source check is not Dart analysis or compilation. All 58 statically referenced RPC names found in the POS source exist in production. New endpoint named arguments were compared with live catalog signatures.

Postflight: all seven new public RPCs deny anonymous EXECUTE and allow authenticated EXECUTE; all are SECURITY DEFINER with empty search_path. Direct authenticated/anonymous execution of private.pos_notification_feed is denied. The new device table has RLS, denies anonymous SELECT and authenticated INSERT, and remains empty.

Security advisor notices after deployment: 85 authenticated SECURITY DEFINER notices (78 before this phase; the seven new endpoints are intentional authorized RPCs); two anonymous SECURITY DEFINER notices, unchanged and outside these changes; 17 existing private RLS/no-policy informational notices; existing disabled leaked-password protection. No new anonymous RPC exposure was introduced.
References: [authenticated endpoint notice](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), [anonymous endpoint notice](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable), [RLS informational notice](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
