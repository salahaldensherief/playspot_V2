BEGIN;

CREATE OR REPLACE FUNCTION public.create_user_ban_request(
  p_lounge_id uuid,
  p_user_id uuid,
  p_booking_id uuid DEFAULT NULL,
  p_reason text DEFAULT NULL,
  p_evidence_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor_role text;
  v_request_id uuid;
  v_reason text := NULLIF(btrim(COALESCE(p_reason,'')),'');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';
  END IF;

  IF p_lounge_id IS NULL OR p_user_id IS NULL OR v_reason IS NULL THEN
    RAISE EXCEPTION 'LOUNGE_USER_AND_REASON_REQUIRED' USING ERRCODE='22023';
  END IF;

  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'CANNOT_REQUEST_SELF_BAN' USING ERRCODE='42501';
  END IF;

  v_actor_role := private.permission_role(auth.uid(), p_lounge_id);
  IF v_actor_role NOT IN ('owner','manager') THEN
    RAISE EXCEPTION 'LOUNGE_OWNER_OR_MANAGER_REQUIRED' USING ERRCODE='42501';
  END IF;

  IF p_booking_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.id=p_booking_id
      AND b.lounge_id=p_lounge_id
      AND b.user_id=p_user_id
  ) THEN
    RAISE EXCEPTION 'BOOKING_SCOPE_MISMATCH' USING ERRCODE='22023';
  END IF;

  SELECT r.id
  INTO v_request_id
  FROM public.user_ban_requests r
  WHERE r.lounge_id=p_lounge_id
    AND r.user_id=p_user_id
    AND r.status='pending'
  ORDER BY r.created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF v_request_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success',true,
      'request_id',v_request_id,
      'status','pending',
      'idempotent',true
    );
  END IF;

  INSERT INTO public.user_ban_requests(
    lounge_id,user_id,booking_id,reason,evidence_notes,status
  )
  VALUES(
    p_lounge_id,p_user_id,p_booking_id,v_reason,
    NULLIF(btrim(COALESCE(p_evidence_notes,'')),''),
    'pending'
  )
  RETURNING id INTO v_request_id;

  RETURN jsonb_build_object(
    'success',true,
    'request_id',v_request_id,
    'status','pending',
    'idempotent',false
  );
END;
$function$;

DROP POLICY IF EXISTS user_ban_requests_insert_owner
ON public.user_ban_requests;

CREATE POLICY user_ban_requests_insert_owner_or_manager
ON public.user_ban_requests
FOR INSERT
TO authenticated
WITH CHECK (
  private.permission_role(auth.uid(),lounge_id) IN ('owner','manager')
  AND user_id <> auth.uid()
  AND (
    booking_id IS NULL
    OR EXISTS (
      SELECT 1
      FROM public.bookings b
      WHERE b.id=booking_id
        AND b.lounge_id=user_ban_requests.lounge_id
        AND b.user_id=user_ban_requests.user_id
    )
  )
);

REVOKE ALL ON FUNCTION public.create_user_ban_request(
  uuid,uuid,uuid,text,text
) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.create_user_ban_request(
  uuid,uuid,uuid,text,text
) TO authenticated,service_role;

COMMIT;
