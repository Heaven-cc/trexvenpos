# Verified corrections — Phase 1: employee permissions

Status: source prepared for review. No production deployment and no runtime verification.
Latest baseline: POS c344c8550a2b70b382bf7423db32a6456f021893; Owner 8a57789e5564e0dd7f7a7d5aa8e27b2b19a5bca5.
Owner's merged four-theme appearance work and POS's merged crash/UI fixes are preserved.

## Defect and correction

Managers received manage_employees through frontend defaults, employee-login defaults and the shared SQL authorization helper. POS offered staff administration in More and through notification navigation. Direct employee INSERT also had a permissive manager policy.

- POS model: manage_employees is owner-only even with a stale explicit grant; remove its manager default. Existing active-status checks and explicit employee denials remain before operational defaults.
- POS shell: remove Employees & permissions and staff-management notification routing. Own employee notifications still open personal settings.
- POS-owned EmployeeAccessScreen: reject POS application/presentation contexts before staff loading or actions, including direct navigation.
- Both independently owned login-permissions.ts copies: remove default and explicit employee manage_employees authorization. Keep other role defaults and explicit-denial filtering.
- Both independently owned permission screens: exclude manage_employees from delegable permissions.
- Owner-owned employee-access.ts: require RPC owner === true, so create/reset-password Edge Functions cannot accept manager authorization.
- Prepared SQL: remove employee manage_employees authorization, make staff assertion/update owner-only, restrict staff reads to owner or self, reject delegating staff administration, remove its fallback context permission and add restrictive owner-only employee INSERT/UPDATE/DELETE policies.

No existing employee, membership, permission or financial rows are edited. Existing obsolete grants remain stored but become ineffective after deployment. No new privileges or package dependencies.

## Files

POS:
- lib/src/models/employee.dart
- lib/src/features/pos/pos_shell.dart
- packages/trexven_operations/lib/src/employee_access_screen.dart
- supabase/functions/_shared/login-permissions.ts
- docs/VERIFIED_CORRECTIONS_PHASE_1.md

Owner:
- packages/trexven_operations/lib/src/employee_access_screen.dart
- supabase/functions/_shared/login-permissions.ts
- supabase/functions/_shared/employee-access.ts
- supabase/changes/phase_1_owner_only_employee_administration.sql
- docs/implementation/verified_corrections_phase_1.md

## Compatibility evidence

Read current Owner employee model/service and staff screen: Owner employee creation uses create-employee; password reset uses manage-employee; updates/status use existing named RPC contracts. All signatures remain unchanged. Owner identity is derived by user_owns_business from businesses.owner_id through existing account-deletion/admin-business guards. Those wrappers are preserved.

Read deployed employee-login v6, create-employee v7 and manage-employee v4. The latter two entrypoints and shared helper match current Owner source. Prepared deployment changes shared helpers, not their entrypoints. Keep employee-login verify_jwt=false (it is a pre-login endpoint); create-employee/manage-employee verify_jwt=true.

Read live permission/context/staff functions, policies and employee triggers. Permission helper still requires active employee and membership and applies denials before defaults. Existing private.has_business_permission wrapper stays unchanged. No sales/inventory function, receipt contract, queue, theme or authentication session pipeline is modified in Phase 1.

## Approval-required deployment

1. Review paired PRs and approve the exact Phase 1 production SQL + employee-login/create-employee/manage-employee deployment.
2. Re-read current live function definitions. Prepared SQL contains six exact baseline hash guards; abort on drift and review rather than bypassing them.
3. Promote the prepared SQL through the normal migration workflow with a generated migration version, apply atomically once, and record its actual version. It is intentionally under supabase/changes, not labeled as already deployed.
4. Deploy employee-login with the corrected login-permissions helper from its source. Deploy create-employee and manage-employee with the corrected employee-access helper from Owner source. Preserve pinned imports and JWT settings.
5. Read-only postflight: confirm exact function definitions, unchanged grants/search_path, restrictive policies, migration record, deployed Edge source and employee/financial row counts.
6. Release POS/frontend updates after the backend checkpoint. Frontend source alone does not remove direct access for old clients.

Do not roll back by restoring manager privileges without explicit approval.

## Manual acceptance required (user)

- Active manager can sell, view/manage approved inventory and perform other explicitly permitted operations, but cannot list/manage other staff or grant permissions.
- Check stale manage_employees grant and direct RPC/REST/Edge requests as manager: denied.
- Owner can create/update/suspend employees and reset passwords; owner status is verified server-side.
- Explicit operational denial overrides a role default; inactive/suspended employee and membership cannot operate.
- Employee can view own profile/settings and own notification target; other employee notification cannot open management.
- POS staff route invoked directly shows unavailable message without staff lookup.
- Verify Owner permissions screen excludes staff administration from delegable permissions.
- Verify appearance and existing POS checkout/recovery remain unchanged.

## Verification limits and next phases

Source and read-only live catalog inspection only. No local build, analyzer, test suite, fabricated identity/session or application-data write.
Prepared SQL has not been executed, including in a rollback transaction. Runtime and migration validation remain pending.
Phases 2–9 and their final handoff remain pending at the Phase 1 production-approval checkpoint; nothing in this report claims they are complete.
