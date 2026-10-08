-- Service-only: the Edge handler must resolve the authenticated caller before passing this ID.
BEGIN;
CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id),
  requested_at timestamptz NOT NULL DEFAULT now(),
  auth_disabled_at timestamptz
);
ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_deletion_requests FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, UPDATE ON public.account_deletion_requests TO service_role;
DROP POLICY IF EXISTS account_deletion_service_reconciliation ON public.account_deletion_requests;
CREATE POLICY account_deletion_service_reconciliation
ON public.account_deletion_requests TO service_role
USING (true) WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.anonymize_account_for_deletion(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'USER_REQUIRED' USING ERRCODE = '22023';
  END IF;
  PERFORM 1 FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROFILE_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO public.account_deletion_requests(user_id) VALUES(p_user_id)
  ON CONFLICT (user_id) DO NOTHING;
  DELETE FROM public.points_transactions WHERE user_id = p_user_id;
  DELETE FROM public.user_vouchers WHERE user_id = p_user_id;
  DELETE FROM public.notifications WHERE user_id = p_user_id;
  DELETE FROM public.notification_settings WHERE user_id = p_user_id;
  DELETE FROM public.favorites WHERE user_id = p_user_id;
  UPDATE public.profiles
  SET full_name = 'Deleted User', phone = NULL, email = NULL,
      avatar_url = NULL, fcm_token = NULL, is_active = false,
      is_banned = true, updated_at = now()
  WHERE id = p_user_id;
  -- Bookings, payments and ownership are preserved under the existing deletion policy.
  RETURN jsonb_build_object('success', true, 'deactivated', true);
END;
$function$;
REVOKE ALL ON FUNCTION public.anonymize_account_for_deletion(uuid)
FROM PUBLIC, anon, authenticated, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.anonymize_account_for_deletion(uuid) TO service_role;
COMMIT;
