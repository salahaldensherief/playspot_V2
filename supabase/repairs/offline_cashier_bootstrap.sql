-- Coordinated-release review source. Requires the reviewed offline protocol;
-- this file is not a hosted migration and must not be replayed automatically.
BEGIN;
CREATE OR REPLACE FUNCTION private.offline_minor_amount(p_amount numeric)
RETURNS bigint LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF p_amount IS NULL OR p_amount::text IN ('NaN','Infinity','-Infinity')
    OR p_amount < 0 OR p_amount*100 <> trunc(p_amount*100)
    OR p_amount*100 > 9007199254740991 THEN
    RAISE EXCEPTION 'INVALID_OFFLINE_FINANCIAL_SNAPSHOT' USING ERRCODE='22023';
  END IF;
  RETURN (p_amount*100)::bigint;
END; $$;
REVOKE ALL ON FUNCTION private.offline_minor_amount(numeric) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.bootstrap_offline_cashier(
  p_lounge_id uuid, p_device_id uuid, p_online boolean DEFAULT true
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_authority jsonb;
  v_shift_id uuid;
  v_shift_count integer;
  v_timezone text;
  v_from bigint;
  v_until bigint;
  v_blind_cash boolean;
  v_snapshot jsonb;
BEGIN
  -- refresh performs canonical active/unbanned Auth and scoped permission checks,
  -- then acquires the same lounge mutex as booking/reconciliation mutations.
  -- An error later in bootstrap rolls back a first writer claim as well.
  v_authority := public.refresh_cashier_writer(p_lounge_id,p_device_id,p_online);
  v_timezone := v_authority->>'timezone';
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=v_timezone) THEN
    RAISE EXCEPTION 'INVALID_LOUNGE_TIMEZONE' USING ERRCODE='22023';
  END IF;
  SELECT count(*) INTO v_shift_count FROM public.shifts
    WHERE lounge_id=p_lounge_id AND coalesce(cashier_id,staff_user_id)=v_actor
      AND status='open' AND closed_at IS NULL;
  IF v_shift_count<>1 THEN
    RAISE EXCEPTION 'OFFLINE_BOOTSTRAP_REQUIRES_ONE_OWN_SHIFT' USING ERRCODE='55000';
  END IF;
  SELECT id INTO v_shift_id FROM public.shifts
    WHERE lounge_id=p_lounge_id AND coalesce(cashier_id,staff_user_id)=v_actor
      AND status='open' AND closed_at IS NULL FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'OFFLINE_BOOTSTRAP_REQUIRES_ONE_OWN_SHIFT' USING ERRCODE='55000';
  END IF;
  v_from := floor((v_authority->>'server_time_ms')::numeric/60000)::bigint*60000;
  v_until := (v_authority->>'expires_ms')::bigint;
  v_blind_cash := public.is_super_admin() IS TRUE OR
    public.has_lounge_permission(p_lounge_id,'shifts_view_blind_cash') IS TRUE;

  -- A single SQL statement gives resources, capacity and receipts one MVCC
  -- snapshot. Do not lock rooms then bookings: existing online start paths take
  -- booking locks first, so that would introduce a reverse-order deadlock.
  WITH room_rows AS MATERIALIZED (
    SELECT r.*, coalesce(r.hourly_rate_single,r.hourly_rate,50) AS single_rate,
      CASE WHEN coalesce(r.hourly_rate_multi,0)>0 THEN r.hourly_rate_multi
        ELSE coalesce(r.hourly_rate_single,r.hourly_rate,50) END AS multi_rate
    FROM public.rooms r WHERE r.lounge_id=p_lounge_id
  ), intervals AS MATERIALIZED (
    SELECT m.room_id,extract(epoch FROM m.scheduled_at)*1000 AS start_ms,
      extract(epoch FROM m.scheduled_end_at)*1000 AS end_ms
    FROM public.tournament_matches m JOIN room_rows r ON r.id=m.room_id
    WHERE m.status<>'cancelled' AND m.scheduled_at IS NOT NULL
      AND m.scheduled_end_at>m.scheduled_at
      AND extract(epoch FROM m.scheduled_at)*1000<v_until
      AND extract(epoch FROM m.scheduled_end_at)*1000>v_from
    UNION ALL
    SELECT h.room_id,extract(epoch FROM (h.start_at AT TIME ZONE v_timezone))*1000,
      extract(epoch FROM (h.end_at AT TIME ZONE v_timezone))*1000
    FROM public.booking_holds h JOIN room_rows r ON r.id=h.room_id
    WHERE h.lounge_id=p_lounge_id AND h.released_at IS NULL
      AND h.expires_at>statement_timestamp() AND h.end_at>h.start_at
      AND extract(epoch FROM (h.start_at AT TIME ZONE v_timezone))*1000<v_until
      AND extract(epoch FROM (h.end_at AT TIME ZONE v_timezone))*1000>v_from
  ), booking_rows AS MATERIALIZED (
    SELECT b.*, extract(epoch FROM ((b.date+b.start_time) AT TIME ZONE v_timezone))*1000 AS start_ms,
      extract(epoch FROM (((b.date+b.end_time)+CASE WHEN b.end_time<=b.start_time
        THEN interval '1 day' ELSE interval '0' END) AT TIME ZONE v_timezone))*1000 AS end_ms,
      extract(epoch FROM (upper(b.cashier_capacity_period) AT TIME ZONE v_timezone))*1000 AS capacity_end_ms,
      coalesce(p.amount,0) AS paid_amount,
      (p.id IS NULL OR (p.status='completed' AND p.payment_method='cash'
        AND p.lounge_id=p_lounge_id AND p.payout_id IS NULL
        AND p.amount=(SELECT coalesce(sum(sp.amount),0) FROM public.shift_payments sp
          WHERE sp.booking_id=b.id AND sp.lounge_id=p_lounge_id AND sp.payment_method='cash')))
        AND (p.id IS NOT NULL OR b.payment_status='unpaid') AS payment_supported
    FROM public.bookings b JOIN room_rows r ON r.id=b.room_id
    LEFT JOIN public.payments p ON p.booking_id=b.id
    WHERE b.lounge_id=p_lounge_id AND b.date IS NOT NULL
      AND b.start_time IS NOT NULL AND b.end_time IS NOT NULL
      AND b.status NOT IN ('cancelled','rejected')
  ), scoped_bookings AS MATERIALIZED (
    SELECT * FROM booking_rows b WHERE b.status='in_progress'
      OR (b.start_ms<v_until AND b.end_ms>v_from)
      OR (b.shift_id=v_shift_id AND b.total_price>b.paid_amount)
  )
  SELECT jsonb_build_object(
    'protocol_version',2,'complete',true,'authority',v_authority,
    'coverage',jsonb_build_object('from_ms',v_from,'until_ms',v_until),
    'shift',jsonb_build_object('id',v_shift_id,'actor_id',v_actor,
      'lounge_id',p_lounge_id,'status','open','cash_total_visible',v_blind_cash,
      'collected_cash_minor',CASE WHEN v_blind_cash THEN private.offline_minor_amount(
        (SELECT coalesce(sum(amount),0) FROM public.shift_payments
          WHERE shift_id=v_shift_id AND lounge_id=p_lounge_id AND payment_method='cash')) ELSE 0 END),
    'rooms',coalesce((SELECT jsonb_object_agg(r.id::text,jsonb_build_object(
      'id',r.id,'lounge_id',r.lounge_id,'name',r.name,
      'is_active',r.is_active IS TRUE,'is_available',r.is_available IS TRUE,'status',r.status,
      'single_hour_minor',private.offline_minor_amount(r.single_rate),
      'multi_hour_minor',private.offline_minor_amount(r.multi_rate),
      'offline_supported',coalesce(r.pricing_model,'single_multi_hour')='single_multi_hour'
        AND r.single_rate>0 AND r.multi_rate>0,
      'blocked_intervals',coalesce((SELECT jsonb_agg(jsonb_build_object(
        'start_ms',i.start_ms,'end_ms',i.end_ms)) FROM intervals i WHERE i.room_id=r.id),'[]'::jsonb)
    )) FROM room_rows r),'{}'::jsonb),
    'products',coalesce((SELECT jsonb_object_agg(e.id::text,jsonb_build_object(
      'id',e.id,'lounge_id',e.lounge_id,'name',e.name,
      'is_active',e.is_active IS TRUE,'is_available',e.is_available IS TRUE,
      'track_stock',e.track_stock IS TRUE,'stock_quantity',e.stock_quantity,
      'unit_price_minor',private.offline_minor_amount(e.price)
    )) FROM public.extras e WHERE e.lounge_id=p_lounge_id),'{}'::jsonb),
    'bookings',coalesce((SELECT jsonb_object_agg(b.id::text,jsonb_build_object(
      'id',b.id,'lounge_id',b.lounge_id,'room_id',b.room_id,'shift_id',b.shift_id,
      'customer_name',b.user_name,'customer_phone',b.user_phone,'play_mode',b.play_mode,
      'timezone',v_timezone,'start_ms',b.start_ms,'end_ms',b.end_ms,
      'capacity_end_ms',coalesce(b.capacity_end_ms,b.start_ms),
      'started_ms',extract(epoch FROM b.actual_start_time)*1000,
      'total_minor',private.offline_minor_amount(b.total_price),
      'paid_minor',private.offline_minor_amount(b.paid_amount),
      'payment_status',CASE WHEN b.paid_amount=b.total_price THEN 'paid'
        WHEN b.paid_amount>0 THEN 'partial' ELSE 'unpaid' END,
      'status',b.status,'sync_status','synced',
      'offline_supported',b.is_open_time IS NOT TRUE AND b.payment_supported
        AND b.shift_id=v_shift_id AND b.play_mode IN ('single','multi')
        AND coalesce(b.extra_controllers,0)=0
        AND coalesce(b.discount_amount,0)=0 AND coalesce(b.discount_percentage,0)=0,
      'items',coalesce((SELECT jsonb_agg(jsonb_build_object('id',o.id,'items',o.items,
        'total_minor',private.offline_minor_amount(o.total_price)))
        FROM public.canteen_orders o WHERE o.booking_id=b.id AND o.lounge_id=p_lounge_id
          AND o.status<>'cancelled'),'[]'::jsonb)
    )) FROM scoped_bookings b),'{}'::jsonb)
  ) INTO v_snapshot;

  -- Never label a truncated oversized snapshot as complete.
  IF octet_length(v_snapshot::text)>8388608 THEN
    RAISE EXCEPTION 'OFFLINE_BOOTSTRAP_TOO_LARGE' USING ERRCODE='54000';
  END IF;
  RETURN v_snapshot;
END; $$;
REVOKE ALL ON FUNCTION public.bootstrap_offline_cashier(uuid,uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.bootstrap_offline_cashier(uuid,uuid,boolean) TO authenticated;
COMMIT;
