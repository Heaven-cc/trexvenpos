# TREXVEN POS operations

This private package is an independent, POS-owned implementation. The app uses
`packages/trexven_operations`; the only nested local dependency is the sibling
POS-owned `../trexven_design_system` package. Neither package needs the Main app.

It contains POS credit/repayment/return/refund screens, inventory and stocktaking,
cash shifts, employee access, notifications, payment confirmation, the existing
operations client, stock-count batching, customer presentation, encrypted
durable state and the idempotent operation journal.

The initial separation preserves required operational logic. The export list
and package description were adjusted; unused account-management, Owner
permission-configuration, subscription entitlement and metric-layout files
were not copied. A subsequent POS-only UI review removed invalid `const`
qualifiers from 29 padding constructors that use runtime theme spacing.
Retained Owner-capable
branches inside required files preserve compatibility; they do not import or
depend on the Main app. Further simplification should preserve POS workflows.

Existing Supabase RPC names, arguments, permissions and durable-state identities
are retained. Package ownership is independent; the production backend remains
the existing shared TREXVEN backend. No backend migration accompanies separation.

Checkout, Confirm Payment and Sale Completion remain separate app stages.
The existing POS presentation marker selects the approved local UI.

Source inspection does not establish build or runtime compatibility. No Flutter
commands or backend business transactions were run during separation.
