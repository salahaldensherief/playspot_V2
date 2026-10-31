BEGIN;

CREATE OR REPLACE FUNCTION public.batch_complete_onboarding_v2(
  p_lounge_id uuid,
  p_lounge_data jsonb,
  p_rooms jsonb,
  p_extras jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_room jsonb;
  v_room_id uuid;
  v_activity_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication is required' USING ERRCODE='28000';
  END IF;

  PERFORM public.batch_complete_onboarding(
    p_lounge_id,
    p_lounge_data,
    p_rooms,
    p_extras
  );

  FOR v_room IN
    SELECT value
    FROM jsonb_array_elements(COALESCE(p_rooms,'[]'::jsonb))
  LOOP
    BEGIN
      v_room_id := (v_room->>'id')::uuid;
    EXCEPTION
      WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'INVALID_ONBOARDING_ROOM_ID'
          USING ERRCODE='22023';
    END;

    IF NOT EXISTS (
      SELECT 1
      FROM public.rooms AS r
      WHERE r.id = v_room_id
        AND r.lounge_id = p_lounge_id
    ) THEN
      RAISE EXCEPTION 'ONBOARDING_ROOM_SCOPE_MISMATCH'
        USING ERRCODE='42501';
    END IF;

    UPDATE public.rooms AS r
    SET resource_type = CASE
          WHEN v_room ? 'resource_type'
          THEN NULLIF(btrim(v_room->>'resource_type'),'')
          ELSE r.resource_type
        END,
        requires_screen = CASE
          WHEN v_room ? 'requires_screen'
          THEN (v_room->>'requires_screen')::boolean
          ELSE r.requires_screen
        END,
        requires_controllers = CASE
          WHEN v_room ? 'requires_controllers'
          THEN (v_room->>'requires_controllers')::boolean
          ELSE r.requires_controllers
        END,
        pricing_model = CASE
          WHEN v_room ? 'pricing_model'
          THEN NULLIF(btrim(v_room->>'pricing_model'),'')
          ELSE r.pricing_model
        END,
        open_time_enabled = CASE
          WHEN v_room ? 'open_time_enabled'
          THEN (v_room->>'open_time_enabled')::boolean
          ELSE r.open_time_enabled
        END,
        open_time_pricing_mode = CASE
          WHEN v_room ? 'open_time_pricing_mode'
          THEN NULLIF(btrim(v_room->>'open_time_pricing_mode'),'')
          ELSE r.open_time_pricing_mode
        END,
        open_time_custom_hourly_rate = CASE
          WHEN v_room ? 'open_time_custom_hourly_rate'
          THEN NULLIF(v_room->>'open_time_custom_hourly_rate','')::numeric
          ELSE r.open_time_custom_hourly_rate
        END,
        open_time_price_multiplier = CASE
          WHEN v_room ? 'open_time_price_multiplier'
          THEN COALESCE(NULLIF(v_room->>'open_time_price_multiplier','')::numeric,1)
          ELSE r.open_time_price_multiplier
        END,
        open_time_minimum_minutes = CASE
          WHEN v_room ? 'open_time_minimum_minutes'
          THEN COALESCE(NULLIF(v_room->>'open_time_minimum_minutes','')::integer,30)
          ELSE r.open_time_minimum_minutes
        END,
        open_time_rounding_minutes = CASE
          WHEN v_room ? 'open_time_rounding_minutes'
          THEN COALESCE(NULLIF(v_room->>'open_time_rounding_minutes','')::integer,15)
          ELSE r.open_time_rounding_minutes
        END,
        open_time_max_minutes = CASE
          WHEN v_room ? 'open_time_max_minutes'
          THEN NULLIF(v_room->>'open_time_max_minutes','')::integer
          ELSE r.open_time_max_minutes
        END,
        open_time_buffer_before_booking_minutes = CASE
          WHEN v_room ? 'open_time_buffer_before_booking_minutes'
          THEN COALESCE(
            NULLIF(v_room->>'open_time_buffer_before_booking_minutes','')::integer,
            15
          )
          ELSE r.open_time_buffer_before_booking_minutes
        END,
        updated_at = now()
    WHERE r.id = v_room_id;

    IF v_room ? 'activity_ids' THEN
      IF jsonb_typeof(v_room->'activity_ids') <> 'array' THEN
        RAISE EXCEPTION 'ROOM_ACTIVITY_IDS_MUST_BE_ARRAY'
          USING ERRCODE='22023';
      END IF;

      DELETE FROM public.room_activities
      WHERE room_id = v_room_id;

      FOR v_activity_id IN
        SELECT value::uuid
        FROM jsonb_array_elements_text(v_room->'activity_ids')
      LOOP
        IF NOT EXISTS (
          SELECT 1
          FROM public.activity_types AS a
          WHERE a.id = v_activity_id
        ) THEN
          RAISE EXCEPTION 'UNKNOWN_ACTIVITY_TYPE: %', v_activity_id
            USING ERRCODE='22023';
        END IF;

        INSERT INTO public.room_activities(room_id,activity_type_id)
        VALUES(v_room_id,v_activity_id)
        ON CONFLICT DO NOTHING;
      END LOOP;
    END IF;
  END LOOP;
END;
$function$;

REVOKE ALL ON FUNCTION public.batch_complete_onboarding_v2(
  uuid,jsonb,jsonb,jsonb
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.batch_complete_onboarding_v2(
  uuid,jsonb,jsonb,jsonb
) TO authenticated, service_role;

COMMIT;
