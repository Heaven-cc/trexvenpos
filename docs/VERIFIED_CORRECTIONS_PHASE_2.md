# Verified corrections — Phase 2: POS action permissions

Status: frontend source implemented, not merged/released; manual acceptance pending.
Phase 1 backend was approved and deployed before these changes. Phase 2 needs no migration, Edge deployment or permission grants.

## Defects addressed

- Home exposed Expenses and Credit & Return without workflow capability checks. Operations exposed Credit & Returns unconditionally.
- Expense read-only managers could open the default personal-history scope, which live get_pos_expenses requires record_expenses to read.
- Financial routes relied on cached authorization during dialogs; Expenses did not subscribe to access changes before its locked-state return.

## Implementation and files

- lib/src/features/auth/permission_service.dart: central recording, branch-history and credit/return capability checks; stable grant/denial/role/status authorization key.
- lib/src/features/auth/pos_workflow_access.dart (new): fresh get_trexven_pos_context plus RLS-authorized active branch lookup; compare current employee/user/membership/business/branch-mode/permission snapshot; refresh visible session on access drift and reject stale action.
- lib/src/features/pos/dashboard_screen.dart: disable unauthorized shortcuts in the existing 2x2 layout.
- lib/src/features/pos/operations_screen.dart: only show authorized expense and credit/return workflows.
- lib/src/features/pos/credit_returns_screen.dart: block direct navigation without actual credit/return access, bind to authorization snapshot and supply read/action verification callbacks.
- lib/src/features/pos/expense_support_screen.dart: reactive access guard; read-only authorized managers open branch history directly; personal history remains for recorders; branch-history switch cannot fall back to unauthorized personal scope; clear pagination on scope changes; validate returned scope/business/branch/member; recording/recovery controls stay disabled without recording authority.
- lib/src/features/pos/pos_shell.dart: apply the same capability check to credit/return notification routing.
- packages/trexven_operations/lib/src/financial_operations_screen.dart (POS-owned copy): optional fresh verification before reads and preparing forms; fail closed on failed verification. Owner repository copy untouched.
- packages/trexven_operations/lib/src/operations_client.dart (POS-owned copy): optional verification hook. For idempotent writes, reserve original request/payload BEFORE online verification so connectivity/auth failures retain recoverable intent. Original committed-receipt recovery remains available; uncommitted replay verifies access. No request-ID regeneration.
- docs/VERIFIED_CORRECTIONS_PHASE_2.md: this evidence and manual checklist.

Approved UI colors, sizing, themes and navigation structure are unchanged. No business-wide financial totals are added. No new employee privilege or dependency.

## Backend / Owner compatibility

Read live get_pos_expenses/record_pos_expense: both require pos_access, and own history requires record_expenses while branch history requires explicit view_pos_expenses for owner/active authorized manager. Use those existing contracts, without granting writes to readers.

Read operations_context, inspect_trexven_return, decide_trexven_credit_approval and repay_trexven_credit. Existing server checks remain the commit-time authority for active employee/membership, explicit denials, sensitive manager grants and branch access. Do not unnecessarily require selling access for an employee explicitly authorized only to inspect returns or receive repayments.

All changes live in the independent POS repo; Owner Flutter/package sources and shared SQL signatures remain unchanged.

## Manual verification (user)

1. No financial capabilities: Home tiles disabled, no Operations entries, direct routes locked.
2. Manager with pos_access + view_pos_expenses, without record_expenses: opens branch history, paginates, cannot switch to own scope, record or retry expense.
3. Recorder without branch-read authority: can save and page own history, cannot request branch history.
4. Explicit denial beats role default; suspension, membership change, role/grant revocation and branch reassignment block open forms/actions on fresh verification.
5. Repayment-only / inspection-only / approval-only / read-only finance employee sees only the corresponding existing sections/actions; unauthorized direct navigation remains blocked.
6. Lose network after confirming a financial form: original idempotent operation stays journaled; recover with the original employee/business after connection returns; no second payment.
7. Switch account/business/branch while a read or form is pending: stale response is ignored and old snapshot cannot submit.
8. Confirm no POS business-wide totals and no design/crash-fix regressions.

## Evidence / limits

Live catalogs and source inspected; no local builds, analyzer, test suites, new identities or fabricated transaction calls.
Frontend source must be pulled/built and accepted by the user before claiming runtime success.
Phase 3 (session/password behavior) is next; later phases remain pending.
