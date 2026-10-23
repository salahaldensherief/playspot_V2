# Audit inventory method

inventory_reference.py documents the lexical discovery algorithm used in this audit. It expects the internal read-only catalog snapshots and checkout folders described by its W paths; it is not a standalone production verification tool or a deployed runtime. Full internal public/private function dumps are deliberately not published. Retained sanitized call records, signatures, catalog evidence and native logs are sufficient to review the findings. The request register has explicit semantic coverage limits.

Two executable isolated probes are committed under supabase/tests/launch_v2_cash_start.probe.mjs and launch_v2_extension.probe.mjs. They reuse existing synthetic fixture code, never accept a hosted database URL, and require the documented local fixture PostgreSQL setup. Evidence SQL snapshots must never be applied as migrations.
