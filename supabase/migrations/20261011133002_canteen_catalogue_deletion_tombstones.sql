BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';

-- Inactive offers remain editable. Archived offers retain their sales references
-- but cannot return to the catalogue or be reactivated by an older client.
ALTER TABLE public.canteen_combos ADD COLUMN deleted_at timestamptz;
ALTER TABLE public.upsell_rules ADD COLUMN deleted_at timestamptz;
CREATE INDEX canteen_combos_live_catalogue_idx ON public.canteen_combos(lounge_id,sort_order,created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX upsell_rules_live_catalogue_idx ON public.upsell_rules(lounge_id,priority DESC,created_at DESC) WHERE deleted_at IS NULL;

CREATE OR REPLACE FUNCTION private.guard_catalogue_tombstone()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF TG_OP='UPDATE' AND OLD.deleted_at IS NOT NULL THEN
    IF (to_jsonb(NEW)-'updated_at') IS DISTINCT FROM (to_jsonb(OLD)-'updated_at') THEN
      RAISE EXCEPTION 'CATALOGUE_ITEM_DELETED' USING ERRCODE='55000';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.deleted_at IS NOT NULL THEN
    NEW.deleted_at:=clock_timestamp();
    NEW.is_active:=false;
  END IF;
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION private.guard_catalogue_tombstone() FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;
CREATE TRIGGER zz_canteen_combo_tombstone BEFORE INSERT OR UPDATE ON public.canteen_combos
FOR EACH ROW EXECUTE FUNCTION private.guard_catalogue_tombstone();
CREATE TRIGGER zz_upsell_rule_tombstone BEFORE INSERT OR UPDATE ON public.upsell_rules
FOR EACH ROW EXECUTE FUNCTION private.guard_catalogue_tombstone();
REVOKE DELETE ON public.canteen_combos,public.upsell_rules FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.archive_canteen_catalogue_item(p_kind text,p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_lounge uuid;v_deleted timestamptz;
BEGIN
  PERFORM private.require_active_booking_actor();
  IF p_id IS NULL OR p_kind IS NULL OR p_kind NOT IN ('combo','upsell_rule') THEN
    RAISE EXCEPTION 'INVALID_CATALOGUE_ARCHIVE_REQUEST' USING ERRCODE='22023';
  END IF;
  IF p_kind='combo' THEN
    SELECT lounge_id,deleted_at INTO v_lounge,v_deleted FROM public.canteen_combos WHERE id=p_id FOR UPDATE;
  ELSE
    SELECT lounge_id,deleted_at INTO v_lounge,v_deleted FROM public.upsell_rules WHERE id=p_id FOR UPDATE;
  END IF;
  IF NOT FOUND THEN RAISE EXCEPTION 'CATALOGUE_ITEM_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  IF public.is_super_admin() IS NOT TRUE AND public.has_lounge_permission(v_lounge,'menu_manage_items') IS NOT TRUE THEN
    RAISE EXCEPTION 'CATALOGUE_ARCHIVE_DENIED' USING ERRCODE='42501';
  END IF;
  IF v_deleted IS NULL THEN
    IF p_kind='combo' THEN
      UPDATE public.canteen_combos SET deleted_at=clock_timestamp(),is_active=false WHERE id=p_id;
      -- Keep the suggestion row for reports/editing, but stop promoting an
      -- archived combo. Its activation remains separate from deletion.
      UPDATE public.upsell_rules SET is_active=false WHERE suggest_combo_id=p_id AND deleted_at IS NULL;
    ELSE
      UPDATE public.upsell_rules SET deleted_at=clock_timestamp(),is_active=false WHERE id=p_id;
    END IF;
  END IF;
  RETURN jsonb_build_object('success',true,'id',p_id,'kind',p_kind);
END; $$;
REVOKE ALL ON FUNCTION public.archive_canteen_catalogue_item(text,uuid) FROM PUBLIC,anon,service_role,supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.archive_canteen_catalogue_item(text,uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
