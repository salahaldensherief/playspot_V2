# Profile write boundary

Migration 20261001130000_profile_security_write_boundaries.sql is not applied live.
17 isolated grant/RLS checks passed. Self-service profile creation defaults to user;
clients may edit only identity/display/location/token/preferences fields. Points, role,
lounge assignment, setup/account activation, ban state and referral ownership stay
server-owned. Anonymous writes, DELETE, TRUNCATE and trigger/reference grants are removed.
Existing authenticated SELECT policies remain intact. Staff/admin mutations must use
reviewed server RPCs; membership alone no longer authorizes editing coworker profiles.

Client inventory:
- Mobile auth profile upserts and location/token/display edits use allowed columns.
- Mobile legacy referral-code generation must use ensure_my_referral_code() and must
  not invent a fallback referral code after a server/network failure.
- Dashboard auth location edits are compatible.
- Dashboard lounge creation attempts a forbidden direct owner-role/setup update;
  remove it and use the authenticated super_admin_create_lounge_with_owner route.
- The active signup trigger handle_new_user always creates user and does NOT trust
  raw_user_meta_data.role. The dangerous-looking alternate function is not attached
  to auth.users; it is not evidence of a currently active signup escalation path.

Rollout gate: actual signup triggers, ON CONFLICT profile upserts, existing client
insert payloads, all security-definer staff/admin RPCs and grants must be verified on
an isolated production-schema clone. No live policy changes or deletion occurred.