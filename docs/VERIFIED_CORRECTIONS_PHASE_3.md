# Verified corrections — Phase 3: secure session/password behavior

Status: source prepared; new change-employee-password Edge Function NOT deployed.
No Phase 3 SQL or Auth configuration changes. Frontend PR is not merged/released; device acceptance pending.

## Defects and implemented corrections

The locked Supabase Flutter version is 2.17.2; persistence defaults to true already.
Its initialize() starts recoverSession asynchronously. POS's auth stream error handler could invalidate an in-flight restoration and immediately start another, while expired-token membership reads raced SDK refresh.

- lib/src/features/auth/auth_provider.dart: always finish the initial loading decision before choosing login; join the SDK's coalesced expired-token refresh before context reads; suppress redundant stream-triggered restoration while one is running; let its own catch handle refresh errors instead of recursively invalidating its generation; allow retryable Auth network failures through the existing encrypted offline-context validation. Explicit sign-out/invalid sessions still close access. Role/membership/business validation stays server-authoritative.
- lib/main.dart: explicitly preserve persistSession and autoRefreshToken. Retain the existing secure-access/loading gate and business/branch selection. No new token store, plaintext identity cache or dependency is introduced.
- lib/src/features/pos/employee_settings_screen.dart: invoke the authenticated self-service endpoint with the current/new credentials and business; verify response user/current account/business/membership before success. Do not re-sign-in on the primary Flutter client or mutate the active session. No frontend email or service key required.

The old form already obtained canonical Auth email rather than employees.email; null employee profile email alone was not proof of the defect. The concrete disruption was its primary-client re-sign-in emitting authentication changes during the password flow.

## Prepared backend extension (approval required)

Files in Owner repository:
- supabase/functions/change-employee-password/index.ts
- supabase/config.toml (verify_jwt=true entry)
- docs/implementation/verified_corrections_phase_3.md

The Edge Function:
- POST only, verified caller via Auth getUser, caller-scoped get_trexven_pos_context before and after credential verification; active matching business/user/membership required.
- Accepts only business_id/current_password/new_password. No target user, email, role or arbitrary attributes.
- Uses the canonical identifier from Auth; internal employee email remains server-side.
- Independently verifies the OLD password using an isolated nonpersisted Auth client and matches its user to the authenticated caller.
- Updates through /auth/v1/user using the ORIGINAL bearer/session, sends current_password as well, and preserves server password policy/MFA/secure-reauthentication checks. Does not use service_role or admin.updateUserById.
- Closes the isolated verification session locally. No sessions/tokens/passwords are logged, persisted or returned. Existing Supabase Auth password-update auditing applies.
- Returns only success + caller user ID on confirmed update. Timeout/unknown outcome never triggers automatic retry; password may already be changed.
- If secure Auth configuration requires additional reauthentication, fail closed and request a fresh sign-in. Do not bypass that requirement for internal-email accounts.

Normal password-change security may invalidate OTHER devices' Auth sessions; pending sales/encrypted queues remain on those devices and are recovered after sign-in. This is not a change to normal multiple-device login support.

## Compatibility / evidence

Read current production function list: no self-service password endpoint existed. Existing create/reset-password Owner endpoints are separate and unchanged.
Read pinned Flutter SDK source for session recovery, LocalStorage defaults and token refresh coalescing, plus official Supabase Auth password verification/session-update source.
No Owner Flutter/theme edits; no package/dependency changes. No queue, journal, encryption-key, request-ID, branch-authority or financial-write code is changed in this phase.

Phase 1 production remains migration 20261020235818 and employee-login v7/create-employee v8/manage-employee v5.
Security advisor groups remain 85 authenticated definer exposures, 2 anonymous definer exposures, 17 RLS/no-policy informational notices and leaked-password protection disabled. Those later handoff phases are not claimed corrected here.
See:
https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Deployment / manual verification

Approve only the new change-employee-password function from this PR, with verify_jwt=true. No migration, account credential mutation or Auth setting change is included in that deployment.
After approved deployment, fetch its source back and compare exact bundle/JWT setting. Release frontend only after endpoint availability.
User manual checks:
1. Reopen with valid and expired access token + valid refresh token: loading/refresh then authorized workspace, without unnecessary login.
2. Invalid/revoked refresh token: sign-in required; offline queue and original requests still retained.
3. Temporary refresh network failure: bounded verification retry or existing valid 24h encrypted offline mode; no retry storm or online permission bypass.
4. Suspend employee/revoke branch/change permissions before reopening: server context closes unauthorized workflows.
5. Employee with null profile email/internal Auth email can change own password using correct old credential. Wrong old credential, other-user target, invalid/suspended membership and missing JWT cannot update.
6. Secure reauthentication/MFA requirement is respected. Observe other-device reauthentication after password change.
7. Switch account/business during request: old response cannot announce success in a new context.
8. Simulate unknown password response only in user-controlled testing; no automatic retry or fabricated confirmation.

## Limits and pending work

No local build, analyzer, test suite, user login, credential change or fabricated transaction was performed.
Source inspection does not prove the reported every-launch behavior is resolved on the device; user acceptance is required.
Phases 4–9 and final handoff remain pending at this Phase 3 production-approval checkpoint.
