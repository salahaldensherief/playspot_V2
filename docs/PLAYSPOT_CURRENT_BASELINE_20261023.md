# PlaySpot current integration baseline — 2026-10-23

This is a verified snapshot for the next research and architecture phase. Historical handoffs are context, not proof of today's branch state. `dev` is the integration branch in both repositories. No production deployment or production database mutation was performed during this check.

| Area | Verified state | Evidence |
| --- | --- | --- |
| Mobile `dev` | `f8218550b9b3d1419a3e4ef1d57741bf034ea2f7` | [Splash typography PR #77](https://github.com/salahaldensherief/playspot_V2/pull/77), merged after [final-head Flutter CI](https://github.com/salahaldensherief/playspot_V2/actions/runs/40014419514) and [formatting](https://github.com/salahaldensherief/playspot_V2/actions/runs/40014419535) succeeded. |
| Dashboard `dev` | `e111196f0ebaabe3a1ec39e4e2a2d094d388c621` | [Scheduler safety PR #77](https://github.com/salahaldensherief/Playspot_dashboard/pull/77) and [UI direction documentation PR #78](https://github.com/salahaldensherief/Playspot_dashboard/pull/78) merged. |
| Dashboard redesign | Rejected and absent from `dev` | [Dashboard PR #75](https://github.com/salahaldensherief/Playspot_dashboard/pull/75) closed without merge. The existing Dashboard UI is the approved baseline. |
| Open Time financial work | Draft, not integrated | [Mobile PR #75](https://github.com/salahaldensherief/playspot_V2/pull/75) remains Draft at `b9edcf976b7e861fcef0bea8688558ac0c2d72a5`. Exact-schema financial validation remains required. |
| System Atlas | Proposed documentation, absent from `dev` | [Mobile PR #76](https://github.com/salahaldensherief/playspot_V2/pull/76) and [Dashboard PR #76](https://github.com/salahaldensherief/Playspot_dashboard/pull/76) remain open and currently conflict with newer `dev` changes. Their 22 October source snapshots must be refreshed before integration. |

Worktree inspection found six Dashboard and ten Mobile checkouts. There are uncommitted changes in the rejected Dashboard UI worktree (five paths), another Dashboard audit worktree (one path), a scheduler evaluation worktree (one path), a Mobile audit worktree (eight paths), and the isolated splash worktree (seven generated platform files). The `task02a/security-regression` Dashboard branch has two local commits ahead of its upstream; the `fix/open-time-canteen-duration-followup` Mobile branch has one. These were not reset, deleted, or merged by this baseline check. Reinspect their exact diffs before reuse.

The new master directive describes seven operator survey responses; the unmerged System Atlas records four responses from an earlier review. Neither number should be presented as a complete market estimate without reviewing the original survey data and dates. This is a research discrepancy to resolve, not a reason to overwrite verified code behavior.

Research already confirms that [PanCafe Pro's official feature list](https://www.pancafepro.com/?page=features) describes terminal sessions, cashier authorization, tariffs, cafeteria stock, reporting, and audio alerts. [Gizmo's official product page](https://gizmopowered.com/product) describes POS, PC management, security logs, and employee/shift reports. Those claims establish comparison targets only; they do not establish a usable public API or prove PlaySpot controls physical devices. Candidate GitHub repositories need license, security, and code review before any reuse.

Next evidence gates: inspect the existing PlaySpot capability paths and the exact deployed-compatible schema in a disposable environment; complete competitor/source-code research; refresh the Atlas without stale PR assertions; then evaluate small, independent implementation increments. Preserve the user's rejected Dashboard UI decision throughout.
