-- =============================================================================
-- PLAYSPOT STAGING MIGRATION BUNDLE (11 SEQUENTIAL MIGRATIONS)
-- Generated: 2026-10-26
-- Target: Staging / Verified Demo (DO NOT RUN ON PRODUCTION tgpdexoitemmpruepgyt)
-- Contains: 5 Intermediate Core Migrations + 6 Financial Architecture Migrations
-- =============================================================================

-- -----------------------------------------------------------------------------
-- START MIGRATION: 20261019212746_live_request_ownership_and_resolution.sql
-- -----------------------------------------------------------------------------

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
       AND NOT public.has_lounge_permission(v_lounge_id, 'sessions_control') THEN
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


-- -----------------------------------------------------------------------------
-- END MIGRATION: 20261019212746_live_request_ownership_and_resolution.sql
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- START MIGRATION: 20261019212750_live_session_visit_number.sql
-- -----------------------------------------------------------------------------

BEGIN;
-- Rank the current booking against the customer's full lounge history.
-- Filtering to in_progress first made every single active booking visit #1.
CREATE OR REPLACE FUNCTION public.get_live_bookings_with_items(p_lounge_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_result JSONB;
BEGIN
  IF p_lounge_id IS NULL THEN
    RAISE EXCEPTION 'Invalid lounge_id parameter';
  END IF;

  IF NOT (public.is_super_admin() OR private.can_operate_playspot_lounge(p_lounge_id) OR public.is_lounge_member_or_admin(p_lounge_id)) THEN
    RAISE EXCEPTION 'Unauthorized: You do not have permission to view live bookings for this lounge' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', b.id,
      'out_booking_id', b.id,
      'lounge_id', b.lounge_id,
      'user_id', b.user_id,
      'room_id', b.room_id,
      'start_time', b.start_time,
      'end_time', b.end_time,
      'duration_minutes', b.duration_minutes,
      'total_price', b.total_price,
      'addons_price', b.addons_price,
      'status', b.status,
      'created_at', b.created_at,
      'user_name', COALESCE(b.user_name, p.full_name, 'Walk-in Customer'),
      'user_phone', COALESCE(b.user_phone, p.phone),
      'room_name', COALESCE(r.name_ar, r.name_en, r.name, 'Room'),
      'visit_number', b.visit_num,
      'out_visit_number', b.visit_num,
      'canteen_orders', (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', co.id,
            'items', co.items,
            'total_price', co.total_price,
            'status', co.status,
            'created_at', co.created_at
          )
        ), '[]'::jsonb)
        FROM public.canteen_orders co
        WHERE co.booking_id = b.id
      )
    )
  ), '[]'::jsonb) INTO v_result
  FROM (
    SELECT
      bk.*,
      (
        SELECT 1 + count(DISTINCT previous.created_at)
        FROM public.bookings AS previous
        WHERE previous.lounge_id = bk.lounge_id
          AND previous.created_at < bk.created_at
          AND previous.status IN ('in_progress'::public.booking_status, 'completed'::public.booking_status)
          AND (
            (bk.user_id IS NOT NULL AND previous.user_id = bk.user_id)
            OR (
              bk.user_id IS NULL
              AND previous.user_id IS NULL
              AND NULLIF(btrim(bk.user_phone), '') IS NOT NULL
              AND bk.user_phone NOT IN ('null', 'No Phone')
              AND btrim(previous.user_phone) = btrim(bk.user_phone)
            )
          )
      ) AS visit_num
    FROM public.bookings bk
    WHERE bk.lounge_id = p_lounge_id AND bk.status = 'in_progress'::public.booking_status
    ORDER BY bk.created_at DESC
  ) b
  LEFT JOIN public.profiles p ON b.user_id = p.id
  LEFT JOIN public.rooms r ON b.room_id = r.id;

  RETURN v_result;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_live_bookings_with_items(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_live_bookings_with_items(uuid)
  TO authenticated, service_role, supabase_auth_admin;
COMMIT;


-- -----------------------------------------------------------------------------
-- END MIGRATION: 20261019212750_live_session_visit_number.sql
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- START MIGRATION: 20261020123340_live_booking_read_permissions.sql
-- -----------------------------------------------------------------------------

BEGIN;

-- Booking mutations go through price/conflict/permission checked RPCs.
-- Direct table grants let any lounge_staff member bypass those rules.
REVOKE INSERT, UPDATE, DELETE ON public.bookings FROM anon, authenticated;

-- Direct table reads must honor the same permission catalog as the dashboard.
-- A lounge_staff row alone is not an authorization to inspect customer data.
ALTER POLICY bookings_select_customer_or_branch ON public.bookings
  USING (
    user_id = (SELECT auth.uid())
    OR public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.lounges l
      WHERE l.id = bookings.lounge_id AND l.owner_id = (SELECT auth.uid())
    )
    OR public.has_lounge_permission(lounge_id, 'bookings.view')
    OR public.has_lounge_permission(lounge_id, 'bookings.manage')
    OR public.has_lounge_permission(lounge_id, 'sessions_control')
    OR public.has_lounge_permission(lounge_id, 'billing_checkout')
    OR public.has_lounge_permission(lounge_id, 'shifts_view')
  );

ALTER POLICY bookings_select_policy ON public.bookings
  USING (
    user_id = (SELECT auth.uid())
    OR public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.lounges l
      WHERE l.id = bookings.lounge_id AND l.owner_id = (SELECT auth.uid())
    )
    OR public.has_lounge_permission(lounge_id, 'bookings.view')
    OR public.has_lounge_permission(lounge_id, 'bookings.manage')
    OR public.has_lounge_permission(lounge_id, 'sessions_control')
    OR public.has_lounge_permission(lounge_id, 'billing_checkout')
    OR public.has_lounge_permission(lounge_id, 'shifts_view')
  );

ALTER POLICY "Users can view own canteen orders" ON public.canteen_orders
  USING (
    user_id = (SELECT auth.uid())
    OR public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.lounges l
      WHERE l.id = canteen_orders.lounge_id AND l.owner_id = (SELECT auth.uid())
    )
    OR public.has_lounge_permission(lounge_id, 'bookings.view')
    OR public.has_lounge_permission(lounge_id, 'sessions_control')
    OR public.has_lounge_permission(lounge_id, 'billing_checkout')
    OR public.has_lounge_permission(lounge_id, 'pos_create_orders')
  );

-- The RPC is SECURITY DEFINER and bypasses table RLS, so it needs its own
-- explicit actor/resource check. Its result shape stays unchanged.
CREATE OR REPLACE FUNCTION public.get_live_bookings_with_items(p_lounge_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_result JSONB;
BEGIN
  IF p_lounge_id IS NULL THEN
    RAISE EXCEPTION 'Invalid lounge_id parameter';
  END IF;

  IF NOT (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.lounges l
      WHERE l.id = p_lounge_id AND l.owner_id = auth.uid()
    )
    OR public.has_lounge_permission(p_lounge_id, 'bookings.view')
    OR public.has_lounge_permission(p_lounge_id, 'sessions_control')
  ) THEN
    RAISE EXCEPTION 'Unauthorized: You do not have permission to view live bookings for this lounge' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', b.id,
      'out_booking_id', b.id,
      'lounge_id', b.lounge_id,
      'user_id', b.user_id,
      'room_id', b.room_id,
      'start_time', b.start_time,
      'end_time', b.end_time,
      'duration_minutes', b.duration_minutes,
      'total_price', b.total_price,
      'addons_price', b.addons_price,
      'status', b.status,
      'created_at', b.created_at,
      'user_name', COALESCE(b.user_name, p.full_name, 'Walk-in Customer'),
      'user_phone', COALESCE(b.user_phone, p.phone),
      'room_name', COALESCE(r.name_ar, r.name_en, r.name, 'Room'),
      'visit_number', b.visit_num,
      'out_visit_number', b.visit_num,
      'canteen_orders', (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', co.id,
            'items', co.items,
            'total_price', co.total_price,
            'status', co.status,
            'created_at', co.created_at
          )
        ), '[]'::jsonb)
        FROM public.canteen_orders co
        WHERE co.booking_id = b.id
      )
    )
  ), '[]'::jsonb) INTO v_result
  FROM (
    SELECT
      bk.*,
      (
        SELECT 1 + count(DISTINCT previous.created_at)
        FROM public.bookings AS previous
        WHERE previous.lounge_id = bk.lounge_id
          AND previous.created_at < bk.created_at
          AND previous.status IN ('in_progress'::public.booking_status, 'completed'::public.booking_status)
          AND (
            (bk.user_id IS NOT NULL AND previous.user_id = bk.user_id)
            OR (
              bk.user_id IS NULL
              AND previous.user_id IS NULL
              AND NULLIF(btrim(bk.user_phone), '') IS NOT NULL
              AND bk.user_phone NOT IN ('null', 'No Phone')
              AND btrim(previous.user_phone) = btrim(bk.user_phone)
            )
          )
      ) AS visit_num
    FROM public.bookings bk
    WHERE bk.lounge_id = p_lounge_id AND bk.status = 'in_progress'::public.booking_status
    ORDER BY bk.created_at DESC
  ) b
  LEFT JOIN public.profiles p ON b.user_id = p.id
  LEFT JOIN public.rooms r ON b.room_id = r.id;

  RETURN v_result;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_live_bookings_with_items(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_live_bookings_with_items(uuid)
  TO authenticated, service_role, supabase_auth_admin;

COMMIT;


-- -----------------------------------------------------------------------------
-- END MIGRATION: 20261020123340_live_booking_read_permissions.sql
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- START MIGRATION: 20261020151000_sync_lounge_review_summary.sql
-- -----------------------------------------------------------------------------

-- The mobile lounge summary reads these denormalized columns. Keep them in
-- sync with the same lounge_reviews rows shown in the reviews section.
CREATE OR REPLACE FUNCTION public.update_lounge_average_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  affected_lounge_id uuid;
BEGIN
  FOR affected_lounge_id IN
    SELECT DISTINCT lounge_id
    FROM (VALUES
      (CASE WHEN TG_OP = 'DELETE' THEN OLD.lounge_id ELSE NEW.lounge_id END),
      (CASE WHEN TG_OP = 'UPDATE' THEN OLD.lounge_id ELSE NULL::uuid END)
    ) AS affected(lounge_id)
    WHERE lounge_id IS NOT NULL
    ORDER BY lounge_id
  LOOP
    -- Serialize concurrent review changes before reading their aggregate.
    PERFORM 1 FROM public.lounges WHERE id = affected_lounge_id FOR UPDATE;
    UPDATE public.lounges AS lounge
    SET total_reviews = review_summary.review_count,
        rating = review_summary.average_rating
    FROM (
      SELECT count(*)::integer AS review_count,
             coalesce(avg(rating), 0) AS average_rating
      FROM public.lounge_reviews
      WHERE lounge_id = affected_lounge_id
    ) AS review_summary
    WHERE lounge.id = affected_lounge_id;
  END LOOP;

  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS trg_update_lounge_rating ON public.lounge_reviews;
CREATE TRIGGER trg_update_lounge_rating
AFTER INSERT OR UPDATE OR DELETE ON public.lounge_reviews
FOR EACH ROW EXECUTE FUNCTION public.update_lounge_average_rating();

-- Existing counts included stale and demo values with no matching reviews.
-- Rebuild the displayed summary from the authoritative review records.
UPDATE public.lounges AS lounge
SET total_reviews = review_summary.review_count,
    rating = review_summary.average_rating
FROM (
  SELECT lounge.id,
         count(review.id)::integer AS review_count,
         coalesce(avg(review.rating), 0) AS average_rating
  FROM public.lounges AS lounge
  LEFT JOIN public.lounge_reviews AS review ON review.lounge_id = lounge.id
  GROUP BY lounge.id
) AS review_summary
WHERE lounge.id = review_summary.id
  AND (lounge.total_reviews IS DISTINCT FROM review_summary.review_count
       OR lounge.rating IS DISTINCT FROM review_summary.average_rating);


-- -----------------------------------------------------------------------------
-- END MIGRATION: 20261020151000_sync_lounge_review_summary.sql
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- START MIGRATION: 20261021120000_live_session_read_contract.sql
-- -----------------------------------------------------------------------------

BEGIN;

-- Restore booking schedule/payment and order notes in the authorized live read.
CREATE OR REPLACE FUNCTION public.get_live_bookings_with_items(p_lounge_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_result JSONB;
BEGIN
  IF p_lounge_id IS NULL THEN
    RAISE EXCEPTION 'Invalid lounge_id parameter';
  END IF;

  IF NOT (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.lounges l
      WHERE l.id = p_lounge_id AND l.owner_id = auth.uid()
    )
    OR public.has_lounge_permission(p_lounge_id, 'bookings.view')
    OR public.has_lounge_permission(p_lounge_id, 'sessions_control')
  ) THEN
    RAISE EXCEPTION 'Unauthorized: You do not have permission to view live bookings for this lounge' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', b.id,
      'out_booking_id', b.id,
      'lounge_id', b.lounge_id,
      'user_id', b.user_id,
      'room_id', b.room_id,
      'date', b.date,
      'scheduled_start_utc', (COALESCE(b.start_at, b.date + b.start_time) AT TIME ZONE COALESCE(l.timezone, 'Africa/Cairo')),
      'scheduled_end_utc', (b.end_at AT TIME ZONE COALESCE(l.timezone, 'Africa/Cairo')),
      'payment_status', b.payment_status,
      'payment_method', b.payment_method,
      'is_open_time', b.is_open_time,
      'start_time', b.start_time,
      'end_time', b.end_time,
      'duration_minutes', b.duration_minutes,
      'total_price', b.total_price,
      'addons_price', b.addons_price,
      'status', b.status,
      'created_at', b.created_at,
      'user_name', COALESCE(b.user_name, p.full_name, 'Walk-in Customer'),
      'user_phone', COALESCE(b.user_phone, p.phone),
      'room_name', COALESCE(r.name_ar, r.name_en, r.name, 'Room'),
      'visit_number', b.visit_num,
      'out_visit_number', b.visit_num,
      'canteen_orders', (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', co.id,
            'items', co.items,
            'total_price', co.total_price,
            'note', co.note,
            'status', co.status,
            'created_at', co.created_at
          )
        ), '[]'::jsonb)
        FROM public.canteen_orders co
        WHERE co.booking_id = b.id
      )
    )
  ), '[]'::jsonb) INTO v_result
  FROM (
    SELECT
      bk.*,
      (
        SELECT 1 + count(DISTINCT previous.created_at)
        FROM public.bookings AS previous
        WHERE previous.lounge_id = bk.lounge_id
          AND previous.created_at < bk.created_at
          AND previous.status IN ('in_progress'::public.booking_status, 'completed'::public.booking_status)
          AND (
            (bk.user_id IS NOT NULL AND previous.user_id = bk.user_id)
            OR (
              bk.user_id IS NULL
              AND previous.user_id IS NULL
              AND NULLIF(btrim(bk.user_phone), '') IS NOT NULL
              AND bk.user_phone NOT IN ('null', 'No Phone')
              AND btrim(previous.user_phone) = btrim(bk.user_phone)
            )
          )
      ) AS visit_num
    FROM public.bookings bk
    WHERE bk.lounge_id = p_lounge_id AND bk.status = 'in_progress'::public.booking_status
    ORDER BY bk.created_at DESC
  ) b
  LEFT JOIN public.profiles p ON b.user_id = p.id
  LEFT JOIN public.rooms r ON b.room_id = r.id
  JOIN public.lounges l ON b.lounge_id = l.id;

  RETURN v_result;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_live_bookings_with_items(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_live_bookings_with_items(uuid)
  TO authenticated, service_role, supabase_auth_admin;

-- Keep the dashboard bookings workspace on the same schedule and note contract.
CREATE OR REPLACE FUNCTION public.get_all_bookings_admin(
  p_lounge_id uuid DEFAULT NULL::uuid,
  p_status text DEFAULT NULL::text,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0,
  p_search text DEFAULT NULL::text,
  p_payment_status text DEFAULT NULL::text,
  p_date date DEFAULT NULL::date
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_super boolean;
  v_lounge_ids uuid[];
  v_target_lounge uuid;
  v_result JSONB;
BEGIN
  PERFORM private.require_active_booking_actor();
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 1000 OR p_offset IS NULL OR p_offset<0 THEN
    RAISE EXCEPTION 'INVALID_BOOKING_PAGE' USING ERRCODE='22023';
  END IF;
  v_super := public.is_super_admin();
  IF p_lounge_id IS NOT NULL AND v_super IS NOT TRUE
    AND public.has_lounge_permission(p_lounge_id,'bookings.view') IS NOT TRUE THEN
    RAISE EXCEPTION 'BOOKING_READ_PERMISSION_DENIED' USING ERRCODE='42501';
  END IF;
  v_target_lounge := p_lounge_id;
  IF v_super IS NOT TRUE THEN
    SELECT COALESCE(array_agg(l.id),'{}'::uuid[]) INTO v_lounge_ids
    FROM public.lounges l WHERE public.has_lounge_permission(l.id,'bookings.view') IS TRUE;
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', b.id,
      'out_booking_id', b.id,
      'user_id', b.user_id,
      'lounge_id', b.lounge_id,
      'room_id', b.room_id,
      'user_name', COALESCE(b.user_name, p.full_name, 'Walk-in Customer'),
      'customer_name', COALESCE(b.user_name, p.full_name, 'Walk-in Customer'),
      'user_phone', COALESCE(b.user_phone, p.phone),
      'customer_phone', COALESCE(b.user_phone, p.phone),
      'user_email', p.email,
      'customer_email', p.email,
      'room_name', COALESCE(r.name_ar, r.name_en, r.name, 'Room'),
      'out_room_name', COALESCE(r.name_ar, r.name_en, r.name, 'Room'),
      'controllers_count', r.controllers_count,
      'screen_size', r.screen_size,
      'out_booking_date', b.date,
      'date', b.date,
      'scheduled_start_utc', (COALESCE(b.start_at, b.date + b.start_time) AT TIME ZONE COALESCE(l.timezone, 'Africa/Cairo')),
      'scheduled_end_utc', (b.end_at AT TIME ZONE COALESCE(l.timezone, 'Africa/Cairo')),
      'out_start_time', b.start_time,
      'start_time', b.start_time,
      'out_end_time', b.end_time,
      'end_time', b.end_time,
      'duration_minutes', b.duration_minutes,
      'status', b.status,
      'out_booking_status', b.status,
      'payment_status', b.payment_status,
      'out_payment_status', b.payment_status,
      'payment_method', b.payment_method,
      'out_payment_method', b.payment_method,
      'total_price', b.total_price,
      'out_total_price', b.total_price,
      'addons_price', b.addons_price,
      'out_addons_price', b.addons_price,
      'voucher_code', b.applied_voucher_code,
      'discount_amount', b.discount_amount,
      'discount_percentage', b.discount_percentage,
      'discount_reason', b.discount_reason,
      'play_mode', b.play_mode,
      'room_price', b.room_price,
      'shift_id', b.shift_id,
      'created_at', b.created_at,
      'checked_in_at', b.checked_in_at,
      'cancellation_reason', b.cancellation_reason,
      'cancelled_by', b.cancelled_by,
      'cancelled_at', b.cancelled_at,
      'rejection_reason', b.rejection_reason,
      'canteen_orders', (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', co.id,
            'items', co.items,
            'total_price', co.total_price,
            'note', co.note,
            'status', co.status,
            'created_at', co.created_at
          )
        ), '[]'::jsonb)
        FROM public.canteen_orders co
        WHERE co.booking_id = b.id
      ),
      'extras', (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', bi.id,
            'extra_id', bi.extra_id,
            'name', bi.name,
            'quantity', bi.quantity,
            'unit_price', bi.unit_price,
            'total_price', bi.total_price,
            'status', bi.status
          )
        ), '[]'::jsonb)
        FROM public.booking_items bi
        WHERE bi.booking_id = b.id
      )
    )
  ), '[]'::jsonb) INTO v_result
  FROM (
    SELECT bk.*
    FROM public.bookings bk
    LEFT JOIN public.profiles pr ON bk.user_id = pr.id
    LEFT JOIN public.rooms rm ON bk.room_id = rm.id
    WHERE (v_target_lounge IS NULL OR bk.lounge_id = v_target_lounge)
      AND (v_super IS TRUE OR bk.lounge_id=ANY(v_lounge_ids))
      AND (p_status IS NULL OR p_status = '' OR bk.status::text = p_status)
      AND (p_payment_status IS NULL OR p_payment_status = '' OR bk.payment_status = p_payment_status)
      AND (p_date IS NULL OR bk.date = p_date)
      AND (
        p_search IS NULL
        OR p_search = ''
        OR bk.id::text ILIKE '%' || p_search || '%'
        OR bk.user_name ILIKE '%' || p_search || '%'
        OR bk.user_phone ILIKE '%' || p_search || '%'
        OR pr.full_name ILIKE '%' || p_search || '%'
        OR pr.phone ILIKE '%' || p_search || '%'
        OR pr.email ILIKE '%' || p_search || '%'
        OR rm.name ILIKE '%' || p_search || '%'
      )
    ORDER BY bk.created_at DESC,bk.id
    LIMIT p_limit
    OFFSET p_offset
  ) b
  LEFT JOIN public.profiles p ON b.user_id = p.id
  LEFT JOIN public.rooms r ON b.room_id = r.id
  JOIN public.lounges l ON b.lounge_id = l.id;

  RETURN v_result;
END;
$function$;


COMMIT;




-- -----------------------------------------------------------------------------
-- END MIGRATION: 20261021120000_live_session_read_contract.sql
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- START MIGRATION: 20261025101139_atomic_discount_cash_checkout.sql
-- -----------------------------------------------------------------------------

-- Exact deployed contract guard. Do not apply if the canonical collector drifted.
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.collect_booking_cash_partial(uuid,uuid,numeric,uuid)'::regprocedure))
      <> 'b2b0d07ad98247c015ef67d43b0665aa' THEN
    RAISE EXCEPTION 'CASH_COLLECTOR_CONTRACT_DRIFT';
  END IF;
END;
$guard$;

-- A request fingerprint prevents an operation ID being replayed with a different
-- discount. Existing plain collection receipts retain NULL here.
ALTER TABLE private.cash_collection_receipts
  ADD COLUMN checkout_request jsonb;

-- The receipt insert holds an FK key-share on the booking. Two distinct requests
-- can otherwise deadlock when both later upgrade that lock to FOR UPDATE.
CREATE OR REPLACE FUNCTION public.collect_booking_cash_partial(
  p_booking_id uuid,p_shift_id uuid,p_amount_minor numeric,p_operation_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_receipt private.cash_collection_receipts%ROWTYPE; v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_operation_id IS NULL OR p_booking_id IS NULL OR p_shift_id IS NULL OR p_amount_minor IS NULL
    OR p_amount_minor::text IN ('NaN','Infinity','-Infinity') OR p_amount_minor<=0
    OR p_amount_minor<>trunc(p_amount_minor) OR p_amount_minor>9007199254740991 THEN
    RAISE EXCEPTION 'INVALID_CASH_COLLECTION_REQUEST' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_booking_id::text,0));
  INSERT INTO private.cash_collection_receipts(operation_id,actor_id,booking_id,shift_id,amount_minor)
    VALUES(p_operation_id,auth.uid(),p_booking_id,p_shift_id,p_amount_minor) ON CONFLICT DO NOTHING;
  SELECT * INTO STRICT v_receipt FROM private.cash_collection_receipts WHERE operation_id=p_operation_id FOR UPDATE;
  IF v_receipt.actor_id IS DISTINCT FROM auth.uid() OR v_receipt.booking_id IS DISTINCT FROM p_booking_id
    OR v_receipt.shift_id IS DISTINCT FROM p_shift_id OR v_receipt.amount_minor IS DISTINCT FROM p_amount_minor THEN
    RAISE EXCEPTION 'CASH_COLLECTION_REPLAY_CONFLICT' USING ERRCODE='22023';
  END IF;
  IF v_receipt.result IS NOT NULL THEN
    PERFORM private.assert_cash_collector(auth.uid(),(v_receipt.result->>'lounge_id')::uuid);
    RETURN v_receipt.result||jsonb_build_object('replayed',true);
  END IF;
  v_result:=private.apply_partial_cash_collection(p_booking_id,p_shift_id,p_amount_minor)
    ||jsonb_build_object('operation_id',p_operation_id,'replayed',false);
  UPDATE private.cash_collection_receipts SET result=v_result WHERE operation_id=p_operation_id;
  RETURN v_result;
END; $function$;

-- One RPC / one database transaction for discount approval and cash collection.
-- All mutations, including the receipt and payment metadata, roll back together.
CREATE FUNCTION public.checkout_booking_cash_atomic(
  p_booking_id uuid,
  p_shift_id uuid,
  p_amount_minor numeric,
  p_operation_id uuid,
  p_discount_amount numeric DEFAULT 0,
  p_discount_percentage numeric DEFAULT 0,
  p_discount_reason text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_request jsonb;
  v_receipt private.cash_collection_receipts%ROWTYPE;
  v_booking public.bookings%ROWTYPE;
  v_result jsonb;
  v_amount_minor numeric;
  v_paid numeric;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_operation_id IS NULL OR p_booking_id IS NULL OR p_shift_id IS NULL
    OR (p_amount_minor IS NOT NULL AND (p_amount_minor::text IN ('NaN','Infinity','-Infinity')
      OR p_amount_minor<=0 OR p_amount_minor<>trunc(p_amount_minor)
      OR p_amount_minor>9007199254740991))
    OR p_discount_amount IS NULL OR p_discount_percentage IS NULL
    OR p_discount_amount::text IN ('NaN','Infinity','-Infinity')
    OR p_discount_percentage::text IN ('NaN','Infinity','-Infinity')
    OR p_discount_amount<0 OR p_discount_percentage<0 THEN
    RAISE EXCEPTION 'INVALID_ATOMIC_CHECKOUT_REQUEST' USING ERRCODE='22023';
  END IF;
  v_request:=jsonb_build_object('requested_amount_minor',p_amount_minor,'discount_amount',p_discount_amount,
    'discount_percentage',p_discount_percentage,'discount_reason',p_discount_reason);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_booking_id::text,0));
  SELECT * INTO v_receipt FROM private.cash_collection_receipts
    WHERE operation_id=p_operation_id FOR UPDATE;
  IF FOUND THEN
    IF v_receipt.actor_id IS DISTINCT FROM auth.uid()
      OR v_receipt.booking_id IS DISTINCT FROM p_booking_id
      OR v_receipt.shift_id IS DISTINCT FROM p_shift_id
      OR (p_amount_minor IS NOT NULL AND v_receipt.amount_minor IS DISTINCT FROM p_amount_minor)
      OR v_receipt.checkout_request IS DISTINCT FROM v_request THEN
      RAISE EXCEPTION 'ATOMIC_CHECKOUT_REPLAY_CONFLICT' USING ERRCODE='22023';
    END IF;
    IF v_receipt.result IS NULL THEN
      RAISE EXCEPTION 'ATOMIC_CHECKOUT_UNRESOLVED_RECEIPT' USING ERRCODE='55000';
    END IF;
    PERFORM private.assert_cash_collector(auth.uid(),(v_receipt.result->>'lounge_id')::uuid);
    RETURN v_receipt.result||jsonb_build_object('replayed',true);
  END IF;

  v_booking:=private.lock_cash_collection_booking(p_booking_id);
  PERFORM private.lock_cash_collection_shift(p_shift_id,v_booking.lounge_id);
  IF p_discount_amount>0 OR p_discount_percentage>0 THEN
    IF COALESCE(v_booking.discount_amount,0)>0 OR COALESCE(v_booking.discount_percentage,0)>0 THEN
      RAISE EXCEPTION 'DISCOUNT_ALREADY_APPLIED' USING ERRCODE='55000';
    END IF;
    PERFORM public.apply_booking_discount(p_booking_id,p_discount_amount,
      p_discount_percentage,p_discount_reason,NULL);
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id;
  v_amount_minor:=p_amount_minor;
  IF v_amount_minor IS NULL THEN
    v_paid:=private.cash_collection_paid_amount(p_booking_id,v_booking.lounge_id,v_booking.payment_status);
    v_amount_minor:=(v_booking.total_price-v_paid)*100;
    IF v_amount_minor<=0 OR v_amount_minor<>trunc(v_amount_minor) THEN
      RAISE EXCEPTION 'NO_COLLECTIBLE_BALANCE' USING ERRCODE='22023';
    END IF;
  END IF;
  INSERT INTO private.cash_collection_receipts(
    operation_id,actor_id,booking_id,shift_id,amount_minor,checkout_request)
  VALUES(p_operation_id,auth.uid(),p_booking_id,p_shift_id,v_amount_minor,v_request);
  v_result:=public.collect_booking_cash_partial(p_booking_id,p_shift_id,v_amount_minor,p_operation_id);
  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id;
  INSERT INTO private.cash_collection_context(transaction_id,booking_id)
    VALUES(txid_current(),p_booking_id) ON CONFLICT DO NOTHING;
  UPDATE public.payments SET discount_amount=v_booking.discount_amount,
    discount_percentage=v_booking.discount_percentage,
    discount_reason=v_booking.discount_reason,
    discount_approved_by=v_booking.discount_approved_by
  WHERE booking_id=p_booking_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'CHECKOUT_PAYMENT_MISSING' USING ERRCODE='55000'; END IF;
  DELETE FROM private.cash_collection_context
    WHERE transaction_id=txid_current() AND booking_id=p_booking_id;
  v_result:=v_result||jsonb_build_object('discount_amount',v_booking.discount_amount,
    'discount_percentage',v_booking.discount_percentage,'total_minor',v_booking.total_price*100);
  UPDATE private.cash_collection_receipts SET result=v_result WHERE operation_id=p_operation_id;
  RETURN v_result;
END; $function$;

REVOKE ALL ON FUNCTION public.checkout_booking_cash_atomic(uuid,uuid,numeric,uuid,numeric,numeric,text)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.checkout_booking_cash_atomic(uuid,uuid,numeric,uuid,numeric,numeric,text)
  TO authenticated;


-- -----------------------------------------------------------------------------
-- END MIGRATION: 20261025101139_atomic_discount_cash_checkout.sql
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- START MIGRATION: 20261025151217_owner_permission_write_boundary.sql
-- -----------------------------------------------------------------------------

BEGIN;

-- Role templates and per-user overrides must be changed through audited RPCs.
-- Direct table writes bypass the delegation rules in update_role_permission.
REVOKE INSERT, UPDATE, DELETE ON public.staff_permissions
  FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.lounge_role_permissions
  FROM PUBLIC, anon, authenticated;
-- Guarded staff RPCs own membership changes. Direct writes allowed self-promotion.
REVOKE INSERT, UPDATE, DELETE ON public.lounge_staff
  FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.permission_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id),
  actor_user_id uuid NOT NULL REFERENCES public.profiles(id),
  target_user_id uuid REFERENCES public.profiles(id),
  target_role text,
  permission_key text NOT NULL,
  old_value boolean,
  new_value boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT permission_audit_target_check
    CHECK ((target_user_id IS NOT NULL) <> (target_role IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS permission_audit_logs_lounge_time_idx
  ON public.permission_audit_logs(lounge_id, created_at DESC);
ALTER TABLE public.permission_audit_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.permission_audit_logs FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.permission_audit_logs TO authenticated;
DROP POLICY IF EXISTS permission_audit_owner_read ON public.permission_audit_logs;
CREATE POLICY permission_audit_owner_read ON public.permission_audit_logs
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR EXISTS (
    SELECT 1 FROM public.lounges l
    JOIN public.profiles p ON p.id = l.owner_id
    WHERE l.id = permission_audit_logs.lounge_id
      AND l.owner_id = (SELECT auth.uid())
      AND p.is_active IS TRUE AND p.is_banned IS FALSE
  ) OR EXISTS (
    SELECT 1 FROM public.lounge_staff ls
    JOIN public.profiles p ON p.id = ls.user_id
    WHERE ls.lounge_id = permission_audit_logs.lounge_id
      AND ls.user_id = (SELECT auth.uid())
      AND ls.role = 'lounge_owner'
      AND p.is_active IS TRUE AND p.is_banned IS FALSE
  ));

-- The older get_staff_permissions reads the profile's primary lounge.
-- This explicit scope supports staff assigned to multiple branches.
CREATE OR REPLACE FUNCTION public.get_lounge_staff_permissions(
  p_lounge_id uuid, p_target_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor_role text;
  v_target_role text;
  v_permissions jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_lounge_id IS NULL OR p_target_user_id IS NULL THEN
    RAISE EXCEPTION 'Lounge and employee are required' USING ERRCODE = '22023';
  END IF;
  v_actor_role := private.permission_role(auth.uid(), p_lounge_id);
  v_target_role := private.permission_role(p_target_user_id, p_lounge_id);
  IF v_actor_role IS NULL OR v_actor_role NOT IN ('owner','super_admin')
     OR v_target_role IS NULL OR v_target_role NOT IN ('manager','cashier','staff') THEN
    RAISE EXCEPTION 'Not authorized for employee permissions in this lounge'
      USING ERRCODE = '42501';
  END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'permission_key',a.key,'name_ar',a.name_ar,'name_en',a.name_en,
    'category',a.category,'description_ar',a.description_ar,
    'description_en',a.description_en,
    'is_enabled',private.user_permission_value(p_target_user_id,p_lounge_id,a.key)
  ) ORDER BY a.key),'[]'::jsonb)
  INTO v_permissions
  FROM public.app_permissions a;
  RETURN jsonb_build_object('success',true,'lounge_id',p_lounge_id,
    'target_user_id',p_target_user_id,'role',v_target_role,
    'permissions',v_permissions);
END;
$function$;
REVOKE ALL ON FUNCTION public.get_lounge_staff_permissions(uuid,uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_lounge_staff_permissions(uuid,uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.set_staff_permission(
  p_lounge_id uuid,
  p_target_user_id uuid,
  p_permission_key text,
  p_is_enabled boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_actor_role text;
  v_target_role text;
  v_key text := btrim(p_permission_key);
  v_previous boolean;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_lounge_id IS NULL OR p_target_user_id IS NULL
     OR v_key IS NULL OR v_key = '' OR p_is_enabled IS NULL THEN
    RAISE EXCEPTION 'Permission request is incomplete' USING ERRCODE = '22023';
  END IF;

  v_actor_role := private.permission_role(v_actor, p_lounge_id);
  IF v_actor_role IS NULL OR v_actor_role NOT IN ('owner', 'super_admin') THEN
    RAISE EXCEPTION 'Only the lounge owner may set employee permissions'
      USING ERRCODE = '42501';
  END IF;

  v_target_role := private.permission_role(p_target_user_id, p_lounge_id);
  IF v_target_role IS NULL OR v_target_role NOT IN ('manager', 'cashier', 'staff')
     OR v_actor = p_target_user_id THEN
    RAISE EXCEPTION 'Target must be another active employee in this lounge'
      USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.app_permissions a WHERE a.key = v_key) THEN
    RAISE EXCEPTION 'Unknown permission key' USING ERRCODE = '22023';
  END IF;
  IF p_is_enabled AND NOT private.permission_key_allowed_for_role(v_target_role, v_key) THEN
    RAISE EXCEPTION 'Permission cannot be granted to this role'
      USING ERRCODE = '42501';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(
    'staff_permission:' || p_lounge_id::text || ':' || p_target_user_id::text || ':' || v_key, 0));

  SELECT sp.is_enabled INTO v_previous
  FROM public.staff_permissions sp
  WHERE sp.lounge_id = p_lounge_id
    AND sp.user_id = p_target_user_id
    AND sp.permission_key = v_key
  FOR UPDATE;

  INSERT INTO public.staff_permissions
    (lounge_id, user_id, permission_key, is_enabled, updated_at)
  VALUES (p_lounge_id, p_target_user_id, v_key, p_is_enabled, now())
  ON CONFLICT (user_id, lounge_id, permission_key)
  DO UPDATE SET is_enabled = EXCLUDED.is_enabled, updated_at = now();

  INSERT INTO public.permission_audit_logs
    (lounge_id, actor_user_id, target_user_id, permission_key, old_value, new_value)
  VALUES (p_lounge_id, v_actor, p_target_user_id, v_key, v_previous, p_is_enabled);

  RETURN jsonb_build_object(
    'success', true, 'lounge_id', p_lounge_id,
    'target_user_id', p_target_user_id,
    'permission_key', v_key, 'is_enabled', p_is_enabled
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.set_staff_permission(uuid,uuid,text,boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_staff_permission(uuid,uuid,text,boolean)
  TO authenticated;

-- Role templates are lounge-wide. A manager's staff_manage permission must not
-- allow granting a privilege they do not hold, or changing their own template.
CREATE OR REPLACE FUNCTION public.update_role_permission(
  p_role text, p_permission_key text, p_is_enabled boolean,
  p_lounge_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_role text := lower(btrim(p_role));
  v_key text := btrim(p_permission_key);
  v_actor_role text;
  v_previous boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF v_role NOT IN ('owner','manager','cashier','staff','super_admin')
     OR p_is_enabled IS NULL THEN
    RAISE EXCEPTION 'Unsupported permission request' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.app_permissions a WHERE a.key = v_key) THEN
    RAISE EXCEPTION 'Unknown permission key' USING ERRCODE = '22023';
  END IF;
  IF p_is_enabled AND NOT private.permission_key_allowed_for_role(v_role,v_key) THEN
    RAISE EXCEPTION 'Permission cannot be delegated to this role'
      USING ERRCODE = '42501';
  END IF;

  IF p_lounge_id IS NULL THEN
    IF NOT public.is_super_admin() THEN
      RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;
    UPDATE public.role_permissions
    SET is_enabled=p_is_enabled, updated_at=now()
    WHERE role=v_role AND permission_key=v_key;
    RETURN jsonb_build_object('success',true,'scope','global',
      'role',v_role,'permission_key',v_key,'is_enabled',p_is_enabled);
  END IF;

  v_actor_role := private.permission_role(auth.uid(),p_lounge_id);
  IF v_actor_role IS NULL OR v_actor_role NOT IN ('super_admin','owner','manager') THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;
  IF v_actor_role <> 'super_admin'
     AND NOT public.has_lounge_permission(p_lounge_id,'staff_manage') THEN
    RAISE EXCEPTION 'Missing staff_manage permission' USING ERRCODE = '42501';
  END IF;
  IF v_role = 'super_admin' THEN
    RAISE EXCEPTION 'Super admin permissions are global-only' USING ERRCODE = '42501';
  END IF;
  IF v_role = 'owner' AND v_actor_role <> 'super_admin' THEN
    RAISE EXCEPTION 'Only a super admin can change owner permissions'
      USING ERRCODE = '42501';
  END IF;
  IF v_actor_role = 'manager' THEN
    IF v_role NOT IN ('cashier','staff') THEN
      RAISE EXCEPTION 'Managers can only edit cashier or staff permissions'
        USING ERRCODE = '42501';
    END IF;
    IF p_is_enabled AND NOT public.has_lounge_permission(p_lounge_id,v_key) THEN
      RAISE EXCEPTION 'Cannot delegate a permission the manager does not hold'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(
    'role_permission:' || p_lounge_id::text || ':' || v_role || ':' || v_key, 0));
  SELECT lrp.is_enabled INTO v_previous
  FROM public.lounge_role_permissions lrp
  WHERE lrp.lounge_id=p_lounge_id AND lrp.role=v_role AND lrp.permission_key=v_key;

  INSERT INTO public.lounge_role_permissions
    (lounge_id,role,permission_key,is_enabled,updated_at)
  VALUES (p_lounge_id,v_role,v_key,p_is_enabled,now())
  ON CONFLICT (lounge_id,role,permission_key)
  DO UPDATE SET is_enabled=EXCLUDED.is_enabled, updated_at=now();

  INSERT INTO public.permission_audit_logs
    (lounge_id,actor_user_id,target_role,permission_key,old_value,new_value)
  VALUES (p_lounge_id,auth.uid(),v_role,v_key,v_previous,p_is_enabled);
  RETURN jsonb_build_object('success',true,'scope','lounge',
    'lounge_id',p_lounge_id,'role',v_role,
    'permission_key',v_key,'is_enabled',p_is_enabled);
END;
$function$;

COMMIT;


-- -----------------------------------------------------------------------------
-- END MIGRATION: 20261025151217_owner_permission_write_boundary.sql
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- START MIGRATION: 20261025170000_guard_pre_session_manual_transfer_total.sql
-- -----------------------------------------------------------------------------

-- The legacy approval RPC settles the entire expected price even when the
-- booking requires only a reservation deposit. Keep that unsafe transition
-- closed until a verified deposit and mixed-method ledger is deployed.
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.approve_manual_booking(uuid,uuid)'::regprocedure))
       <> '7ddf3f2bd80fbb013ee008747d72c61b'
     OR md5(pg_get_functiondef('public.complete_booking_payment(uuid,text,numeric)'::regprocedure))
       <> 'b2cea5fe275757100336f2b57f3ce53b' THEN
    RAISE EXCEPTION 'MANUAL_TRANSFER_CONTRACT_DRIFT';
  END IF;
END;
$guard$;

CREATE FUNCTION private.guard_pre_session_manual_transfer_total()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $function$
DECLARE
  v_status public.booking_status;
  v_total numeric;
BEGIN
  IF NEW.status <> 'completed' OR NEW.payment_method <> 'manual_transfer'
     OR NEW.booking_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT status, total_price INTO v_status, v_total
  FROM public.bookings WHERE id = NEW.booking_id;
  IF FOUND AND v_status IN ('pending', 'upcoming', 'in_progress')
     AND v_total > 0 AND NEW.amount >= v_total THEN
    RAISE EXCEPTION 'PRE_SESSION_MANUAL_TRANSFER_REQUIRES_VERIFIED_DEPOSIT_CONTRACT'
      USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.guard_pre_session_manual_transfer_total()
  FROM PUBLIC, anon, authenticated;
CREATE TRIGGER guard_pre_session_manual_transfer_total
BEFORE INSERT OR UPDATE OF amount, payment_method, status ON public.payments
FOR EACH ROW EXECUTE FUNCTION private.guard_pre_session_manual_transfer_total();


-- -----------------------------------------------------------------------------
-- END MIGRATION: 20261025170000_guard_pre_session_manual_transfer_total.sql
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- START MIGRATION: 20261025225255_canonical_booking_collections.sql
-- -----------------------------------------------------------------------------

-- Draft method-specific booking money movements with authorized deposit and
-- mixed cash collection writers. Existing payments remain the aggregate
-- projection. Payouts, refunds and clients require a coordinated release.
CREATE TABLE private.booking_money_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_id uuid NOT NULL UNIQUE,
  booking_id uuid NOT NULL REFERENCES public.bookings(id),
  payment_id uuid NOT NULL REFERENCES public.payments(id),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id),
  shift_id uuid NOT NULL REFERENCES public.shifts(id),
  shift_payment_id uuid UNIQUE REFERENCES public.shift_payments(id),
  movement_type text NOT NULL CHECK (movement_type IN ('collection', 'refund')),
  collection_purpose text NOT NULL CHECK (collection_purpose IN ('deposit', 'settlement', 'partial', 'refund')),
  payment_method text NOT NULL CHECK (payment_method IN
    ('cash', 'manual_transfer', 'card', 'vodafone_cash', 'fawry', 'instapay', 'app_wallet')),
  amount_minor bigint NOT NULL,
  commission_minor bigint NOT NULL,
  net_to_lounge_minor bigint GENERATED ALWAYS AS (amount_minor - commission_minor) STORED,
  funds_holder text NOT NULL CHECK (funds_holder IN ('platform', 'lounge')),
  evidence_reference text,
  reversal_of uuid REFERENCES private.booking_money_movements(id),
  verified_by uuid NOT NULL REFERENCES auth.users(id),
  verified_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT booking_money_movement_shape CHECK (
    (movement_type = 'collection' AND amount_minor > 0
      AND commission_minor >= 0 AND commission_minor <= amount_minor
      AND reversal_of IS NULL AND shift_payment_id IS NOT NULL
      AND collection_purpose <> 'refund')
    OR
    (movement_type = 'refund' AND amount_minor < 0
      AND commission_minor <= 0 AND commission_minor >= amount_minor
      AND reversal_of IS NOT NULL AND shift_payment_id IS NULL
      AND collection_purpose = 'refund')
  ),
  CONSTRAINT booking_money_movement_cash_custody CHECK (
    payment_method <> 'cash' OR funds_holder = 'lounge'
  ),
  CONSTRAINT booking_money_movement_evidence CHECK (
    (movement_type = 'collection' AND payment_method = 'cash')
    OR (evidence_reference IS NOT NULL
      AND length(trim(evidence_reference)) BETWEEN 1 AND 500)
  )
);

CREATE INDEX booking_money_movements_booking_time
  ON private.booking_money_movements (booking_id, verified_at, id);
CREATE INDEX booking_money_movements_lounge_time
  ON private.booking_money_movements (lounge_id, verified_at, id);
CREATE INDEX booking_money_movements_shift
  ON private.booking_money_movements (shift_id, verified_at, id);
CREATE INDEX booking_money_movements_payment
  ON private.booking_money_movements (payment_id, id);
CREATE INDEX booking_money_movements_reversal
  ON private.booking_money_movements (reversal_of) WHERE reversal_of IS NOT NULL;

ALTER TABLE private.booking_money_movements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.booking_money_movements
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

-- Payout allocation is separate so money movements stay immutable. An entry
-- can be retried after a failed/cancelled payout while retaining its history.
CREATE TABLE private.booking_movement_payout_entries (
  payout_id uuid NOT NULL REFERENCES public.payouts(id),
  movement_id uuid NOT NULL REFERENCES private.booking_money_movements(id),
  contribution_minor bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (payout_id, movement_id)
);
CREATE INDEX booking_movement_payout_entries_payout
  ON private.booking_movement_payout_entries (payout_id);
CREATE INDEX booking_movement_payout_entries_movement
  ON private.booking_movement_payout_entries (movement_id);
ALTER TABLE private.booking_movement_payout_entries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.booking_movement_payout_entries
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE FUNCTION private.reject_booking_money_movement_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path TO '' AS $function$
BEGIN
  RAISE EXCEPTION 'BOOKING_MONEY_MOVEMENTS_ARE_APPEND_ONLY' USING ERRCODE = '55000';
END;
$function$;
REVOKE ALL ON FUNCTION private.reject_booking_money_movement_mutation()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
CREATE TRIGGER booking_money_movements_append_only
BEFORE UPDATE OR DELETE ON private.booking_money_movements
FOR EACH ROW EXECUTE FUNCTION private.reject_booking_money_movement_mutation();

CREATE FUNCTION private.validate_booking_money_movement()
RETURNS trigger LANGUAGE plpgsql SET search_path TO '' AS $function$
DECLARE
  v_payment public.payments%ROWTYPE;
  v_shift_payment public.shift_payments%ROWTYPE;
  v_original private.booking_money_movements%ROWTYPE;
  v_refunded_minor bigint;
  v_refunded_commission_minor bigint;
BEGIN
  SELECT * INTO v_payment FROM public.payments WHERE id = NEW.payment_id;
  IF NOT FOUND OR v_payment.booking_id IS DISTINCT FROM NEW.booking_id
    OR v_payment.lounge_id IS DISTINCT FROM NEW.lounge_id THEN
    RAISE EXCEPTION 'MOVEMENT_PAYMENT_SCOPE_MISMATCH' USING ERRCODE = '23514';
  END IF;
  PERFORM 1 FROM public.bookings b WHERE b.id = NEW.booking_id
    AND b.lounge_id = NEW.lounge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MOVEMENT_BOOKING_SCOPE_MISMATCH' USING ERRCODE = '23514';
  END IF;
  PERFORM 1 FROM public.shifts s WHERE s.id = NEW.shift_id
    AND s.lounge_id = NEW.lounge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MOVEMENT_SHIFT_SCOPE_MISMATCH' USING ERRCODE = '23514';
  END IF;

  IF NEW.movement_type = 'collection' THEN
    SELECT * INTO v_shift_payment FROM public.shift_payments
    WHERE id = NEW.shift_payment_id;
    IF NOT FOUND OR v_shift_payment.booking_id IS DISTINCT FROM NEW.booking_id
      OR v_shift_payment.lounge_id IS DISTINCT FROM NEW.lounge_id
      OR v_shift_payment.shift_id IS DISTINCT FROM NEW.shift_id
      OR v_shift_payment.payment_method IS DISTINCT FROM NEW.payment_method
      OR v_shift_payment.amount * 100 IS DISTINCT FROM NEW.amount_minor THEN
      RAISE EXCEPTION 'MOVEMENT_SHIFT_EVIDENCE_MISMATCH' USING ERRCODE = '23514';
    END IF;
  ELSE
    -- Lock the original movement to serialize competing refund confirmations.
    SELECT * INTO v_original FROM private.booking_money_movements
    WHERE id = NEW.reversal_of FOR UPDATE;
    IF NOT FOUND OR v_original.movement_type <> 'collection'
      OR v_original.booking_id IS DISTINCT FROM NEW.booking_id
      OR v_original.payment_id IS DISTINCT FROM NEW.payment_id
      OR v_original.lounge_id IS DISTINCT FROM NEW.lounge_id THEN
      RAISE EXCEPTION 'REFUND_COLLECTION_SCOPE_MISMATCH' USING ERRCODE = '23514';
    END IF;
    SELECT COALESCE(-sum(amount_minor), 0), COALESCE(-sum(commission_minor), 0)
      INTO v_refunded_minor, v_refunded_commission_minor
    FROM private.booking_money_movements
    WHERE reversal_of = NEW.reversal_of;
    IF v_refunded_minor - NEW.amount_minor > v_original.amount_minor
      OR v_refunded_commission_minor - NEW.commission_minor > v_original.commission_minor THEN
      RAISE EXCEPTION 'REFUND_EXCEEDS_VERIFIED_COLLECTION' USING ERRCODE = '22023';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.validate_booking_money_movement()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
CREATE TRIGGER booking_money_movement_validate
BEFORE INSERT ON private.booking_money_movements
FOR EACH ROW EXECUTE FUNCTION private.validate_booking_money_movement();

CREATE FUNCTION private.validate_booking_movement_payout_entry()
RETURNS trigger LANGUAGE plpgsql SET search_path TO '' AS $function$
DECLARE
  v_movement private.booking_money_movements%ROWTYPE;
  v_lounge_id uuid;
  v_payout_status text;
  v_expected bigint;
BEGIN
  SELECT * INTO v_movement FROM private.booking_money_movements
    WHERE id = NEW.movement_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PAYOUT_MOVEMENT_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;
  IF EXISTS (
    SELECT 1 FROM private.booking_movement_payout_entries e
    JOIN public.payouts p ON p.id = e.payout_id
    WHERE e.movement_id = NEW.movement_id
      AND p.status IN ('pending', 'approved', 'processing', 'paid', 'needs_review')
  ) THEN
    RAISE EXCEPTION 'MOVEMENT_ALREADY_IN_ACTIVE_PAYOUT' USING ERRCODE = '55000';
  END IF;
  SELECT lounge_id, status INTO v_lounge_id, v_payout_status FROM public.payouts
    WHERE id = NEW.payout_id;
  IF NOT FOUND OR v_lounge_id IS DISTINCT FROM v_movement.lounge_id
    OR v_payout_status IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'PAYOUT_MOVEMENT_LOUNGE_MISMATCH' USING ERRCODE = '23514';
  END IF;
  v_expected := CASE WHEN v_movement.funds_holder = 'platform'
    THEN v_movement.net_to_lounge_minor ELSE -v_movement.commission_minor END;
  IF NEW.contribution_minor IS DISTINCT FROM v_expected THEN
    RAISE EXCEPTION 'PAYOUT_MOVEMENT_CONTRIBUTION_MISMATCH' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.validate_booking_movement_payout_entry()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
CREATE TRIGGER booking_movement_payout_entry_validate
BEFORE INSERT ON private.booking_movement_payout_entries
FOR EACH ROW EXECUTE FUNCTION private.validate_booking_movement_payout_entry();
CREATE TRIGGER booking_movement_payout_entries_append_only
BEFORE UPDATE OR DELETE ON private.booking_movement_payout_entries
FOR EACH ROW EXECUTE FUNCTION private.reject_booking_money_movement_mutation();

-- A private reconciliation surface for the migration cohort. The legacy
-- aggregate method is intentionally absent: reports must use the movements.
CREATE VIEW private.booking_money_coverage
WITH (security_invoker = true) AS
SELECT p.id AS payment_id, p.booking_id, p.lounge_id,
  (p.amount * 100)::bigint AS aggregate_gross_minor,
  COALESCE(sum(m.amount_minor) FILTER (WHERE m.movement_type = 'collection'), 0)::bigint
    AS movement_gross_minor,
  COALESCE(sum(m.amount_minor) FILTER (WHERE m.movement_type = 'refund'), 0)::bigint
    AS refunded_minor,
  count(m.id) FILTER (WHERE m.movement_type = 'collection')::integer
    AS collection_count,
  CASE
    WHEN count(m.id) = 0 THEN 'legacy_unclassified'
    WHEN COALESCE(sum(m.amount_minor) FILTER (WHERE m.movement_type = 'collection'), 0)
      IS DISTINCT FROM p.amount * 100 THEN 'requires_reconciliation'
    ELSE 'covered'
  END AS coverage_state
FROM public.payments p
LEFT JOIN private.booking_money_movements m ON m.payment_id = p.id
GROUP BY p.id, p.booking_id, p.lounge_id, p.amount;
REVOKE ALL ON private.booking_money_coverage
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

-- Staff attests that the transfer has actually arrived. The submitted receipt
-- remains only evidence until this authorized transaction commits.
CREATE OR REPLACE FUNCTION public.verify_booking_deposit_transfer(
  p_booking_id uuid, p_shift_id uuid, p_operation_id uuid,
  p_evidence_reference text, p_funds_holder text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_existing private.booking_money_movements%ROWTYPE;
  v_payment public.payments%ROWTYPE;
  v_shift_payment uuid;
  v_amount numeric;
  v_amount_minor bigint;
  v_rate numeric;
  v_commission numeric;
  v_commission_minor bigint;
  v_method text;
  v_result jsonb;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '28000';
  END IF;
  IF p_booking_id IS NULL OR p_shift_id IS NULL OR p_operation_id IS NULL
    OR p_funds_holder NOT IN ('platform','lounge')
    OR p_funds_holder IS NULL OR p_evidence_reference IS NULL
    OR length(trim(p_evidence_reference)) NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'INVALID_DEPOSIT_VERIFICATION_REQUEST' USING ERRCODE = '22023';
  END IF;
  -- A lounge cashier can attest only to the account they can reconcile.
  -- Platform-held transfers need a separate platform-finance verifier.
  IF p_funds_holder='platform' THEN
    RAISE EXCEPTION 'PLATFORM_DEPOSIT_REQUIRES_PLATFORM_VERIFICATION'
      USING ERRCODE='42501';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_booking_id::text,0));
  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;
  PERFORM private.assert_cash_collector(v_actor,v_booking.lounge_id);
  SELECT * INTO v_existing FROM private.booking_money_movements
    WHERE operation_id=p_operation_id;
  IF FOUND THEN
    IF v_existing.booking_id IS DISTINCT FROM p_booking_id
      OR v_existing.shift_id IS DISTINCT FROM p_shift_id
      OR v_existing.verified_by IS DISTINCT FROM v_actor
      OR v_existing.collection_purpose IS DISTINCT FROM 'deposit'
      OR v_existing.evidence_reference IS DISTINCT FROM trim(p_evidence_reference)
      OR v_existing.funds_holder IS DISTINCT FROM p_funds_holder THEN
      RAISE EXCEPTION 'DEPOSIT_VERIFICATION_REPLAY_CONFLICT' USING ERRCODE = '22023';
    END IF;
    RETURN jsonb_build_object('operation_id',p_operation_id,
      'movement_id',v_existing.id,'booking_id',p_booking_id,
      'shift_id',p_shift_id,'payment_method',v_existing.payment_method,
      'collected_minor',v_existing.amount_minor,
      'commission_minor',v_existing.commission_minor,'replayed',true);
  END IF;
  PERFORM private.lock_cash_collection_shift(p_shift_id,v_booking.lounge_id);
  v_method := v_booking.payment_method;
  IF v_booking.confirmation_status IS DISTINCT FROM 'confirmed'
    OR v_booking.status::text NOT IN ('pending','upcoming')
    OR v_booking.deposit_required IS NOT TRUE
    OR v_booking.deposit_paid IS TRUE
    OR v_method IS NULL
    OR v_method NOT IN ('manual_transfer','instapay','vodafone_cash','app_wallet')
    OR NULLIF(trim(COALESCE(v_booking.receipt_url,'')),'') IS NULL THEN
    RAISE EXCEPTION 'BOOKING_NOT_READY_FOR_VERIFIED_DEPOSIT' USING ERRCODE = '55000';
  END IF;
  v_amount := v_booking.deposit_amount;
  IF v_booking.total_price IS NULL
    OR v_booking.total_price::text IN ('NaN','Infinity','-Infinity')
    OR v_amount IS NULL OR v_amount::text IN ('NaN','Infinity','-Infinity')
    OR v_amount <= 0 OR v_amount >= v_booking.total_price
    OR v_amount <> round(v_amount,2) THEN
    RAISE EXCEPTION 'INVALID_SERVER_DEPOSIT_AMOUNT' USING ERRCODE = '22023';
  END IF;
  v_amount_minor := (v_amount*100)::bigint;
  IF EXISTS (SELECT 1 FROM public.shift_payments
      WHERE booking_id=p_booking_id)
    OR EXISTS (SELECT 1 FROM private.booking_money_movements
      WHERE booking_id=p_booking_id) THEN
    RAISE EXCEPTION 'DEPOSIT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
  END IF;
  SELECT * INTO v_payment FROM public.payments
    WHERE booking_id=p_booking_id FOR UPDATE;
  IF FOUND AND (v_payment.status='completed'
    OR v_payment.payout_id IS NOT NULL
    OR v_payment.lounge_id IS DISTINCT FROM v_booking.lounge_id) THEN
    RAISE EXCEPTION 'DEPOSIT_REQUIRES_RECONCILIATION' USING ERRCODE = '55000';
  END IF;
  v_rate := private.platform_commission_rate();
  IF v_rate IS NULL OR v_rate NOT BETWEEN 0 AND 1
    OR v_rate::text IN ('NaN','Infinity','-Infinity') THEN
    RAISE EXCEPTION 'INVALID_COMMISSION_POLICY' USING ERRCODE = '55000';
  END IF;
  v_commission := round(v_amount*v_rate,2);
  v_commission_minor := (v_commission*100)::bigint;
  INSERT INTO private.cash_collection_context(transaction_id,booking_id)
    VALUES(txid_current(),p_booking_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.payments(booking_id,user_id,lounge_id,amount,
    commission_rate,commission,net_to_lounge,payment_method,status,paid_at)
  VALUES(p_booking_id,v_booking.user_id,v_booking.lounge_id,v_amount,
    v_rate,v_commission,v_amount-v_commission,v_method,'completed',now())
  ON CONFLICT(booking_id) DO UPDATE SET
    amount=EXCLUDED.amount,commission_rate=EXCLUDED.commission_rate,
    commission=EXCLUDED.commission,net_to_lounge=EXCLUDED.net_to_lounge,
    payment_method=EXCLUDED.payment_method,status=EXCLUDED.status,
    paid_at=EXCLUDED.paid_at
  RETURNING * INTO v_payment;
  INSERT INTO public.shift_payments(shift_id,lounge_id,booking_id,
    payment_method,category,amount,paid_at)
  VALUES(p_shift_id,v_booking.lounge_id,p_booking_id,v_method,
    'gaming_time',v_amount,now()) RETURNING id INTO v_shift_payment;
  INSERT INTO private.booking_money_movements(operation_id,booking_id,
    payment_id,lounge_id,shift_id,shift_payment_id,movement_type,
    collection_purpose,payment_method,amount_minor,commission_minor,
    funds_holder,evidence_reference,verified_by)
  VALUES(p_operation_id,p_booking_id,v_payment.id,v_booking.lounge_id,
    p_shift_id,v_shift_payment,'collection','deposit',v_method,
    v_amount_minor,v_commission_minor,p_funds_holder,
    trim(p_evidence_reference),v_actor)
  RETURNING * INTO v_existing;
  UPDATE public.bookings SET deposit_paid=true,payment_status='partial',
    updated_at=now() WHERE id=p_booking_id;
  DELETE FROM private.cash_collection_context
    WHERE transaction_id=txid_current() AND booking_id=p_booking_id;
  v_result := jsonb_build_object('operation_id',p_operation_id,
    'movement_id',v_existing.id,'booking_id',p_booking_id,
    'shift_id',p_shift_id,'payment_method',v_method,
    'collected_minor',v_amount_minor,
    'commission_minor',v_commission_minor,'replayed',false);
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.verify_booking_deposit_transfer(uuid,uuid,uuid,text,text)
  FROM PUBLIC, anon, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.verify_booking_deposit_transfer(uuid,uuid,uuid,text,text)
  TO authenticated;

-- Old clients can still call complete_booking_payment/approve_manual_booking.
-- Prevent them from promoting an expected full price into a collection for a
-- future deposit booking, or overwriting an already movement-backed payment.
CREATE FUNCTION private.guard_canonical_booking_payment_write()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_booking_id uuid;
  v_booking public.bookings%ROWTYPE;
BEGIN
  v_booking_id:=CASE WHEN TG_OP='DELETE' THEN OLD.booking_id
    ELSE NEW.booking_id END;
  SELECT * INTO v_booking FROM public.bookings WHERE id=v_booking_id;
  IF FOUND AND (
    EXISTS (SELECT 1 FROM private.booking_money_movements
      WHERE booking_id=v_booking_id)
    OR (v_booking.deposit_required IS TRUE
      AND v_booking.deposit_paid IS NOT TRUE
      AND v_booking.status::text IN ('pending','upcoming'))
  ) AND NOT EXISTS (SELECT 1 FROM private.cash_collection_context
      WHERE transaction_id=txid_current() AND booking_id=v_booking_id) THEN
    RAISE EXCEPTION 'CANONICAL_BOOKING_PAYMENT_WRITER_REQUIRED'
      USING ERRCODE='55000';
  END IF;
  RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END;
$function$;
REVOKE ALL ON FUNCTION private.guard_canonical_booking_payment_write()
  FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;
CREATE TRIGGER guard_canonical_booking_payment_write
BEFORE INSERT OR UPDATE OR DELETE ON public.payments
FOR EACH ROW EXECUTE FUNCTION private.guard_canonical_booking_payment_write();

-- The aggregate payment method becomes an explicit compatibility marker once
-- more than one method has actually been collected for a booking. Payout and
-- reporting must use booking_money_movements for these rows.
ALTER TABLE public.payments DROP CONSTRAINT payments_payment_method_check;
ALTER TABLE public.payments ADD CONSTRAINT payments_payment_method_check
  CHECK (payment_method IN ('cash','manual_transfer','card','vodafone_cash',
    'fawry','instapay','app_wallet','mixed'));
ALTER TABLE public.bookings DROP CONSTRAINT bookings_payment_method_check;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_payment_method_check
  CHECK (payment_method IN ('cash','manual_transfer','card','vodafone_cash',
    'fawry','instapay','app_wallet','mixed'));

CREATE OR REPLACE FUNCTION private.cash_collection_paid_amount(
  p_booking_id uuid,p_lounge_id uuid,p_payment_status text)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_payment public.payments%ROWTYPE;
  v_cash numeric;
  v_shift_gross numeric;
  v_movement_gross bigint;
  v_movement_count bigint;
BEGIN
  SELECT * INTO v_payment FROM public.payments
    WHERE booking_id=p_booking_id FOR UPDATE;
  SELECT count(*),COALESCE(sum(amount_minor),0)
    INTO v_movement_count,v_movement_gross
  FROM private.booking_money_movements
  WHERE booking_id=p_booking_id AND movement_type='collection';
  IF v_movement_count>0 THEN
    SELECT COALESCE(sum(amount),0) INTO v_shift_gross
    FROM public.shift_payments
    WHERE booking_id=p_booking_id AND lounge_id=p_lounge_id
      AND category='gaming_time';
    IF v_payment.id IS NULL OR v_payment.status IS DISTINCT FROM 'completed'
      OR v_payment.lounge_id IS DISTINCT FROM p_lounge_id
      OR v_payment.payout_id IS NOT NULL
      OR v_payment.amount IS NULL OR v_payment.amount<0
      OR v_payment.amount::text IN ('NaN','Infinity','-Infinity')
      OR v_payment.amount<>round(v_payment.amount,2)
      OR v_payment.amount*100 IS DISTINCT FROM v_movement_gross
      OR v_shift_gross*100 IS DISTINCT FROM v_movement_gross
      OR EXISTS (SELECT 1 FROM private.booking_money_movements
        WHERE booking_id=p_booking_id AND movement_type='refund') THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
    END IF;
    RETURN v_payment.amount;
  END IF;
  SELECT COALESCE(sum(amount),0) INTO v_cash FROM public.shift_payments
    WHERE booking_id=p_booking_id AND lounge_id=p_lounge_id
      AND payment_method='cash';
  IF v_payment.id IS NOT NULL THEN
    IF v_payment.payment_method IS DISTINCT FROM 'cash'
      OR v_payment.status IS DISTINCT FROM 'completed'
      OR v_payment.lounge_id IS DISTINCT FROM p_lounge_id
      OR v_payment.payout_id IS NOT NULL OR v_payment.amount IS NULL
      OR v_payment.amount<0 OR v_payment.amount::text IN ('NaN','Infinity','-Infinity')
      OR v_payment.amount<>round(v_payment.amount,2)
      OR v_payment.amount IS DISTINCT FROM v_cash THEN
      RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
    END IF;
    RETURN v_payment.amount;
  ELSIF p_payment_status IS DISTINCT FROM 'unpaid' OR v_cash<>0 THEN
    RAISE EXCEPTION 'PAYMENT_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  RETURN 0;
END;
$function$;

CREATE OR REPLACE FUNCTION private.apply_partial_cash_collection_with_movement(
  p_booking_id uuid,p_shift_id uuid,p_amount_minor numeric,p_operation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_lounge_id uuid;
  v_allow_cash boolean;
  v_old_payment public.payments%ROWTYPE;
  v_payment public.payments%ROWTYPE;
  v_has_movements boolean;
  v_has_electronic boolean;
  v_shift_payment_id uuid;
  v_movement_id uuid;
  v_rate numeric;
  v_new_commission_minor bigint;
  v_prior_commission_minor bigint;
  v_booking public.bookings%ROWTYPE;
  v_paid numeric;
  v_amount numeric;
BEGIN
  SELECT lounge_id INTO v_lounge_id FROM public.bookings WHERE id=p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE='P0002';
  END IF;
  SELECT allow_cash_payment INTO v_allow_cash FROM public.lounges
    WHERE id=v_lounge_id;
  IF v_allow_cash IS NOT TRUE THEN
    RAISE EXCEPTION 'CASH_COLLECTION_DISABLED' USING ERRCODE='42501';
  END IF;
  SELECT EXISTS(SELECT 1 FROM private.booking_money_movements
    WHERE booking_id=p_booking_id AND movement_type='collection'),
    EXISTS(SELECT 1 FROM private.booking_money_movements
    WHERE booking_id=p_booking_id AND movement_type='collection'
      AND payment_method<>'cash')
    INTO v_has_movements,v_has_electronic;
  SELECT * INTO v_old_payment FROM public.payments
    WHERE booking_id=p_booking_id FOR UPDATE;
  -- Historical cash rows without movement evidence remain on their existing
  -- writer. Do not backfill a partial history by pretending it is complete.
  IF v_old_payment.id IS NOT NULL AND v_has_movements IS FALSE THEN
    RETURN private.apply_partial_cash_collection(p_booking_id,p_shift_id,p_amount_minor);
  END IF;
  v_rate:=private.platform_commission_rate();
  IF v_rate IS NULL OR v_rate NOT BETWEEN 0 AND 1
    OR v_rate::text IN ('NaN','Infinity','-Infinity')
    OR (v_has_movements AND v_old_payment.commission_rate IS DISTINCT FROM v_rate) THEN
    RAISE EXCEPTION 'MIXED_COMMISSION_POLICY_REQUIRES_RECONCILIATION'
      USING ERRCODE='55000';
  END IF;
  v_new_commission_minor:=
    (round((p_amount_minor/100)*v_rate,2)*100)::bigint;
  SELECT COALESCE(sum(commission_minor),0) INTO v_prior_commission_minor
  FROM private.booking_money_movements
  WHERE booking_id=p_booking_id AND movement_type='collection';
  v_booking:=private.lock_cash_collection_booking(p_booking_id);
  PERFORM private.lock_cash_collection_shift(p_shift_id,v_booking.lounge_id);
  v_paid:=private.cash_collection_paid_amount(
    p_booking_id,v_booking.lounge_id,v_booking.payment_status);
  v_amount:=p_amount_minor/100;
  IF v_amount>v_booking.total_price-v_paid THEN
    RAISE EXCEPTION 'CASH_EXCEEDS_OUTSTANDING_BALANCE' USING ERRCODE='22023';
  END IF;
  INSERT INTO private.cash_collection_context(transaction_id,booking_id)
    VALUES(txid_current(),p_booking_id) ON CONFLICT DO NOTHING;
  INSERT INTO public.payments(booking_id,user_id,lounge_id,amount,
    commission_rate,commission,net_to_lounge,payment_method,status,paid_at)
  VALUES(p_booking_id,v_booking.user_id,v_booking.lounge_id,v_paid+v_amount,
    v_rate,round((v_paid+v_amount)*v_rate,2),
    v_paid+v_amount-round((v_paid+v_amount)*v_rate,2),
    CASE WHEN v_has_electronic THEN 'mixed' ELSE 'cash' END,
    'completed',now())
  ON CONFLICT(booking_id) DO UPDATE SET amount=EXCLUDED.amount,
    commission_rate=EXCLUDED.commission_rate,
    commission=EXCLUDED.commission,net_to_lounge=EXCLUDED.net_to_lounge,
    payment_method=EXCLUDED.payment_method,paid_at=EXCLUDED.paid_at;
  INSERT INTO public.shift_payments(shift_id,lounge_id,booking_id,
    payment_method,category,amount,paid_at)
  VALUES(p_shift_id,v_booking.lounge_id,p_booking_id,'cash',
    'gaming_time',v_amount,now()) RETURNING id INTO v_shift_payment_id;
  UPDATE public.bookings SET
    payment_status=CASE WHEN v_paid+v_amount=total_price THEN 'paid'
      ELSE 'partial' END,
    payment_method=CASE WHEN v_has_electronic THEN 'mixed' ELSE 'cash' END,
    updated_at=now() WHERE id=p_booking_id;
  DELETE FROM private.cash_collection_context
    WHERE transaction_id=txid_current() AND booking_id=p_booking_id;
  SELECT * INTO STRICT v_payment FROM public.payments
    WHERE booking_id=p_booking_id;
  IF v_payment.commission*100 IS DISTINCT FROM
      v_prior_commission_minor+v_new_commission_minor THEN
    RAISE EXCEPTION 'MIXED_COMMISSION_ALLOCATION_CONFLICT' USING ERRCODE='55000';
  END IF;
  INSERT INTO private.booking_money_movements(operation_id,booking_id,
    payment_id,lounge_id,shift_id,shift_payment_id,movement_type,
    collection_purpose,payment_method,amount_minor,commission_minor,
    funds_holder,verified_by)
  VALUES(p_operation_id,p_booking_id,v_payment.id,v_lounge_id,p_shift_id,
    v_shift_payment_id,'collection','settlement','cash',p_amount_minor::bigint,
    v_new_commission_minor,'lounge',auth.uid())
  RETURNING id INTO v_movement_id;
  RETURN jsonb_build_object('booking_id',p_booking_id,'lounge_id',
    v_booking.lounge_id,'shift_id',p_shift_id,
    'shift_payment_id',v_shift_payment_id,'collected_minor',p_amount_minor,
    'paid_minor',(v_paid+v_amount)*100,
    'due_minor',(v_booking.total_price-v_paid-v_amount)*100,
    'payment_status',CASE WHEN v_paid+v_amount=v_booking.total_price
      THEN 'paid' ELSE 'partial' END,'movement_id',v_movement_id);
END;
$function$;
REVOKE ALL ON FUNCTION private.apply_partial_cash_collection_with_movement(
  uuid,uuid,numeric,uuid) FROM PUBLIC,anon,authenticated,service_role,supabase_auth_admin;

CREATE OR REPLACE FUNCTION public.collect_booking_cash_partial(
  p_booking_id uuid,p_shift_id uuid,p_amount_minor numeric,p_operation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE v_receipt private.cash_collection_receipts%ROWTYPE;v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000'; END IF;
  IF p_operation_id IS NULL OR p_booking_id IS NULL OR p_shift_id IS NULL OR p_amount_minor IS NULL
    OR p_amount_minor::text IN ('NaN','Infinity','-Infinity') OR p_amount_minor<=0
    OR p_amount_minor<>trunc(p_amount_minor) OR p_amount_minor>9007199254740991 THEN
    RAISE EXCEPTION 'INVALID_CASH_COLLECTION_REQUEST' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_booking_id::text,0));
  INSERT INTO private.cash_collection_receipts(operation_id,actor_id,booking_id,shift_id,amount_minor)
    VALUES(p_operation_id,auth.uid(),p_booking_id,p_shift_id,p_amount_minor) ON CONFLICT DO NOTHING;
  SELECT * INTO STRICT v_receipt FROM private.cash_collection_receipts
    WHERE operation_id=p_operation_id FOR UPDATE;
  IF v_receipt.actor_id IS DISTINCT FROM auth.uid() OR v_receipt.booking_id IS DISTINCT FROM p_booking_id
    OR v_receipt.shift_id IS DISTINCT FROM p_shift_id OR v_receipt.amount_minor IS DISTINCT FROM p_amount_minor THEN
    RAISE EXCEPTION 'CASH_COLLECTION_REPLAY_CONFLICT' USING ERRCODE='22023';
  END IF;
  IF v_receipt.result IS NOT NULL THEN
    PERFORM private.assert_cash_collector(auth.uid(),(v_receipt.result->>'lounge_id')::uuid);
    RETURN v_receipt.result||jsonb_build_object('replayed',true);
  END IF;
  v_result:=private.apply_partial_cash_collection_with_movement(
    p_booking_id,p_shift_id,p_amount_minor,p_operation_id)
    ||jsonb_build_object('operation_id',p_operation_id,'replayed',false);
  UPDATE private.cash_collection_receipts SET result=v_result
    WHERE operation_id=p_operation_id;
  RETURN v_result;
END;
$function$;


-- -----------------------------------------------------------------------------
-- END MIGRATION: 20261025225255_canonical_booking_collections.sql
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- START MIGRATION: 20261025225913_branch_booking_refund_policy.sql
-- -----------------------------------------------------------------------------

-- Branch owners choose the cancellation cutoff and refundable percentage.
-- No cancellation RPC or money movement is changed here: eligibility is not
-- evidence that a manual refund was actually paid.
CREATE TABLE private.booking_refund_policy_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  operation_id uuid NOT NULL UNIQUE,
  lounge_id uuid NOT NULL REFERENCES public.lounges(id),
  cutoff_minutes_before_start integer NOT NULL
    CHECK (cutoff_minutes_before_start BETWEEN 0 AND 43200),
  refund_percentage numeric(5,2) NOT NULL
    CHECK (refund_percentage BETWEEN 0 AND 100),
  configured_by uuid NOT NULL REFERENCES auth.users(id),
  configured_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX booking_refund_policy_versions_latest
  ON private.booking_refund_policy_versions (lounge_id, version DESC);
ALTER TABLE private.booking_refund_policy_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.booking_refund_policy_versions
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;

CREATE FUNCTION private.reject_booking_refund_policy_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path TO '' AS $function$
BEGIN
  RAISE EXCEPTION 'REFUND_POLICY_VERSION_IS_IMMUTABLE' USING ERRCODE = '55000';
END;
$function$;
REVOKE ALL ON FUNCTION private.reject_booking_refund_policy_mutation()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
CREATE TRIGGER booking_refund_policy_versions_append_only
BEFORE UPDATE OR DELETE ON private.booking_refund_policy_versions
FOR EACH ROW EXECUTE FUNCTION private.reject_booking_refund_policy_mutation();

ALTER TABLE public.bookings ADD COLUMN refund_policy_version_id uuid
  REFERENCES private.booking_refund_policy_versions(id);

CREATE FUNCTION private.snapshot_booking_refund_policy()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
BEGIN
  SELECT p.id INTO NEW.refund_policy_version_id
  FROM private.booking_refund_policy_versions p
  WHERE p.lounge_id = NEW.lounge_id
  ORDER BY p.version DESC LIMIT 1;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.snapshot_booking_refund_policy()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
CREATE TRIGGER zz_snapshot_booking_refund_policy
BEFORE INSERT ON public.bookings
FOR EACH ROW EXECUTE FUNCTION private.snapshot_booking_refund_policy();

CREATE FUNCTION private.guard_booking_refund_policy_snapshot()
RETURNS trigger LANGUAGE plpgsql SET search_path TO '' AS $function$
BEGIN
  IF NEW.refund_policy_version_id IS DISTINCT FROM OLD.refund_policy_version_id THEN
    RAISE EXCEPTION 'BOOKING_REFUND_POLICY_SNAPSHOT_IMMUTABLE' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.guard_booking_refund_policy_snapshot()
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;
CREATE TRIGGER booking_refund_policy_snapshot_immutable
BEFORE UPDATE OF refund_policy_version_id ON public.bookings
FOR EACH ROW EXECUTE FUNCTION private.guard_booking_refund_policy_snapshot();

CREATE FUNCTION public.configure_branch_booking_refund_policy(
  p_lounge_id uuid, p_cutoff_minutes_before_start integer,
  p_refund_percentage numeric, p_operation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_existing private.booking_refund_policy_versions%ROWTYPE;
  v_new private.booking_refund_policy_versions%ROWTYPE;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE = '28000';
  END IF;
  IF p_lounge_id IS NULL OR p_operation_id IS NULL
    OR p_cutoff_minutes_before_start IS NULL
    OR p_cutoff_minutes_before_start NOT BETWEEN 0 AND 43200
    OR p_refund_percentage IS NULL
    OR p_refund_percentage::text IN ('NaN','Infinity','-Infinity')
    OR p_refund_percentage NOT BETWEEN 0 AND 100
    OR p_refund_percentage <> round(p_refund_percentage, 2) THEN
    RAISE EXCEPTION 'INVALID_REFUND_POLICY' USING ERRCODE = '22023';
  END IF;
  PERFORM 1 FROM public.profiles p JOIN auth.users u ON u.id = p.id
    WHERE p.id = v_actor AND p.role = 'owner'
      AND p.is_active IS TRUE AND p.is_banned IS FALSE
    FOR SHARE OF p, u;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ACTIVE_OWNER_REQUIRED' USING ERRCODE = '42501';
  END IF;
  PERFORM 1 FROM public.lounges l
    WHERE l.id = p_lounge_id AND l.owner_id = v_actor FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BRANCH_OWNER_REQUIRED' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_existing FROM private.booking_refund_policy_versions
    WHERE operation_id = p_operation_id;
  IF FOUND THEN
    IF v_existing.lounge_id IS DISTINCT FROM p_lounge_id
      OR v_existing.configured_by IS DISTINCT FROM v_actor
      OR v_existing.cutoff_minutes_before_start IS DISTINCT FROM p_cutoff_minutes_before_start
      OR v_existing.refund_percentage IS DISTINCT FROM p_refund_percentage THEN
      RAISE EXCEPTION 'REFUND_POLICY_REPLAY_CONFLICT' USING ERRCODE = '22023';
    END IF;
    RETURN jsonb_build_object('policy_version_id', v_existing.id,
      'cutoff_minutes_before_start', v_existing.cutoff_minutes_before_start,
      'refund_percentage', v_existing.refund_percentage, 'replayed', true);
  END IF;
  INSERT INTO private.booking_refund_policy_versions
    (operation_id,lounge_id,cutoff_minutes_before_start,refund_percentage,configured_by)
  VALUES (p_operation_id,p_lounge_id,p_cutoff_minutes_before_start,
    p_refund_percentage,v_actor) RETURNING * INTO v_new;
  RETURN jsonb_build_object('policy_version_id', v_new.id,
    'cutoff_minutes_before_start', v_new.cutoff_minutes_before_start,
    'refund_percentage', v_new.refund_percentage, 'replayed', false);
END;
$function$;
REVOKE ALL ON FUNCTION public.configure_branch_booking_refund_policy(uuid,integer,numeric,uuid)
  FROM PUBLIC, anon, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.configure_branch_booking_refund_policy(uuid,integer,numeric,uuid)
  TO authenticated;

CREATE FUNCTION public.get_branch_booking_refund_policy(p_lounge_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE v_policy private.booking_refund_policy_versions%ROWTYPE;
BEGIN
  PERFORM 1 FROM public.lounges l WHERE l.id = p_lounge_id
    AND ((l.is_active IS TRUE AND l.status = 'active')
      OR l.owner_id = auth.uid());
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BRANCH_NOT_AVAILABLE' USING ERRCODE = 'P0002';
  END IF;
  SELECT * INTO v_policy FROM private.booking_refund_policy_versions
    WHERE lounge_id = p_lounge_id ORDER BY version DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('configured', false);
  END IF;
  RETURN jsonb_build_object('configured', true,
    'policy_version_id', v_policy.id,
    'cutoff_minutes_before_start', v_policy.cutoff_minutes_before_start,
    'refund_percentage', v_policy.refund_percentage);
END;
$function$;
REVOKE ALL ON FUNCTION public.get_branch_booking_refund_policy(uuid)
  FROM PUBLIC, service_role, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.get_branch_booking_refund_policy(uuid)
  TO anon, authenticated;

-- Internal policy decision only. The percentage is not a refund receipt or a
-- calculation of money owed; the verified collection ledger supplies that.
CREATE FUNCTION private.booking_refund_policy_decision(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_policy private.booking_refund_policy_versions%ROWTYPE;
  v_timezone text;
  v_start_at timestamptz;
  v_cutoff_at timestamptz;
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE = 'P0002';
  END IF;
  IF v_booking.status::text <> 'cancelled' OR v_booking.cancelled_at IS NULL THEN
    RETURN jsonb_build_object('decision', 'not_cancelled');
  END IF;
  IF v_booking.actual_start_time IS NOT NULL
    OR v_booking.open_time_started_at IS NOT NULL
    OR v_booking.checked_in_at IS NOT NULL THEN
    RETURN jsonb_build_object('decision', 'session_started',
      'eligible_percentage', 0);
  END IF;
  SELECT * INTO v_policy FROM private.booking_refund_policy_versions
    WHERE id = v_booking.refund_policy_version_id
      AND lounge_id = v_booking.lounge_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('decision', 'manual_review_no_policy_snapshot');
  END IF;
  SELECT timezone INTO v_timezone FROM public.lounges
    WHERE id = v_booking.lounge_id;
  IF v_booking.date IS NULL OR v_booking.start_time IS NULL
    OR v_timezone IS NULL THEN
    RETURN jsonb_build_object('decision', 'manual_review_missing_start');
  END IF;
  v_start_at := (v_booking.date + v_booking.start_time) AT TIME ZONE v_timezone;
  v_cutoff_at := v_start_at
    - make_interval(mins => v_policy.cutoff_minutes_before_start);
  RETURN jsonb_build_object(
    'decision', CASE WHEN v_booking.cancelled_at <= v_cutoff_at
      THEN 'eligible' ELSE 'cutoff_passed' END,
    'eligible_percentage', CASE WHEN v_booking.cancelled_at <= v_cutoff_at
      THEN v_policy.refund_percentage ELSE 0 END,
    'policy_version_id', v_policy.id,
    'cutoff_at', v_cutoff_at
  );
END;
$function$;
REVOKE ALL ON FUNCTION private.booking_refund_policy_decision(uuid)
  FROM PUBLIC, anon, authenticated, service_role, supabase_auth_admin;


-- -----------------------------------------------------------------------------
-- END MIGRATION: 20261025225913_branch_booking_refund_policy.sql
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- START MIGRATION: 20261026100000_guard_paid_deposit_payment_quote.sql
-- -----------------------------------------------------------------------------

-- The legacy destination RPC quotes the entire expected booking price after a
-- verified deposit. Do not offer a second transfer amount until the canonical
-- final-bill settlement contract is available to all clients.
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.get_booking_payment_destination(uuid)'::regprocedure))
       <> '6cc8ac058e5ccff1f55e3e1d9c1488a7' THEN
    RAISE EXCEPTION 'PAYMENT_DESTINATION_CONTRACT_DRIFT';
  END IF;
END;
$guard$;

CREATE OR REPLACE FUNCTION public.get_booking_payment_destination(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_lounge public.lounges%ROWTYPE;
  v_has_open_shift boolean;
  v_amount_due numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT b.* INTO v_booking FROM public.bookings b WHERE b.id = p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_booking.user_id IS DISTINCT FROM auth.uid()
     AND NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(v_booking.lounge_id, 'billing_checkout') THEN
    RAISE EXCEPTION 'Not authorized to view payment details for this booking' USING ERRCODE = '42501';
  END IF;

  SELECT l.* INTO v_lounge FROM public.lounges l WHERE l.id = v_booking.lounge_id;

  SELECT EXISTS (
    SELECT 1 FROM public.shifts s
    WHERE s.lounge_id = v_booking.lounge_id
      AND s.status = 'open'
      AND s.closed_at IS NULL
  ) INTO v_has_open_shift;

  IF v_booking.confirmation_status = 'pending_confirmation' OR v_has_open_shift IS FALSE THEN
    RETURN jsonb_build_object(
      'can_pay', false,
      'booking_id', p_booking_id,
      'confirmation_status', v_booking.confirmation_status,
      'has_open_shift', v_has_open_shift,
      'reason', 'SHIFT_NOT_OPEN_OR_NOT_CONFIRMED',
      'message_ar', 'Ù„Ø§ ÙŠÙ…ÙƒÙ† ØªØ­ÙˆÙŠÙ„ Ø§Ù„Ø£Ù…ÙˆØ§Ù„ Ø£Ùˆ Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø¥ÙŠØµØ§Ù„ Ù‚Ø¨Ù„ ÙØªØ­ Ø§Ù„Ø´ÙŠÙØª ÙˆØªØ£ÙƒÙŠØ¯ Ø§Ù„ØµØ§Ù„Ø© Ù„Ù„Ø­Ø¬Ø²',
      'message_en', 'Payment destination is withheld until the lounge opens a shift and confirms your booking request.'
    );
  END IF;

  IF v_booking.deposit_required AND v_booking.deposit_paid THEN
    RETURN jsonb_build_object(
      'can_pay', false,
      'booking_id', p_booking_id,
      'lounge_id', v_lounge.id,
      'deposit_required', true,
      'deposit_paid', true,
      'reason', 'DEPOSIT_ALREADY_COLLECTED_USE_CANONICAL_SETTLEMENT',
      'message_ar', 'ØªÙ… ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¹Ø±Ø¨ÙˆÙ†. Ø§Ù„Ù…Ø¨Ù„Øº Ø§Ù„Ù†Ù‡Ø§Ø¦ÙŠ ÙŠØªØ­Ø¯Ø¯ Ø¨Ø¹Ø¯ Ø§Ù†ØªÙ‡Ø§Ø¡ Ø§Ù„Ù„Ø¹Ø¨ ÙˆØªØ³ÙˆÙŠØ© Ø§Ù„Ø·Ù„Ø¨Ø§Øª.',
      'message_en', 'The deposit is recorded. The final amount is determined after play and order settlement.'
    );
  END IF;

  IF v_booking.deposit_required THEN
    v_amount_due := v_booking.deposit_amount;
  ELSE
    v_amount_due := GREATEST(0, v_booking.total_price);
  END IF;

  RETURN jsonb_build_object(
    'can_pay', true,
    'booking_id', p_booking_id,
    'lounge_id', v_lounge.id,
    'lounge_name', v_lounge.name,
    'confirmation_status', v_booking.confirmation_status,
    'has_open_shift', true,
    'amount_due', v_amount_due,
    'deposit_required', v_booking.deposit_required,
    'instapay_account', v_lounge.instapay_account,
    'instapay_handle', v_lounge.instapay_handle,
    'vodafone_cash_number', v_lounge.vodafone_cash_number,
    'wallet_number', v_lounge.wallet_number
  );
END;
$function$;


-- -----------------------------------------------------------------------------
-- END MIGRATION: 20261026100000_guard_paid_deposit_payment_quote.sql
-- -----------------------------------------------------------------------------
