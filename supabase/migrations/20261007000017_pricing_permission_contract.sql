BEGIN;

INSERT INTO public.app_permissions (
  key,name_ar,name_en,category,description_ar,description_en,
  default_super_admin,default_owner,default_cashier
)
VALUES (
  'pricing_manage',
  'إدارة التسعير',
  'Manage Pricing',
  'pricing',
  'إنشاء وتعديل وحذف قواعد التسعير.',
  'Create, update and delete pricing rules.',
  true,true,false
)
ON CONFLICT (key) DO UPDATE SET
  name_ar=EXCLUDED.name_ar,
  name_en=EXCLUDED.name_en,
  category=EXCLUDED.category,
  description_ar=EXCLUDED.description_ar,
  description_en=EXCLUDED.description_en,
  default_super_admin=true,
  default_owner=true,
  default_cashier=false;

CREATE OR REPLACE FUNCTION private.permission_key_allowed_for_role(
  p_role text,
  p_key text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path TO ''
AS $function$
  SELECT CASE lower(btrim(COALESCE(p_role, '')))
    WHEN 'super_admin' THEN true
    WHEN 'owner' THEN p_key NOT IN (
      'analytics_view_global',
      'lounges_manage_all'
    )
    WHEN 'manager' THEN p_key NOT IN (
      'analytics_view_global',
      'lounges_manage_all',
      'payouts_manage'
    )
    WHEN 'cashier' THEN p_key NOT IN (
      'analytics_view_global',
      'lounges_manage_all',
      'payouts_manage',
      'staff_manage',
      'staff.manage',
      'shifts_review_and_approve',
      'lounges_manage_settings',
      'pricing_manage'
    )
    WHEN 'staff' THEN p_key NOT IN (
      'analytics_view_global',
      'lounges_manage_all',
      'payouts_manage',
      'staff_manage',
      'staff.manage',
      'shifts_review_and_approve',
      'lounges_manage_settings',
      'pricing_manage'
    )
    ELSE false
  END;
$function$;

DROP POLICY IF EXISTS pricing_rules_write ON public.pricing_rules;
CREATE POLICY pricing_rules_write
ON public.pricing_rules
FOR ALL
TO authenticated
USING (
  public.is_super_admin()
  OR public.has_lounge_permission(lounge_id,'pricing_manage')
)
WITH CHECK (
  (
    public.is_super_admin()
    OR public.has_lounge_permission(lounge_id,'pricing_manage')
  )
  AND (
    room_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.rooms AS r
      WHERE r.id=room_id AND r.lounge_id=lounge_id
    )
  )
  AND (
    space_type_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.space_types AS st
      WHERE st.id=space_type_id
    )
  )
);

UPDATE public.lounge_role_permissions AS lrp
SET is_enabled=false,
    updated_at=now()
WHERE lrp.permission_key='pricing_manage'
  AND lrp.role IN ('cashier','staff')
  AND lrp.is_enabled IS TRUE;

COMMIT;
