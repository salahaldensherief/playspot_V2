BEGIN;

CREATE TABLE IF NOT EXISTS public.pricing_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid NOT NULL REFERENCES public.lounges(id) ON DELETE CASCADE,
  space_type_id uuid REFERENCES public.space_types(id) ON DELETE CASCADE,
  room_id uuid REFERENCES public.rooms(id) ON DELETE CASCADE,
  name_ar text NOT NULL,
  name_en text NOT NULL,
  rule_type text NOT NULL DEFAULT 'peak'
    CHECK (rule_type IN ('peak','off_peak','standard','custom')),
  days_of_week integer[] NOT NULL DEFAULT ARRAY[1,2,3,4,5,6,7],
  start_time time NOT NULL,
  end_time time NOT NULL,
  start_date date,
  end_date date,
  adjustment_type text NOT NULL DEFAULT 'multiplier'
    CHECK (adjustment_type IN ('multiplier','percentage','fixed')),
  adjustment_value numeric NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  priority integer NOT NULL DEFAULT 10,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pricing_rules_days_valid CHECK (
    cardinality(days_of_week) > 0
    AND days_of_week <@ ARRAY[1,2,3,4,5,6,7]::integer[]
  ),
  CONSTRAINT pricing_rules_dates_valid CHECK (
    start_date IS NULL OR end_date IS NULL OR end_date >= start_date
  ),
  CONSTRAINT pricing_rules_adjustment_valid CHECK (
    (adjustment_type='multiplier' AND adjustment_value > 0)
    OR (adjustment_type='percentage' AND adjustment_value >= -100)
    OR (adjustment_type='fixed' AND adjustment_value >= 0)
  )
);

CREATE INDEX IF NOT EXISTS pricing_rules_lounge_active_idx
  ON public.pricing_rules(lounge_id,is_active,priority DESC);
CREATE INDEX IF NOT EXISTS pricing_rules_room_idx
  ON public.pricing_rules(room_id)
  WHERE room_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS pricing_rules_space_type_idx
  ON public.pricing_rules(space_type_id)
  WHERE space_type_id IS NOT NULL;

ALTER TABLE public.pricing_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pricing_rules_read ON public.pricing_rules;
CREATE POLICY pricing_rules_read
ON public.pricing_rules
FOR SELECT
TO authenticated
USING (public._playspot_has_lounge_access(lounge_id));

DROP POLICY IF EXISTS pricing_rules_write ON public.pricing_rules;
CREATE POLICY pricing_rules_write
ON public.pricing_rules
FOR ALL
TO authenticated
USING (
  public.is_super_admin()
  OR public.has_lounge_permission(lounge_id,'pricing_manage')
  OR public.has_lounge_permission(lounge_id,'pricing.manage')
)
WITH CHECK (
  (
    public.is_super_admin()
    OR public.has_lounge_permission(lounge_id,'pricing_manage')
    OR public.has_lounge_permission(lounge_id,'pricing.manage')
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

GRANT SELECT,INSERT,UPDATE,DELETE ON public.pricing_rules TO authenticated;

CREATE OR REPLACE FUNCTION private.pricing_time_windows_overlap(
  p_start_a time,
  p_end_a time,
  p_start_b time,
  p_end_b time
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO ''
AS $function$
DECLARE
  a1 integer;
  a2 integer;
  b1 integer;
  b2 integer;
BEGIN
  a1 := (extract(hour from p_start_a)*60 + extract(minute from p_start_a))::integer;
  a2 := (extract(hour from p_end_a)*60 + extract(minute from p_end_a))::integer;
  b1 := (extract(hour from p_start_b)*60 + extract(minute from p_start_b))::integer;
  b2 := (extract(hour from p_end_b)*60 + extract(minute from p_end_b))::integer;
  IF a2 <= a1 THEN a2 := a2 + 1440; END IF;
  IF b2 <= b1 THEN b2 := b2 + 1440; END IF;

  RETURN
    (a1 < b2 AND b1 < a2)
    OR (a1 < b2 + 1440 AND b1 + 1440 < a2)
    OR (a1 + 1440 < b2 AND b1 < a2 + 1440);
END;
$function$;

REVOKE ALL ON FUNCTION private.pricing_time_windows_overlap(time,time,time,time)
FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.check_pricing_rule_conflicts(
  p_lounge_id uuid,
  p_start_time time,
  p_end_time time,
  p_days integer[],
  p_space_type_id uuid DEFAULT NULL,
  p_room_id uuid DEFAULT NULL,
  p_exclude_rule_id uuid DEFAULT NULL
)
RETURNS SETOF public.pricing_rules
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT pr.*
  FROM public.pricing_rules AS pr
  WHERE pr.lounge_id=p_lounge_id
    AND pr.is_active IS TRUE
    AND (p_exclude_rule_id IS NULL OR pr.id<>p_exclude_rule_id)
    AND pr.days_of_week && p_days
    AND private.pricing_time_windows_overlap(
      pr.start_time,pr.end_time,p_start_time,p_end_time
    )
    AND (
      p_room_id IS NULL
      OR pr.room_id IS NULL
      OR pr.room_id=p_room_id
    )
    AND (
      p_space_type_id IS NULL
      OR pr.space_type_id IS NULL
      OR pr.space_type_id=p_space_type_id
    )
    AND (
      public.is_super_admin()
      OR public._playspot_has_lounge_access(p_lounge_id)
    )
  ORDER BY pr.priority DESC,pr.created_at DESC;
$function$;

REVOKE ALL ON FUNCTION public.check_pricing_rule_conflicts(
  uuid,time,time,integer[],uuid,uuid,uuid
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_pricing_rule_conflicts(
  uuid,time,time,integer[],uuid,uuid,uuid
) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION private.price_room_interval(
  p_room_id uuid,
  p_date date,
  p_start time,
  p_end time,
  p_play_mode text DEFAULT 'single'
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_room public.rooms%ROWTYPE;
  v_base_rate numeric;
  v_start_min integer;
  v_end_min integer;
  v_boundaries integer[];
  v_sorted integer[];
  v_rule public.pricing_rules%ROWTYPE;
  v_offset integer;
  v_rule_date date;
  v_rule_start integer;
  v_rule_end integer;
  v_i integer;
  v_seg_start integer;
  v_seg_end integer;
  v_mid integer;
  v_mid_date date;
  v_mid_time time;
  v_match public.pricing_rules%ROWTYPE;
  v_rate numeric;
  v_minutes integer;
  v_amount numeric;
  v_total numeric := 0;
  v_segments jsonb := '[]'::jsonb;
  v_has_rule boolean := false;
  v_duration integer;
  v_avg_rate numeric;
BEGIN
  IF p_room_id IS NULL OR p_date IS NULL OR p_start IS NULL OR p_end IS NULL THEN
    RAISE EXCEPTION 'Missing pricing interval arguments' USING ERRCODE='22023';
  END IF;

  SELECT r.* INTO v_room
  FROM public.rooms AS r
  WHERE r.id=p_room_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE='P0002';
  END IF;

  v_base_rate := CASE
    WHEN lower(COALESCE(p_play_mode,'single'))='multi'
      AND COALESCE(v_room.hourly_rate_multi,0)>0
      THEN v_room.hourly_rate_multi
    ELSE COALESCE(v_room.hourly_rate_single,v_room.hourly_rate,0)
  END;

  IF COALESCE(v_base_rate,0)<=0 THEN
    RAISE EXCEPTION 'Room has no valid hourly rate' USING ERRCODE='23514';
  END IF;

  v_start_min := (
    extract(hour from p_start)*60 + extract(minute from p_start)
  )::integer;
  v_end_min := (
    extract(hour from p_end)*60 + extract(minute from p_end)
  )::integer;
  IF v_end_min <= v_start_min THEN
    v_end_min := v_end_min + 1440;
  END IF;

  v_duration := v_end_min-v_start_min;
  IF v_duration<=0 OR v_duration>1440 THEN
    RAISE EXCEPTION 'Invalid pricing duration' USING ERRCODE='22023';
  END IF;

  v_boundaries := ARRAY[v_start_min,v_end_min];

  FOR v_rule IN
    SELECT pr.*
    FROM public.pricing_rules AS pr
    WHERE pr.lounge_id=v_room.lounge_id
      AND pr.is_active IS TRUE
      AND (pr.room_id IS NULL OR pr.room_id=v_room.id)
      AND (
        pr.space_type_id IS NULL
        OR pr.space_type_id=v_room.space_type_id
      )
  LOOP
    FOR v_offset IN -1..1 LOOP
      v_rule_date := p_date + v_offset;

      IF (v_rule.start_date IS NULL OR v_rule_date>=v_rule.start_date)
         AND (v_rule.end_date IS NULL OR v_rule_date<=v_rule.end_date)
         AND extract(isodow from v_rule_date)::integer = ANY(v_rule.days_of_week)
      THEN
        v_rule_start :=
          v_offset*1440
          + (extract(hour from v_rule.start_time)*60
             + extract(minute from v_rule.start_time))::integer;
        v_rule_end :=
          v_offset*1440
          + (extract(hour from v_rule.end_time)*60
             + extract(minute from v_rule.end_time))::integer;

        IF v_rule.end_time<=v_rule.start_time THEN
          v_rule_end:=v_rule_end+1440;
        END IF;

        IF v_rule_start>v_start_min AND v_rule_start<v_end_min THEN
          v_boundaries:=array_append(v_boundaries,v_rule_start);
        END IF;
        IF v_rule_end>v_start_min AND v_rule_end<v_end_min THEN
          v_boundaries:=array_append(v_boundaries,v_rule_end);
        END IF;
      END IF;
    END LOOP;
  END LOOP;

  SELECT array_agg(DISTINCT x ORDER BY x)
  INTO v_sorted
  FROM unnest(v_boundaries) AS x;

  FOR v_i IN 1..cardinality(v_sorted)-1 LOOP
    v_seg_start:=v_sorted[v_i];
    v_seg_end:=v_sorted[v_i+1];
    v_minutes:=v_seg_end-v_seg_start;
    IF v_minutes<=0 THEN CONTINUE; END IF;

    v_mid:=floor((v_seg_start+v_seg_end)/2.0)::integer;
    v_mid_date:=p_date + floor(v_mid/1440.0)::integer;
    v_mid_time:=
      '00:00:00'::time
      + ((v_mid % 1440)::text || ' minutes')::interval;

    v_match:=NULL;

    SELECT pr.*
    INTO v_match
    FROM public.pricing_rules AS pr
    WHERE pr.lounge_id=v_room.lounge_id
      AND pr.is_active IS TRUE
      AND (pr.room_id IS NULL OR pr.room_id=v_room.id)
      AND (
        pr.space_type_id IS NULL
        OR pr.space_type_id=v_room.space_type_id
      )
      AND (
        (
          pr.end_time>pr.start_time
          AND v_mid_time>=pr.start_time
          AND v_mid_time<pr.end_time
        )
        OR (
          pr.end_time<=pr.start_time
          AND (v_mid_time>=pr.start_time OR v_mid_time<pr.end_time)
        )
      )
      AND (
        pr.start_date IS NULL
        OR (
          CASE
            WHEN pr.end_time<=pr.start_time AND v_mid_time<pr.end_time
              THEN v_mid_date-1
            ELSE v_mid_date
          END
        )>=pr.start_date
      )
      AND (
        pr.end_date IS NULL
        OR (
          CASE
            WHEN pr.end_time<=pr.start_time AND v_mid_time<pr.end_time
              THEN v_mid_date-1
            ELSE v_mid_date
          END
        )<=pr.end_date
      )
      AND extract(
        isodow FROM
        CASE
          WHEN pr.end_time<=pr.start_time AND v_mid_time<pr.end_time
            THEN v_mid_date-1
          ELSE v_mid_date
        END
      )::integer = ANY(pr.days_of_week)
    ORDER BY
      pr.priority DESC,
      (pr.room_id IS NOT NULL) DESC,
      (pr.space_type_id IS NOT NULL) DESC,
      pr.created_at DESC,
      pr.id
    LIMIT 1;

    IF FOUND THEN
      v_has_rule:=true;
      v_rate:=CASE v_match.adjustment_type
        WHEN 'multiplier' THEN v_base_rate*v_match.adjustment_value
        WHEN 'percentage' THEN
          v_base_rate*(1+(v_match.adjustment_value/100.0))
        WHEN 'fixed' THEN v_match.adjustment_value
        ELSE v_base_rate
      END;
    ELSE
      v_rate:=v_base_rate;
    END IF;

    v_rate:=GREATEST(0,round(v_rate,2));
    v_amount:=round((v_rate/60.0)*v_minutes,2);
    v_total:=v_total+v_amount;

    v_segments:=v_segments || jsonb_build_array(
      jsonb_build_object(
        'from',
          to_char(
            '00:00:00'::time
            + ((v_seg_start % 1440)::text || ' minutes')::interval,
            'HH24:MI:SS'
          ),
        'to',
          to_char(
            '00:00:00'::time
            + ((v_seg_end % 1440)::text || ' minutes')::interval,
            'HH24:MI:SS'
          ),
        'minutes',v_minutes,
        'rate',v_rate,
        'amount',v_amount,
        'rule_id',CASE WHEN FOUND THEN v_match.id ELSE NULL END,
        'rule_name_ar',CASE WHEN FOUND THEN v_match.name_ar ELSE NULL END,
        'rule_name_en',CASE WHEN FOUND THEN v_match.name_en ELSE NULL END
      )
    );
  END LOOP;

  v_avg_rate:=CASE
    WHEN v_duration>0 THEN round(v_total/(v_duration/60.0),2)
    ELSE v_base_rate
  END;

  RETURN jsonb_build_object(
    'room_id',p_room_id,
    'base_rate',v_base_rate,
    'effective_hourly_rate',v_avg_rate,
    'room_subtotal',round(v_total,2),
    'duration_minutes',v_duration,
    'has_peak_rates',v_has_rule,
    'segments',v_segments
  );
END;
$function$;

REVOKE ALL ON FUNCTION private.price_room_interval(
  uuid,date,time,time,text
) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.quote_booking_price(
  p_room_id uuid,
  p_date date,
  p_start time,
  p_end time,
  p_play_mode text DEFAULT 'single',
  p_extra_controllers integer DEFAULT 0,
  p_coupon_code text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_room public.rooms%ROWTYPE;
  v_pricing jsonb;
  v_duration_min integer;
  v_base_rate numeric;
  v_effective_rate numeric;
  v_room_subtotal numeric;
  v_controller_rate numeric:=0;
  v_controllers_amount numeric:=0;
  v_promo_type text;
  v_promo_value numeric:=0;
  v_promo_discount numeric:=0;
  v_voucher jsonb;
  v_voucher_discount numeric:=0;
  v_total_before_discount numeric;
  v_final_total numeric;
BEGIN
  SELECT r.* INTO v_room
  FROM public.rooms AS r
  WHERE r.id=p_room_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE='P0002';
  END IF;

  v_pricing:=private.price_room_interval(
    p_room_id,p_date,p_start,p_end,p_play_mode
  );
  v_duration_min:=(v_pricing->>'duration_minutes')::integer;
  v_base_rate:=(v_pricing->>'base_rate')::numeric;
  v_effective_rate:=(v_pricing->>'effective_hourly_rate')::numeric;
  v_room_subtotal:=(v_pricing->>'room_subtotal')::numeric;

  IF COALESCE(p_extra_controllers,0)>0 THEN
    v_controller_rate:=COALESCE(v_room.extra_controller_price,0);
    v_controllers_amount:=round(
      COALESCE(p_extra_controllers,0)
      * v_controller_rate
      * (v_duration_min/60.0),
      2
    );
  END IF;

  SELECT p.discount_type,COALESCE(p.discount_value,0)
  INTO v_promo_type,v_promo_value
  FROM public.promotions AS p
  WHERE p.is_active IS TRUE
    AND p.room_id=p_room_id
    AND COALESCE(p.discount_value,0)>0
    AND (p.expires_at IS NULL OR p.expires_at>now())
  ORDER BY p.created_at DESC,p.id DESC
  LIMIT 1;

  IF NOT FOUND THEN
    SELECT p.discount_type,COALESCE(p.discount_value,0)
    INTO v_promo_type,v_promo_value
    FROM public.promotions AS p
    WHERE p.is_active IS TRUE
      AND p.lounge_id=v_room.lounge_id
      AND p.room_id IS NULL
      AND COALESCE(p.is_room_specific,false) IS FALSE
      AND COALESCE(p.discount_value,0)>0
      AND (p.expires_at IS NULL OR p.expires_at>now())
    ORDER BY p.created_at DESC,p.id DESC
    LIMIT 1;
  END IF;

  IF FOUND AND v_promo_value>0 THEN
    IF lower(COALESCE(v_promo_type,'percentage'))='fixed' THEN
      v_promo_discount:=LEAST(v_room_subtotal,v_promo_value);
    ELSE
      v_promo_discount:=round(
        v_room_subtotal
        * LEAST(GREATEST(v_promo_value,0),100)/100.0,
        2
      );
    END IF;
  END IF;

  IF NULLIF(btrim(COALESCE(p_coupon_code,'')),'') IS NOT NULL THEN
    v_voucher:=public.validate_voucher_by_code(p_coupon_code);
    IF COALESCE((v_voucher->>'valid')::boolean,false) THEN
      IF v_voucher->>'reward_type'='discount_fixed' THEN
        v_voucher_discount:=COALESCE(
          (v_voucher->>'reward_value')::numeric,0
        );
      ELSIF v_voucher->>'reward_type'='free_hour' THEN
        v_voucher_discount:=LEAST(
          GREATEST(0,v_room_subtotal-v_promo_discount),
          v_effective_rate
          * COALESCE((v_voucher->>'reward_value')::numeric,0)
        );
      END IF;
    END IF;
  END IF;

  v_total_before_discount:=v_room_subtotal+v_controllers_amount;
  v_voucher_discount:=LEAST(
    v_voucher_discount,
    GREATEST(0,v_total_before_discount-v_promo_discount)
  );
  v_final_total:=GREATEST(
    0,
    v_total_before_discount-v_promo_discount-v_voucher_discount
  );

  RETURN jsonb_build_object(
    'room_id',p_room_id,
    'lounge_id',v_room.lounge_id,
    'date',p_date,
    'start_time',to_char(p_start,'HH24:MI:SS'),
    'end_time',to_char(p_end,'HH24:MI:SS'),
    'duration_minutes',v_duration_min,
    'play_mode',lower(COALESCE(NULLIF(btrim(p_play_mode),''),'single')),
    'base_rate',v_base_rate,
    'effective_hourly_rate',v_effective_rate,
    'room_subtotal',v_room_subtotal,
    'extra_controllers',COALESCE(p_extra_controllers,0),
    'controller_rate',v_controller_rate,
    'controllers_amount',v_controllers_amount,
    'addons_amount',0,
    'promo_discount_amount',v_promo_discount,
    'voucher_discount_amount',v_voucher_discount,
    'discount_amount',v_promo_discount+v_voucher_discount,
    'subtotal',v_total_before_discount,
    'final_total',round(v_final_total,2),
    'currency','EGP',
    'has_peak_rates',COALESCE((v_pricing->>'has_peak_rates')::boolean,false),
    'segments',COALESCE(v_pricing->'segments','[]'::jsonb)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_validate_and_clamp_booking_price()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE
  v_interval jsonb;
  v_room_subtotal numeric:=0;
  v_extra_controller_rate numeric:=0;
  v_controllers_amount numeric:=0;
  v_addons numeric:=0;
  v_subtotal numeric:=0;
  v_discount numeric:=0;
  v_snap jsonb;
  v_actual_hourly_rate numeric:=0;
BEGIN
  IF current_setting('app.skip_price_clamp',true)='true' THEN
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.is_open_time,false) IS TRUE
     AND NEW.status='in_progress'::public.booking_status THEN
    NEW.duration_minutes:=GREATEST(1,COALESCE(NEW.duration_minutes,1));
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.duration_minutes,0)<=0 OR NEW.duration_minutes>1440 THEN
    RAISE EXCEPTION
      'Invalid booking duration: % minutes. Duration must be between 1 and 1440 minutes.',
      NEW.duration_minutes USING ERRCODE='22023';
  END IF;

  IF NEW.room_id IS NULL THEN
    RAISE EXCEPTION 'Cannot validate booking price: room_id is required.'
      USING ERRCODE='22023';
  END IF;

  IF COALESCE(NEW.is_open_time,false) IS TRUE
     AND NEW.open_time_pricing_snapshot IS NOT NULL
     AND NEW.open_time_pricing_snapshot<>'{}'::jsonb THEN
    v_snap:=NEW.open_time_pricing_snapshot;
    v_actual_hourly_rate:=COALESCE(
      (v_snap->>'effective_hourly_rate')::numeric,
      (v_snap->>'base_hourly_rate')::numeric,
      50
    );
    v_room_subtotal:=round(
      (NEW.duration_minutes/60.0)*v_actual_hourly_rate,
      2
    );
  ELSE
    IF NEW.date IS NULL OR NEW.start_time IS NULL OR NEW.end_time IS NULL THEN
      RAISE EXCEPTION 'Booking date/start/end are required for pricing'
        USING ERRCODE='22023';
    END IF;

    v_interval:=private.price_room_interval(
      NEW.room_id,
      NEW.date,
      NEW.start_time,
      NEW.end_time,
      COALESCE(NEW.play_mode,'single')
    );
    v_room_subtotal:=COALESCE(
      (v_interval->>'room_subtotal')::numeric,0
    );
  END IF;

  SELECT
    GREATEST(0,COALESCE(NEW.extra_controllers,0))
    * COALESCE(r.extra_controller_price,0)
    * (NEW.duration_minutes/60.0)
  INTO v_controllers_amount
  FROM public.rooms AS r
  WHERE r.id=NEW.room_id;

  IF COALESCE(NEW.is_open_time,false) IS FALSE
     OR NEW.status='completed'::public.booking_status THEN
    NEW.room_price:=round(
      v_room_subtotal+COALESCE(v_controllers_amount,0),
      2
    );
  END IF;

  v_addons:=GREATEST(
    0,COALESCE(NEW.addons_price,NEW.addons_total,0)
  );
  NEW.addons_price:=v_addons;
  NEW.addons_total:=v_addons;

  v_subtotal:=NEW.room_price+v_addons;

  IF COALESCE(NEW.discount_amount,0)>0 THEN
    v_discount:=LEAST(v_subtotal,NEW.discount_amount);
  ELSIF COALESCE(NEW.discount_percentage,0)>0 THEN
    v_discount:=LEAST(
      v_subtotal,
      v_subtotal*(NEW.discount_percentage/100.0)
    );
  ELSE
    v_discount:=0;
  END IF;

  NEW.discount_amount:=v_discount;
  NEW.total_price:=GREATEST(0,v_subtotal-v_discount);

  RETURN NEW;
END;
$function$;

COMMIT;
