CREATE OR REPLACE FUNCTION public.get_lounge_live_shift_overview(p_lounge_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_shift record;
  v_name text;
  v_cash numeric := 0;
  v_digital numeric := 0;
  v_expenses numeric := 0;
  v_cash_expenses numeric := 0;
BEGIN
  IF (SELECT auth.uid()) IS NULL
     OR (SELECT private.current_user_role()) = 'super_admin'
     OR NOT (SELECT private.is_lounge_member(p_lounge_id)) THEN
    RAISE EXCEPTION 'Not authorized for this lounge.';
  END IF;

  SELECT * INTO v_shift
  FROM public.shifts
  WHERE lounge_id = p_lounge_id
    AND status = 'open'
  ORDER BY opened_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'has_active_shift', false,
      'lounge_id', p_lounge_id,
      'total_sales', 0,
      'cash_sales', 0,
      'digital_sales', 0,
      'total_expenses', 0,
      'expected_cash', 0
    );
  END IF;

  SELECT full_name INTO v_name
  FROM public.profiles
  WHERE id = COALESCE(v_shift.cashier_id, v_shift.staff_user_id);

  SELECT
    COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN payment_method <> 'cash' THEN amount ELSE 0 END), 0)
  INTO v_cash, v_digital
  FROM public.shift_payments
  WHERE shift_id = v_shift.id;

  SELECT
    COALESCE(SUM(amount), 0),
    COALESCE(SUM(CASE WHEN expense_type IN ('cash_drop', 'expense', 'other') THEN amount ELSE 0 END), 0)
  INTO v_expenses, v_cash_expenses
  FROM public.shift_expenses
  WHERE shift_id = v_shift.id;

  RETURN json_build_object(
    'has_active_shift', true,
    'lounge_id', p_lounge_id,
    'shift_id', v_shift.id,
    'cashier_id', v_shift.cashier_id,
    'cashier_name', COALESCE(v_name, 'Cashier'),
    'opened_at', v_shift.opened_at,
    'starting_cash', COALESCE(v_shift.starting_cash, 0),
    'cash_sales', v_cash,
    'digital_sales', v_digital,
    'total_sales', v_cash + v_digital,
    'total_expenses', v_expenses,
    'expected_cash', COALESCE(v_shift.starting_cash, 0) + v_cash - v_cash_expenses,
    'payment_count', (SELECT COUNT(*) FROM public.shift_payments WHERE shift_id = v_shift.id),
    'expense_count', (SELECT COUNT(*) FROM public.shift_expenses WHERE shift_id = v_shift.id),
    'linked_booking_count', (SELECT COUNT(*) FROM public.bookings WHERE shift_id = v_shift.id)
  );
END;
$function$
;
CREATE OR REPLACE FUNCTION public.get_current_shift(p_lounge_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_shift RECORD;
  v_total_sales numeric := 0;
  v_cash_sales numeric := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('has_active_shift', false);
  END IF;

  SELECT * INTO v_shift
  FROM public.shifts
  WHERE lounge_id = p_lounge_id
    AND status = 'open'
    AND (cashier_id = auth.uid() OR staff_user_id = auth.uid())
  ORDER BY opened_at DESC
  LIMIT 1;

  IF v_shift.id IS NULL THEN
    RETURN jsonb_build_object('has_active_shift', false, 'lounge_id', p_lounge_id);
  END IF;

  SELECT
    COALESCE(SUM(amount), 0),
    COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN amount ELSE 0 END), 0)
  INTO v_total_sales, v_cash_sales
  FROM public.shift_payments
  WHERE shift_id = v_shift.id;

  RETURN jsonb_build_object(
    'has_active_shift', true,
    'shift_id', v_shift.id,
    'lounge_id', v_shift.lounge_id,
    'cashier_id', v_shift.cashier_id,
    'staff_user_id', v_shift.staff_user_id,
    'opened_at', v_shift.opened_at,
    'starting_cash', v_shift.starting_cash,
    'current_cash_sales', v_cash_sales,
    'current_total_sales', v_total_sales,
    'current_expected_cash', COALESCE(v_shift.starting_cash, 0) + v_cash_sales
  );
END;
$function$
;
CREATE OR REPLACE FUNCTION public.get_shift_report(p_lounge_id uuid, p_start_date date DEFAULT CURRENT_DATE, p_end_date date DEFAULT CURRENT_DATE, p_cashier_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(shift_id uuid, lounge_id uuid, cashier_id uuid, cashier_name text, opened_at timestamp with time zone, closed_at timestamp with time zone, status text, is_approved boolean, starting_cash numeric, total_sales numeric, cash_sales numeric, digital_sales numeric, total_expenses numeric, expected_cash numeric, actual_cash numeric, difference numeric, payment_count bigint, expense_count bigint, linked_booking_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL
     OR (
       COALESCE((SELECT private.current_user_role()), '') <> 'super_admin'
       AND NOT COALESCE((SELECT private.is_lounge_member(p_lounge_id)), false)
     ) THEN
    RAISE EXCEPTION 'Not authorized for this lounge.';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.lounge_id,
    COALESCE(s.cashier_id, s.staff_user_id),
    COALESCE(p.full_name, 'Cashier'),
    s.opened_at,
    s.closed_at,
    s.status,
    COALESCE(s.is_approved, false),
    COALESCE(s.starting_cash, 0),
    COALESCE(SUM(sp.amount), 0),
    COALESCE(SUM(sp.amount) FILTER (WHERE sp.payment_method = 'cash'), 0),
    COALESCE(SUM(sp.amount) FILTER (WHERE sp.payment_method <> 'cash'), 0),
    COALESCE((SELECT SUM(se.amount) FROM public.shift_expenses se WHERE se.shift_id = s.id), 0),
    COALESCE(s.expected_cash, 0),
    COALESCE(s.actual_cash_counted, 0),
    COALESCE(s.difference, 0),
    COUNT(sp.id),
    (SELECT COUNT(*) FROM public.shift_expenses se WHERE se.shift_id = s.id),
    (SELECT COUNT(*) FROM public.bookings b WHERE b.shift_id = s.id)
  FROM public.shifts s
  LEFT JOIN public.profiles p ON p.id = COALESCE(s.cashier_id, s.staff_user_id)
  LEFT JOIN public.shift_payments sp ON sp.shift_id = s.id
  WHERE s.lounge_id = p_lounge_id
    AND s.opened_at::date BETWEEN p_start_date AND p_end_date
    AND (p_cashier_id IS NULL OR COALESCE(s.cashier_id, s.staff_user_id) = p_cashier_id)
  GROUP BY s.id, p.full_name;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.blind_close_shift(p_shift_id uuid, p_cashier_id uuid, p_counted_cash numeric, p_notes text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_shift public.shifts%ROWTYPE;
  v_cash_sales numeric;
  v_expenses numeric;
  v_expected numeric;
  v_difference numeric;
  v_manager boolean;
  v_actor uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
BEGIN
  IF p_counted_cash IS NULL OR p_counted_cash < 0 THEN RAISE EXCEPTION 'Counted cash must be non-negative' USING ERRCODE = '22023'; END IF;
  SELECT s.* INTO v_shift FROM public.shifts s WHERE s.id = p_shift_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Shift not found' USING ERRCODE = 'P0002'; END IF;
  IF v_shift.status <> 'open' THEN RAISE EXCEPTION 'Shift is not open' USING ERRCODE = '55000'; END IF;
  IF v_shift.cashier_id IS DISTINCT FROM p_cashier_id THEN RAISE EXCEPTION 'Shift does not belong to the specified cashier' USING ERRCODE = '42501'; END IF;
  IF auth.role() IS DISTINCT FROM 'service_role' AND (
    NOT COALESCE(private.can_operate_playspot_lounge(v_shift.lounge_id), false)
    OR NOT COALESCE(public.has_lounge_permission(v_shift.lounge_id, 'shifts_blind_close'), false)
  ) THEN
    RAISE EXCEPTION 'Shift closure is not permitted for this actor' USING ERRCODE = '42501';
  END IF;
  v_manager := private.can_manage_playspot_lounge(v_shift.lounge_id);
  IF v_actor IS DISTINCT FROM p_cashier_id AND NOT v_manager AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Only the shift cashier or an authorized manager may close this shift' USING ERRCODE = '42501';
  END IF;
  SELECT COALESCE(SUM(sp.amount), 0) INTO v_cash_sales FROM public.shift_payments sp
  WHERE sp.shift_id = p_shift_id AND sp.payment_method = 'cash';
  SELECT COALESCE(SUM(se.amount), 0) INTO v_expenses FROM public.shift_expenses se WHERE se.shift_id = p_shift_id;
  v_expected := COALESCE(v_shift.starting_cash, 0) + v_cash_sales - v_expenses;
  v_difference := p_counted_cash - v_expected;
  UPDATE public.shifts SET actual_cash_counted = p_counted_cash, expected_cash = v_expected,
    difference = v_difference, status = 'closed', closed_at = v_now, end_time = v_now,
    notes = COALESCE(p_notes, notes)
  WHERE id = p_shift_id;
  INSERT INTO public.shift_audit_logs
    (lounge_id, shift_id, entity_type, entity_id, action, actor_user_id, old_data, new_data)
  VALUES
    (v_shift.lounge_id, p_shift_id, 'shift', p_shift_id, 'update', v_actor,
     jsonb_build_object('status', v_shift.status, 'expected_cash', v_shift.expected_cash,
                        'actual_cash_counted', v_shift.actual_cash_counted, 'difference', v_shift.difference),
     jsonb_build_object('status', 'closed', 'expected_cash', v_expected,
                        'actual_cash_counted', p_counted_cash, 'difference', v_difference,
                        'cash_sales', v_cash_sales, 'expenses', v_expenses, 'notes', p_notes));
  RETURN jsonb_build_object('success', true, 'shift_id', p_shift_id, 'status', 'closed',
    'actual_cash_counted', p_counted_cash,
    'expected_cash', CASE WHEN v_manager THEN to_jsonb(v_expected) ELSE 'null'::jsonb END,
    'difference', CASE WHEN v_manager THEN to_jsonb(v_difference) ELSE 'null'::jsonb END,
    'manager_report', v_manager);
END;
$function$
;
CREATE OR REPLACE FUNCTION public.close_shift(p_shift_id uuid, p_actual_cash numeric, p_notes text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_shift public.shifts;
  v_cash numeric := 0;
  v_digital numeric := 0;
  v_expenses numeric := 0;
  v_cash_expenses numeric := 0;
  v_expected numeric := 0;
  v_diff numeric := 0;
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF p_actual_cash IS NULL OR p_actual_cash < 0 THEN
    RAISE EXCEPTION 'Actual cash cannot be negative.';
  END IF;

  SELECT * INTO v_shift
  FROM public.shifts
  WHERE id = p_shift_id
    AND status = 'open'
  FOR UPDATE;

  IF v_shift.id IS NULL THEN
    RAISE EXCEPTION 'Shift not found or already closed.';
  END IF;

  IF NOT (
    private.can_operate_playspot_lounge(v_shift.lounge_id)
    AND public.has_lounge_permission(v_shift.lounge_id, 'shifts_blind_close')
    AND (v_shift.cashier_id = auth.uid()
         OR private.can_manage_playspot_lounge(v_shift.lounge_id))
  ) THEN
    RAISE EXCEPTION 'Only the assigned cashier or an authorized manager can close this shift.' USING ERRCODE = '42501';
  END IF;

  SELECT
    COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN payment_method <> 'cash' THEN amount ELSE 0 END), 0)
  INTO v_cash, v_digital
  FROM public.shift_payments
  WHERE shift_id = p_shift_id;

  SELECT
    COALESCE(SUM(amount), 0),
    COALESCE(SUM(CASE WHEN expense_type IN ('cash_drop', 'expense', 'other') THEN amount ELSE 0 END), 0)
  INTO v_expenses, v_cash_expenses
  FROM public.shift_expenses
  WHERE shift_id = p_shift_id;

  v_expected := COALESCE(v_shift.starting_cash, 0) + v_cash - v_cash_expenses;
  v_diff := p_actual_cash - v_expected;

  UPDATE public.shifts
  SET status = 'closed',
      closed_at = now(),
      end_time = now(),
      actual_cash_counted = p_actual_cash,
      expected_cash = v_expected,
      total_cash_sales = v_cash,
      total_digital_sales = v_digital,
      total_expenses = v_expenses,
      difference = v_diff,
      notes = COALESCE(p_notes, notes)
  WHERE id = p_shift_id;

  RETURN json_build_object(
    'success', true,
    'shift_id', p_shift_id,
    'starting_cash', COALESCE(v_shift.starting_cash, 0),
    'cash_sales', v_cash,
    'digital_sales', v_digital,
    'total_expenses', v_expenses,
    'expected_cash', v_expected,
    'actual_cash', p_actual_cash,
    'difference', v_diff,
    'status', 'closed'
  );
END;
$function$
;
CREATE OR REPLACE FUNCTION public.close_lounge_shift(p_lounge_id uuid, p_actual_cash_counted numeric DEFAULT NULL::numeric, p_notes text DEFAULT NULL::text)
 RETURNS shifts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_shift public.shifts%ROWTYPE;
  v_cash numeric := 0;
  v_digital numeric := 0;
  v_expenses numeric := 0;
  v_expected_cash numeric := 0;
  v_actual_cash numeric;
  v_difference numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication is required' USING ERRCODE = '28000';
  END IF;

  IF p_lounge_id IS NULL OR (p_actual_cash_counted IS NOT NULL AND p_actual_cash_counted < 0) THEN
    RAISE EXCEPTION 'Invalid lounge or cash count' USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_super_admin() THEN
    PERFORM private.assert_lounge_operator(p_lounge_id, false);
  END IF;

  SELECT s.* INTO v_shift
  FROM public.shifts AS s
  WHERE s.lounge_id = p_lounge_id
    AND s.status = 'open'
    AND s.closed_at IS NULL
  ORDER BY s.opened_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'There is no open shift for this lounge' USING ERRCODE = '55000';
  END IF;

  IF NOT (
    COALESCE(private.can_operate_playspot_lounge(v_shift.lounge_id), false)
    AND COALESCE(public.has_lounge_permission(v_shift.lounge_id, 'shifts_blind_close'), false)
    AND (v_shift.cashier_id = auth.uid()
         OR private.can_manage_playspot_lounge(v_shift.lounge_id))
  ) THEN
    RAISE EXCEPTION 'Only the assigned cashier or an authorized manager can close this shift' USING ERRCODE = '42501';
  END IF;

  SELECT
    COALESCE(sum(sp.amount) FILTER (WHERE sp.payment_method = 'cash'), 0),
    COALESCE(sum(sp.amount) FILTER (WHERE sp.payment_method <> 'cash'), 0)
  INTO v_cash, v_digital
  FROM public.shift_payments AS sp
  WHERE sp.shift_id = v_shift.id;

  SELECT COALESCE(sum(se.amount), 0)
  INTO v_expenses
  FROM public.shift_expenses AS se
  WHERE se.shift_id = v_shift.id;

  v_expected_cash := COALESCE(v_shift.starting_cash, 0) + v_cash - v_expenses;
  v_actual_cash := COALESCE(p_actual_cash_counted, v_shift.actual_cash_counted);
  v_difference := CASE WHEN v_actual_cash IS NULL THEN NULL ELSE v_actual_cash - v_expected_cash END;

  UPDATE public.shifts AS s
  SET status = 'closed',
      closed_at = now(),
      end_time = now(),
      expected_cash = v_expected_cash,
      actual_cash_counted = v_actual_cash,
      total_cash_sales = v_cash,
      total_digital_sales = v_digital,
      total_expenses = v_expenses,
      difference = v_difference,
      notes = COALESCE(p_notes, s.notes)
  WHERE s.id = v_shift.id
  RETURNING s.* INTO v_shift;

  RETURN v_shift;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.close_shift_and_calculate_z_report(p_shift_id uuid, p_actual_cash numeric, p_notes text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'extensions', 'pg_temp'
AS $function$
DECLARE
    v_starting_cash NUMERIC := 0;
    v_cash_revenue NUMERIC := 0;
    v_digital_revenue NUMERIC := 0;
    v_expenses NUMERIC := 0;
    v_total_expected_cash NUMERIC := 0;
    v_total_revenue NUMERIC := 0;
    v_discrepancy NUMERIC := 0;
    v_closed_shift RECORD;
BEGIN
    SELECT COALESCE(starting_cash, 0) INTO v_starting_cash
    FROM public.shifts
    WHERE id = p_shift_id;

    SELECT COALESCE(SUM(amount), 0) INTO v_cash_revenue
    FROM public.shift_payments
    WHERE shift_id = p_shift_id AND payment_method = 'cash';

    SELECT COALESCE(SUM(amount), 0) INTO v_digital_revenue
    FROM public.shift_payments
    WHERE shift_id = p_shift_id AND payment_method <> 'cash';

    SELECT COALESCE(SUM(amount), 0) INTO v_expenses
    FROM public.shift_expenses
    WHERE shift_id = p_shift_id;

    v_total_revenue := v_cash_revenue + v_digital_revenue;
    v_total_expected_cash := v_starting_cash + v_cash_revenue - v_expenses;
    v_discrepancy := p_actual_cash - v_total_expected_cash;

    UPDATE public.shifts
    SET
        status = 'closed',
        closed_at = now(),
        expected_cash = v_total_expected_cash,
        actual_cash_counted = p_actual_cash,
        total_cash_sales = v_cash_revenue,
        total_digital_sales = v_digital_revenue,
        total_expenses = v_expenses,
        difference = v_discrepancy,
        notes = p_notes
    WHERE id = p_shift_id
    RETURNING * INTO v_closed_shift;

    RETURN json_build_object(
        'shift', row_to_json(v_closed_shift),
        'summary', json_build_object(
            'starting_cash', v_starting_cash,
            'cash_revenue', v_cash_revenue,
            'digital_revenue', v_digital_revenue,
            'total_revenue', v_total_revenue,
            'total_expenses', v_expenses,
            'expected_cash', v_total_expected_cash,
            'actual_cash', p_actual_cash,
            'discrepancy', v_discrepancy
        )
    );
END;
$function$
;
CREATE OR REPLACE FUNCTION public.get_lounge_details(p_lounge_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT jsonb_build_object(
    'lounge', jsonb_set(
      to_jsonb(l),
      '{is_open}',
      to_jsonb(EXISTS (
        SELECT 1
        FROM public.shifts AS s
        WHERE s.lounge_id = l.id
          AND s.status = 'open'
          AND s.closed_at IS NULL
      ))
    ),
    'is_shift_open', EXISTS (
      SELECT 1
      FROM public.shifts AS s
      WHERE s.lounge_id = l.id
        AND s.status = 'open'
        AND s.closed_at IS NULL
    ),
    'current_shift', (
      SELECT to_jsonb(s)
      FROM public.shifts AS s
      WHERE s.lounge_id = l.id
        AND s.status = 'open'
        AND s.closed_at IS NULL
      ORDER BY s.opened_at DESC
      LIMIT 1
    )
  )
  FROM public.lounges AS l
  WHERE l.id = p_lounge_id;
$function$
;
CREATE OR REPLACE FUNCTION public.get_lounge_comparison(p_start_date date DEFAULT CURRENT_DATE, p_end_date date DEFAULT CURRENT_DATE)
 RETURNS TABLE(lounge_id uuid, lounge_name text, shift_count bigint, open_shift_count bigint, total_sales numeric, total_expenses numeric, total_difference numeric, average_shift_sales numeric, pending_approval_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL
     OR (SELECT private.current_user_role()) NOT IN ('super_admin', 'admin', 'lounge_admin') THEN
    RAISE EXCEPTION 'Only administrators can view lounge comparison.';
  END IF;

  RETURN QUERY
  SELECT
    l.id,
    COALESCE(l.name, l.name_en, l.name_ar),
    COUNT(DISTINCT s.id),
    COUNT(DISTINCT s.id) FILTER (WHERE s.status = 'open'),
    COALESCE(SUM(sp.amount), 0),
    COALESCE(SUM(s.total_expenses), 0),
    COALESCE(SUM(s.difference) FILTER (WHERE s.status = 'closed'), 0),
    COALESCE(SUM(sp.amount), 0) / NULLIF(COUNT(DISTINCT s.id), 0),
    COUNT(DISTINCT s.id) FILTER (WHERE s.status = 'closed' AND COALESCE(s.is_approved, false) = false)
  FROM public.lounges l
  LEFT JOIN public.shifts s
    ON s.lounge_id = l.id
   AND s.opened_at::date BETWEEN p_start_date AND p_end_date
  LEFT JOIN public.shift_payments sp ON sp.shift_id = s.id
  WHERE COALESCE(l.is_active, true) = true
  GROUP BY l.id, l.name, l.name_en, l.name_ar
  ORDER BY total_sales DESC;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.get_cashier_performance(p_lounge_id uuid, p_start_date date DEFAULT CURRENT_DATE, p_end_date date DEFAULT CURRENT_DATE)
 RETURNS TABLE(cashier_id uuid, cashier_name text, shift_count bigint, closed_shift_count bigint, approved_shift_count bigint, total_sales numeric, cash_sales numeric, digital_sales numeric, total_expenses numeric, total_difference numeric, average_shift_sales numeric, open_shift_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL
     OR (
       COALESCE((SELECT private.current_user_role()), '') <> 'super_admin'
       AND NOT COALESCE((SELECT private.is_lounge_member(p_lounge_id)), false)
     ) THEN
    RAISE EXCEPTION 'Not authorized for this lounge.';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(s.cashier_id, s.staff_user_id),
    COALESCE(p.full_name, 'Cashier'),
    COUNT(DISTINCT s.id),
    COUNT(DISTINCT s.id) FILTER (WHERE s.status = 'closed'),
    COUNT(DISTINCT s.id) FILTER (WHERE COALESCE(s.is_approved, false)),
    COALESCE(SUM(sp.amount), 0),
    COALESCE(SUM(sp.amount) FILTER (WHERE sp.payment_method = 'cash'), 0),
    COALESCE(SUM(sp.amount) FILTER (WHERE sp.payment_method <> 'cash'), 0),
    COALESCE(SUM(s.total_expenses), 0),
    COALESCE(SUM(s.difference) FILTER (WHERE s.status = 'closed'), 0),
    COALESCE(SUM(sp.amount), 0) / NULLIF(COUNT(DISTINCT s.id), 0),
    COUNT(DISTINCT s.id) FILTER (WHERE s.status = 'open')
  FROM public.shifts s
  LEFT JOIN public.profiles p ON p.id = COALESCE(s.cashier_id, s.staff_user_id)
  LEFT JOIN public.shift_payments sp ON sp.shift_id = s.id
  WHERE s.lounge_id = p_lounge_id
    AND s.opened_at::date BETWEEN p_start_date AND p_end_date
  GROUP BY COALESCE(s.cashier_id, s.staff_user_id), p.full_name;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.open_lounge_shift(p_lounge_id uuid, p_starting_cash numeric DEFAULT 0, p_notes text DEFAULT NULL::text)
 RETURNS shifts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_shift public.shifts%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication is required' USING ERRCODE = '28000';
  END IF;

  IF NOT (public.is_super_admin() OR private.can_operate_playspot_lounge(p_lounge_id) OR public.is_lounge_member_or_admin(p_lounge_id)) THEN
    RAISE EXCEPTION 'You are not allowed to open a shift for this lounge' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shift
  FROM public.shifts
  WHERE lounge_id = p_lounge_id AND status = 'open' AND closed_at IS NULL
  ORDER BY opened_at DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN v_shift;
  END IF;

  INSERT INTO public.shifts (
    lounge_id,
    staff_user_id,
    cashier_id,
    status,
    starting_cash,
    notes,
    opened_at,
    start_time
  )
  VALUES (
    p_lounge_id,
    auth.uid(),
    auth.uid(),
    'open',
    GREATEST(COALESCE(p_starting_cash, 0), 0),
    p_notes,
    now(),
    now()
  )
  RETURNING * INTO v_shift;

  RETURN v_shift;
EXCEPTION
  WHEN unique_violation THEN
    SELECT * INTO v_shift
    FROM public.shifts
    WHERE lounge_id = p_lounge_id AND status = 'open' AND closed_at IS NULL
    ORDER BY opened_at DESC
    LIMIT 1;
    RETURN v_shift;
END;
$function$
;
