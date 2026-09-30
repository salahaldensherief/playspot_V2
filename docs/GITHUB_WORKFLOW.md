# GitHub workflow and branch ownership

`dev` is the integration branch. `main` is the reviewed release branch.
Feature and fix branches are temporary and must have one clear purpose.

## Safe cleanup

Delete a remote branch only after every commit is reachable from dev or main,
its pull request is closed, and no active worktree still depends on it.
Preserve transfer bundles and branches with unique work until a verified integration.
Never discard uncommitted work, force-push shared history, or rewrite applied migrations.

## Current work

- Mobile UI: local handoff/mobile-ui; integration candidate remains under review.
- Dashboard UI: local handoff/dashboard-ui; uncommitted work must be reviewed separately.
- Backend: fix/backend-financial-contracts; isolated tests pass but rollout is not approved.
- Original backend phases: backend/playspot-core-v2; preserve until repairs are integrated.
- Transfer: handoff/ui-transfer-20260930; preserve recovery archive.

## Release requirements

Verify formatter, analyze and offline tests on the combined integration state.
Review RPC contracts, permissions and migration ordering independently of Flutter tests.
No automatic production migrations are authorized by a code push.
Do not treat unmerged branches as obsolete merely because their names are old.