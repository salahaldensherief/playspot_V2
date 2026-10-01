-- Review source only. Load before cashier_writer_availability.sql.
BEGIN;
CREATE SCHEMA IF NOT EXISTS private;
REVOKE CREATE ON SCHEMA private FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS private.cashier_writer_permits (
  permit_id uuid PRIMARY KEY,
  lounge_id uuid NOT NULL REFERENCES public.lounges(id),
  actor_id uuid NOT NULL,
  device_id uuid NOT NULL,
  issued_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  permissions jsonb NOT NULL,
  CHECK(expires_at>issued_at AND expires_at-issued_at<=interval '24 hours'),
  CHECK(jsonb_typeof(permissions)='object' AND permissions ?& ARRAY['bookings.manage','sessions_control','billing_checkout']
    AND jsonb_typeof(permissions->'bookings.manage')='boolean'
    AND jsonb_typeof(permissions->'sessions_control')='boolean'
    AND jsonb_typeof(permissions->'billing_checkout')='boolean')
);
ALTER TABLE private.cashier_writer_permits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.cashier_writer_permits FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.guard_cashier_permit_immutability()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  RAISE EXCEPTION 'CASHIER_PERMITS_ARE_IMMUTABLE' USING ERRCODE='55000';
END; $$;
REVOKE ALL ON FUNCTION private.guard_cashier_permit_immutability() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS guard_cashier_permit_immutability ON private.cashier_writer_permits;
CREATE TRIGGER guard_cashier_permit_immutability BEFORE UPDATE OR DELETE ON private.cashier_writer_permits
FOR EACH ROW EXECUTE FUNCTION private.guard_cashier_permit_immutability();

CREATE OR REPLACE FUNCTION private.cashier_effective_permissions(p_lounge_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT jsonb_build_object(
    'bookings.manage',public.is_super_admin() IS TRUE OR public.has_lounge_permission(p_lounge_id,'bookings.manage') IS TRUE,
    'sessions_control',public.is_super_admin() IS TRUE OR public.has_lounge_permission(p_lounge_id,'sessions_control') IS TRUE,
    'billing_checkout',public.is_super_admin() IS TRUE OR public.has_lounge_permission(p_lounge_id,'billing_checkout') IS TRUE);
$$;
REVOKE ALL ON FUNCTION private.cashier_effective_permissions(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION private.cashier_sync_permit_matches_writer(p_lounge_id uuid,p_actor_id uuid,p_permit_id uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  RETURN EXISTS(SELECT 1 FROM private.cashier_writer_authorities writer
    JOIN private.cashier_writer_permits permit ON permit.lounge_id=writer.lounge_id
      AND permit.actor_id=writer.actor_id AND permit.device_id=writer.device_id
    WHERE writer.lounge_id=p_lounge_id AND writer.actor_id=p_actor_id AND permit.permit_id=p_permit_id);
END;
$$;
REVOKE ALL ON FUNCTION private.cashier_sync_permit_matches_writer(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;
COMMIT;
