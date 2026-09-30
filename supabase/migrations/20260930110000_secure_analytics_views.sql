BEGIN;

-- Views in an exposed schema must execute with the caller's permissions so
-- row-level security on the underlying tenant tables remains authoritative.
ALTER VIEW IF EXISTS public.canteen_attach_rate_v
  SET (security_invoker = true);
ALTER VIEW IF EXISTS public.canteen_aov_v
  SET (security_invoker = true);
ALTER VIEW IF EXISTS public.canteen_top_combos_v
  SET (security_invoker = true);
ALTER VIEW IF EXISTS public.canteen_upsell_conversion_v
  SET (security_invoker = true);
ALTER VIEW IF EXISTS public.canteen_low_stock_alerts_v
  SET (security_invoker = true);
ALTER VIEW IF EXISTS public.audit_timeline_legacy_v
  SET (security_invoker = true);

REVOKE ALL ON TABLE
  public.canteen_attach_rate_v,
  public.canteen_aov_v,
  public.canteen_top_combos_v,
  public.canteen_upsell_conversion_v,
  public.canteen_low_stock_alerts_v,
  public.audit_timeline_legacy_v
FROM PUBLIC, anon;

GRANT SELECT ON TABLE
  public.canteen_attach_rate_v,
  public.canteen_aov_v,
  public.canteen_top_combos_v,
  public.canteen_upsell_conversion_v,
  public.canteen_low_stock_alerts_v,
  public.audit_timeline_legacy_v
TO authenticated, service_role;

COMMIT;
