# Published policy content

The documented public contract returns published policy documents (`docs/audits/backend_requests.md`). The observed `get_public_policies(p_lang text)` definition on 2026-10-10 selects only `legal_policies.is_published = true` and selects the requested language. The dashboard's `admin_upsert_legal_policy` controls this publication flag.

Consequently an empty successful response is not permission to invent replacement terms, privacy promises or refunds in the app. The mobile screen now shows a localized unavailable message for absent content and displays only the returned policy. It clears previous response content when reloading, so switching language cannot preserve a policy absent from the new response. Request failures keep the existing error/retry behavior.

Four new widget regressions failed before the fix (empty publication and stale language content in Arabic/English). All 12 support/policy/Quick Rebook widget cases and the full 480 mobile tests pass after it. This is widget validation against synthetic responses, not a live publication change.
