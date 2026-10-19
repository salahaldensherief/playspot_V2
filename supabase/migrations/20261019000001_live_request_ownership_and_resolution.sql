BEGIN;
-- Order totals and contents are server-owned. Dashboard resolution uses the
-- authorized SECURITY DEFINER RPC, so client table updates are unnecessary.
REVOKE UPDATE ON public.canteen_orders FROM anon, authenticated;

-- A customer service call must belong to their running booking and match its
-- lounge and room. The existing direct INSERT grant stays for clients using it.
DROP POLICY IF EXISTS "Users can create service calls for their bookings"
  ON public.service_calls;
CREATE POLICY "Users can create service calls for their bookings"
  ON public.service_calls FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND status = 'pending'
    AND COALESCE(is_attended, false) = false
    AND EXISTS (
      SELECT 1 FROM public.bookings AS b
      WHERE b.id = service_calls.booking_id
        AND b.user_id = (SELECT auth.uid())
        AND b.status = 'in_progress'::public.booking_status
        AND b.lounge_id = service_calls.lounge_id
        AND b.room_id IS NOT DISTINCT FROM service_calls.room_id
    )
  );

-- A canteen order has no service_call_id relationship. Completing one order
-- cannot safely complete other calls for the same booking.
CREATE OR REPLACE FUNCTION public.resolve_live_request(p_request_type text, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_type text := lower(btrim(COALESCE(p_request_type, '')));
  v_lounge_id uuid;
  v_booking_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_request_id IS NULL THEN
    RAISE EXCEPTION 'Request id is required' USING ERRCODE = '22023';
  END IF;

  IF v_type IN ('canteen', 'canteen_order') THEN
    SELECT co.lounge_id, co.booking_id
    INTO v_lounge_id, v_booking_id
    FROM public.canteen_orders AS co
    WHERE co.id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Canteen order not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.is_super_admin()
       AND NOT public.has_lounge_permission(v_lounge_id, 'pos_create_orders') THEN
      RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;

    UPDATE public.canteen_orders
    SET status = 'completed',
        is_attended = true,
        is_read = true,
        updated_at = now()
    WHERE id = p_request_id;

  ELSIF v_type IN ('service', 'service_call', 'call_staff') THEN
    SELECT COALESCE(sc.lounge_id, b.lounge_id), sc.booking_id
    INTO v_lounge_id, v_booking_id
    FROM public.service_calls AS sc
    LEFT JOIN public.bookings AS b ON b.id = sc.booking_id
    WHERE sc.id = p_request_id
    FOR UPDATE OF sc;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Service call not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.is_super_admin()
       AND NOT public.has_lounge_permission(v_lounge_id, 'sessions_control') THEN
      RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;

    UPDATE public.service_calls
    SET status = 'resolved',
        is_attended = true,
        is_read = true,
        updated_at = now()
    WHERE id = p_request_id;

  ELSIF v_type IN ('request', 'client_request') THEN
    SELECT cr.lounge_id, cr.booking_id
    INTO v_lounge_id, v_booking_id
    FROM public.client_requests AS cr
    WHERE cr.id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Client request not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.is_super_admin()
       AND NOT public.has_lounge_permission(v_lounge_id, 'sessions_control') THEN
      RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;

    UPDATE public.client_requests
    SET status = 'resolved',
        is_attended = true,
        is_read = true
    WHERE id = p_request_id;

  ELSE
    RAISE EXCEPTION 'Unsupported request type' USING ERRCODE = '22023';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'request_type', v_type,
    'request_id', p_request_id,
    'lounge_id', v_lounge_id,
    'booking_id', v_booking_id
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.resolve_live_request(text, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_live_request(text, uuid)
  TO authenticated, service_role, supabase_auth_admin;

COMMIT;
