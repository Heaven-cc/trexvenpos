# Verified corrections — Phase 4: checkout / transaction safety

Status: frontend source implemented; legacy-execution restriction SQL prepared, NOT applied.
No current transaction, inventory mutation or historical receipt function was rewritten.

## Compatibility evidence

Focused caller scan fetched 210 current active Dart/Edge source files from both repositories, with zero fetch failures. Both apps use complete_trexven_transaction for current payment-line checkout. No exact quoted calls to complete_pos_sale or record_trexven_sale were found. POS also retains submit_trexven_sale / submit_trexven_branch_sale for older request-ID-bearing cash intents. These are not the two obsolete no-ID functions and remain available.

Read all 12 deployed Edge bundles: no calls to the two obsolete RPCs.
Read live SQL bodies and source references: public wrappers are the only SQL source callers of their corresponding private no-ID wrappers. The trusted process_trexven_sale engine remains postgres-only and is used by modern transaction logic.
GitHub indexed code search returned incomplete results, so it was not treated as evidence; the source-file scan supplied the compatibility evidence.

Current source scan baselines:
POS 02ca5d096284723be5bc17aac85c5ab6e86cc70b
Owner 9a94d50dd0a09f48be607329cb730156cd707e95

Installed historical mobile builds/external clients cannot be inventoried from GitHub. Any such client still calling the two obsolete endpoints must upgrade; do not manufacture request IDs on the server.

## Defects and source corrections

POS files:
- lib/src/features/pos/checkout_screen.dart: outer preparation/submission try/catch/finally releases the transient processing lock even if a drawer/payment dialog or local sale construction throws; pending/uncertain storage still routes through retained-sale recovery. Quantity controller lifetime uses the existing TextControllerScope until the dialog route actually disposes.
- lib/src/features/pos/sales_repository.dart: bound recoverLegacyReceipt's RPC wait to 20 seconds. Its direct recovery-gate caller previously awaited it without a timeout.
- lib/src/features/pos/pending_sale_provider.dart: bound cancellation RPC wait to 20 seconds; prevent overlapping cancellation dialogs/recovery; recheck original identity before local acknowledgement; legacy payment confirmation checks original active online employee context. No-money-moved cancellation remains explicit and server-confirmed.
- lib/src/services/pending_sale.dart: reject a receipt with no ID before acknowledging/displaying a completed sale. Existing membership/business/branch/amount checks remain.
- docs/VERIFIED_CORRECTIONS_PHASE_4.md: this report.

Preserved request ID/payload comparison, flush-before-send storage, replay/cross-format legacy receipt recovery, confirmed payment lines, partial-credit approvals, transaction lock order, stock engine, offline queue, and original-employee receipt acknowledgement.

Owner/backend files:
- supabase/changes/phase_4_restrict_legacy_sale_writes.sql
- docs/implementation/verified_corrections_phase_4.md
No Owner Flutter source changed in Phase 4.

## Prepared SQL (requires approval)

Revoke EXECUTE from PUBLIC/anon/authenticated on exactly:
- public.complete_pos_sale(uuid,uuid,numeric,text,jsonb)
- private.complete_pos_sale(uuid,uuid,numeric,text,jsonb)
- public.record_trexven_sale(uuid,uuid,integer,numeric)
- private.record_trexven_sale(uuid,uuid,integer,numeric)

Do not drop functions, rewrite sales/stock/history, revoke schema usage, or grant service-role permissions.
Preserve modern complete_trexven_transaction; request-ID submit variants; recover_trexven_legacy_checkout; get_trexven_operation_receipt. Existing owner/employee/branch checks remain authoritative.
Ten exact function-definition/ACL guards detect drift across affected and preserved paths before any privilege change.

After approval: re-read live callers/definitions/grants, promote SQL with an actual generated migration version, apply once, compare ACLs and preserved definition hashes, confirm financial row counts. Current preparation is not a production migration record.

## Manual acceptance required (user)

- Duplicate taps: one payment flow, one server sale and one stock deduction.
- Interrupt before and after commit: retain/recover original request and receipt, never collect payment a second time.
- Recovery network stall and cancellation timeout: controls become usable; original journal remains.
- Payment/drawer dialog failure: processing flag clears; storage uncertainty stays locked for recovery.
- Change quantity and close dialog: no disposed-controller access during reverse animation.
- Wrong employee/business/branch, permission revocation and no-money-moved cancellation: server denies unauthorized actions; request retained.
- Historic legacy receipts remain readable; old cash request-ID intents remain recoverable; current split/credit checkout remains unchanged.
- After approved migration only: authenticated direct calls to both obsolete public/private functions denied; current checkout/receipt functions retain prior grants.

No local build, analyzer, test suite, user login, payment or fabricated transaction ran.
Source/catalog review does not prove runtime acceptance.
Phase 3 password endpoint is deployed as v1 with verify_jwt=true, exact approved bundle confirmed; no credentials were changed during deployment.
Phases 5–9 remain pending at the Phase 4 production-approval checkpoint.
