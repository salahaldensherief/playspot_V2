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
REVOKE ALL ON FUNCTION public.close_lounge_shift(uuid,numeric,text) FROM PUBLIC, anon, supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.close_lounge_shift(uuid,numeric,text) TO authenticated, service_role;
NOTIFY pgrst, 'reload schema';
