-- Keep existing financial calculations and payloads; enforce actor scope on both APIs.
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
REVOKE ALL ON FUNCTION public.blind_close_shift(uuid,uuid,numeric,text) FROM PUBLIC, anon, supabase_auth_admin;
REVOKE ALL ON FUNCTION public.close_shift(uuid,numeric,text) FROM PUBLIC, anon, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.blind_close_shift(uuid,uuid,numeric,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.close_shift(uuid,numeric,text) TO authenticated, service_role;
NOTIFY pgrst, 'reload schema';
