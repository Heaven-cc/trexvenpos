# TREXVEN branch stocktaking and stock-management backend

Status: DEPLOYED AND SHARED FRONTEND ACTIVATED. Production target: ufehcfrlygqvminfjumf.
Both real Flutter checkouts and the existing shared operations package were accessed.
After the user's separate approval, migration 20261017052445_branch_inventory_operations was deployed successfully. The approved shared Flutter activation patch was applied only after read-only production verification passed. No business records, stock quantities or branch activation flags were changed.

## Files

- PROPOSED_branch_inventory_operations.sql: exact approved and deployed transaction, retained unchanged for checksum comparison. Its preparation-only header is historical; do not rerun it after deployment.
- READ_ONLY_VERIFICATION.sql: metadata and private-safe aggregate/digest queries for immediately before and after an approved deployment.
- FRONTEND_ACTIVATION.patch: the exact follow-up edits now applied to the two shared Flutter files. Do not reapply it.
- DEPLOYMENT_VERIFICATION.json: fresh before/after production fingerprints, deployed function/schema metadata, and installed shared-source hashes.
- This document: review scope, contracts, activation order and restrictions.

## What the deployed migration changes

It adds nullable branch_id columns to the existing stock_condition_entries and supplier_stock_returns tables, five composite foreign keys, and four indexes. Existing rows are not relabeled or backfilled. It creates no replacement stock database or duplicate ledger.

Four additional restrictive SELECT policies scope condition entries, supplier returns, sessions and offline reviews to the caller's authorized branches. The existing Stocktake read policy also gains a verified-owner exception for historical inactive-branch sessions; staff still require inventory permission and branch access. Existing account-deletion and business-suspension restrictions remain in force. Table/column grants are not broadened.

Five new public RPCs are introduced, without overloading or changing an existing RPC signature:

- get_trexven_inventory_capabilities(p_business_id uuid) -> jsonb.
- start_trexven_branch_stocktake(p_business_id uuid,p_branch_id uuid,p_request_id uuid,p_name text) -> jsonb.
- classify_trexven_branch_stock(p_business_id uuid,p_branch_id uuid,p_product_id uuid,p_request_id uuid,p_quantity numeric,p_condition text,p_reason text) -> jsonb.
- resolve_trexven_branch_condition_stock(p_business_id uuid,p_branch_id uuid,p_product_id uuid,p_request_id uuid,p_quantity numeric,p_condition text,p_action text,p_reason text) -> jsonb.
- dispatch_trexven_branch_supplier_return(p_business_id uuid,p_branch_id uuid,p_request_id uuid,p_product_id uuid,p_quantity numeric,p_condition text,p_supplier_name text,p_reason text) -> jsonb.

New public APIs require authenticated EXECUTE and internal permission/branch checks. Anon/PUBLIC EXECUTE is revoked. Two private invoker helpers authorize/lock branch context and apply branch stock differences; PUBLIC, anon, authenticated and service_role cannot execute them directly.

Eight existing functions are updated:

1. start_trexven_stocktake: prevent a second active whole-business count after idempotent replay.
2. count_trexven_stock: retain duplicate/version/counter checks; branch expected quantities come from locked original branch inventory.
3. approve_trexven_stocktake: branch reconciliation applies counted minus expected-at-count to CURRENT branch stock; the original non-branch reconciliation loop is retained.
4. manage_trexven_stocktake: retain existing lifecycle actions and require an assigned counter to have active access to the session's branch.
5. acknowledge_trexven_supplier_return: derive authorization and returned non-sellable stock from the original supplier record's branch.
6. review_trexven_inventory_discrepancy: derive branch authorization from the original session; it still does not adjust quantities.
7. private.capture_return_condition_stock: attribute newly approved damaged/defective customer returns to the original return branch. The already deployed refund/sellable-return RPC is not rewritten.
8. private.process_trexven_sale: append a movement record only when existing branch checkout deducts stock. The quantity predicate, prices, discounts, sale calculations, authorization and non-branch path are otherwise identical to the live definition. A reverse source comparison verified that this change is limited to the movement insert, RETURNING quantity, and its local variable.

## Preserved safety rules

- No branch activation flags, compatibility branches or stock allocations are changed.
- Existing branch inventory rows must exist; none are fabricated or populated automatically.
- Existing owner/staff permissions, explicit sensitive manager grants, subscription checks and business/account boundaries are retained.
- Branch activation and employee assignments are locked and rechecked, following checkout's existing authorization order.
- Product rows lock before branch inventory rows. Quantities cannot become negative or consume reserved stock. Reserved quantities are not overwritten.
- Counts save progress only. Approval remains a separate authorized transaction. Later sales/returns/restocking are retained through current quantity plus physical discrepancy.
- Durable request identity, replay receipts, duplicate-line checks and count versions remain enforced.
- Only one active whole-inventory session is allowed per business/branch scope, preventing overlapping approvals from applying the same discrepancy twice.
- Original sale/return/session references and actor/member attribution are retained in movements and audit records.
- Legacy non-branch APIs and financial formulas are not replaced.
- Working Credit & Returns and financial-summary RPCs, billing, account lifecycle and the separate Admin project are outside the deployment scope.

## Completed deployment order

The proposal has definition-hash guards for the modified RPCs and relevant helpers, owner/ACL guards for all eight modified functions, a scoped schema/policy/index/trigger/grant fingerprint, and collision guards for the new API names. It refuses unexpected drift, existing overlapping counts or invalid branch quantities/reservations. Transaction lock_timeout is 5 seconds; statement_timeout is 60 seconds. Failure must abort, with no destructive rollback or blind retry.

1. Obtained the user's separate production approval for this exact proposal, its scoped RLS changes and the matching shared frontend activation.
2. Confirm the Supabase project ID/host again, reread the proposal and ensure its SHA256 and current guards still match. Capture a fresh READ_ONLY_VERIFICATION baseline; do not rely on this preparation snapshot for later deployment.
3. Apply the approved SQL as one migration on ufehcfrlygqvminfjumf. Do not activate branches or seed stock. Its final NOTIFY requests a PostgREST schema-cache refresh after commit, following the [PostgREST schema cache documentation](https://docs.postgrest.org/en/stable/references/schema_cache.html).
4. Immediately perform read-only verification. Match deployed function bodies to the proposal, preserve existing argument/default/result contracts and ACLs, check intended policies/new helper permissions, and confirm no unrelated changes. Compare data counts/digests and inventory/financial integrity against the fresh baseline. New nullable branch columns are excluded from legacy row digests.
5. Only on success, apply FRONTEND_ACTIVATION.patch after checking both source hashes below. If verification fails, do not activate the frontend.
6. Recheck installed source hashes and exact RPC parameter names, without running builds, tests or applications.

All six steps above have been completed. The migration's guards passed against the fresh baseline. Deployment is recorded in Supabase migration history as 20261017052445 / branch_inventory_operations.

## Shared frontend activation installed

The patch preserves the redesign, sensitive-role checks, explicit confirmations, original request recovery and the existing POS adapter. It adds an Owner branch selector, authorized branch filtering and original-branch product quantities. It routes only start/classify/resolve/supplier-dispatch branch calls to the new RPCs; session-derived RPC contracts remain unchanged. A capability/version read fails closed on old or unavailable deployments. Both apps continue to share the same production records.

- C:\Users\USER\AndroidStudioProjects\Trexven\packages\trexven_operations\lib\src\inventory_operations_screen.dart
  Before SHA256: 0B8E6B086EBC28937E4D9C3BE661890596EE5AD7E0B70FED8FDA45D330F307AC
  Activated SHA256: F153477F099B706F50E97FA9AF785019F86C2E92796149711834D043C5E579F3
- C:\Users\USER\AndroidStudioProjects\Trexven\packages\trexven_operations\lib\src\inventory_operations_views.dart
  Before SHA256: 16F14E7715A4FE02791F7D277795D52780B92AF1CDDC7DF45D173C9F45837BC8
  Activated SHA256: 5A962BDCB5771CE92799ABA5CEC917BD033168E68D146479234505A9BCFB102B

## Verification actually performed

Live project identity, exact function definitions/permissions, table columns/constraints/indexes/triggers/policies, checkout lock order, quantity validation and source contracts were inspected read-only. The verification snapshot query itself was executed successfully as SELECT statements.

Fresh pre-deployment snapshot: 2026-10-17 05:24:00.721484+00 UTC.
Fresh post-deployment snapshot: 2026-10-17 05:24:51.4845+00 UTC.
- 18 relevant tables fingerprinted without private row details.
- All 18 row counts and digests match before/after. Unrelated function definitions/owners/ACLs, table security/grants, existing columns, unrelated constraints/indexes/policies, roles/memberships/default grants/schema grants, and all original triggers are unchanged. The complete trigger fingerprint changes only for the new foreign keys' internal PostgreSQL triggers.
- No enabled branch businesses, branches, inventory rows, sessions/counts, condition entries, supplier returns or offline reviews currently exist.
- All nine integrity counters are zero: negative credit, credit-ledger mismatch, return-allocation mismatch, invalid branch inventory, overlapping active scopes, invalid closed-count discrepancy, negative condition balance, duplicate branch movements and invalid movement deltas.
- All 15 deployed function bodies match the exact approved SQL. The eight existing signatures, defaults, results, ownership and ACLs are preserved. Five composite foreign keys are validated, four new indexes are valid/ready, the scoped policies match the proposal, and new private helpers have no client EXECUTE privileges. Financial-summary and Credit & Returns functions are unchanged.
- PostgreSQL accepted the migration and stored all definitions successfully. Stock-changing functions were not invoked for testing; live business workflows remain untested.
- Both installed shared Flutter files match their reviewed Activated SHA256 values above; both apps reference this same package. Atomic replacements left no temporary source files. Application behavior has not been runtime-tested.

No Flutter/Gradle build, app launch, analyzer/formatter, emulator, automated application test, dependency/SDK installation, local database/Supabase instance, Docker container or cache deletion was run. No production stock/financial test transactions were created. Only these small, necessary review artifacts were added; no project copies, backup directories or build outputs were generated.

Before relying on branch workflows, manually verify Owner/POS counts, save/resume, simultaneous sales, approval/recount/cancel, duplicate/retried requests, reservation boundaries, branch permissions and condition/supplier-return flows in an appropriately authorized environment. This deployment does not enable the dormant branch foundation or allocate a business's existing stock to branches.

## Approval recorded

The original user task explicitly required separate approval for essential backend deployment. The user approved the concrete SQL transaction, scoped RLS changes and matching frontend activation before implementation. No further approval is pending for this completed scope.
