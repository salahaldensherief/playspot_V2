-- ============================================================================
-- Migration: 20260930180000_p2_multi_resource_and_activities_layer.sql
-- Description: Phase 5 (P2) Multi-Resource & Activities Layer
--              Support PlayStation, Billiards, Table Tennis, VR, Multi-Screen,
--              Board Games, Flexible Resource Attributes & Capabilities.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Schema Extensions for public.activity_types
-- ----------------------------------------------------------------------------

ALTER TABLE public.activity_types
  ADD COLUMN IF NOT EXISTS category text DEFAULT 'console',
  ADD COLUMN IF NOT EXISTS requires_screen boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS requires_controllers boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS icon_name text DEFAULT 'sports_esports',
  ADD COLUMN IF NOT EXISTS pricing_model text DEFAULT 'per_room_hour',
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- Update capability defaults and icons for existing activity types
UPDATE public.activity_types
SET
  category = 'table_sport',
  requires_screen = false,
  requires_controllers = false,
  icon_name = 'sports_pool',
  pricing_model = 'per_room_hour'
WHERE name = 'billiard';

UPDATE public.activity_types
SET
  category = 'table_sport',
  requires_screen = false,
  requires_controllers = false,
  icon_name = 'sports_tennis',
  pricing_model = 'per_room_hour'
WHERE name = 'table_tennis';

UPDATE public.activity_types
SET
  category = 'table_sport',
  requires_screen = false,
  requires_controllers = false,
  icon_name = 'sports_soccer',
  pricing_model = 'per_room_hour'
WHERE name = 'foosball';

UPDATE public.activity_types
SET
  category = 'table_sport',
  requires_screen = false,
  requires_controllers = false,
  icon_name = 'adjust',
  pricing_model = 'per_room_hour'
WHERE name = 'darts';

UPDATE public.activity_types
SET
  category = 'vr',
  requires_screen = true,
  requires_controllers = true,
  icon_name = 'view_in_ar',
  pricing_model = 'per_room_hour'
WHERE name = 'vr';

UPDATE public.activity_types
SET
  category = 'simulator',
  requires_screen = true,
  requires_controllers = true,
  icon_name = 'sports_motorsports',
  pricing_model = 'per_room_hour'
WHERE name = 'simulator';

UPDATE public.activity_types
SET
  category = 'pc',
  requires_screen = true,
  requires_controllers = false,
  icon_name = 'desktop_windows',
  pricing_model = 'per_room_hour'
WHERE name = 'pc';

UPDATE public.activity_types
SET
  category = 'board_game',
  requires_screen = false,
  requires_controllers = false,
  icon_name = 'casino',
  pricing_model = 'per_room_hour'
WHERE name = 'board_games';

UPDATE public.activity_types
SET
  category = 'entertainment',
  requires_screen = true,
  requires_controllers = false,
  icon_name = 'mic',
  pricing_model = 'per_room_hour'
WHERE name = 'karaoke';

UPDATE public.activity_types
SET
  category = 'entertainment',
  requires_screen = true,
  requires_controllers = false,
  icon_name = 'sports',
  pricing_model = 'per_room_hour'
WHERE name = 'bowling';

UPDATE public.activity_types
SET
  category = 'arcade',
  requires_screen = true,
  requires_controllers = true,
  icon_name = 'videogame_asset',
  pricing_model = 'per_room_hour'
WHERE name = 'arcade';

UPDATE public.activity_types
SET
  category = 'console',
  requires_screen = true,
  requires_controllers = true,
  icon_name = 'sports_esports',
  pricing_model = 'single_multi_hour'
WHERE name IN ('ps5', 'ps4', 'playstation', 'xbox');

-- ----------------------------------------------------------------------------
-- 2. Schema Extensions for public.rooms
-- ----------------------------------------------------------------------------

ALTER TABLE public.rooms
  ADD COLUMN IF NOT EXISTS resource_type text DEFAULT 'console',
  ADD COLUMN IF NOT EXISTS resource_attributes jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS requires_screen boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS requires_controllers boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS pricing_model text DEFAULT 'per_room_hour',
  ADD COLUMN IF NOT EXISTS min_capacity integer DEFAULT 1;

-- Add check constraint for pricing_model and min_capacity
ALTER TABLE public.rooms
  DROP CONSTRAINT IF EXISTS rooms_pricing_model_check;

ALTER TABLE public.rooms
  ADD CONSTRAINT rooms_pricing_model_check
  CHECK (pricing_model IN ('per_room_hour', 'per_person_hour', 'single_multi_hour'));

ALTER TABLE public.rooms
  DROP CONSTRAINT IF EXISTS rooms_min_capacity_check;

ALTER TABLE public.rooms
  ADD CONSTRAINT rooms_min_capacity_check
  CHECK (min_capacity >= 1);

-- Backfill existing rooms cleanly
UPDATE public.rooms
SET
  resource_type = COALESCE(device_type, 'console'),
  pricing_model = CASE
    WHEN hourly_rate_multi IS NOT NULL AND hourly_rate_multi <> hourly_rate_single THEN 'single_multi_hour'
    ELSE 'per_room_hour'
  END,
  requires_screen = CASE
    WHEN screen_size IS NOT NULL AND screen_size <> '' AND screen_size <> 'N/A' THEN true
    ELSE true
  END,
  requires_controllers = CASE
    WHEN controllers_count IS NOT NULL AND controllers_count > 0 THEN true
    ELSE false
  END
WHERE resource_type IS NULL OR resource_type = 'console';

-- ----------------------------------------------------------------------------
-- 3. Room Resource Trigger for Automated Capabilities Sync
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_sync_room_resource_capabilities()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_primary_act RECORD;
BEGIN
  -- Infer resource_type and capabilities from activity_types if not explicitly set
  IF NEW.resource_type IS NULL OR NEW.resource_type = '' THEN
    SELECT a.* INTO v_primary_act
    FROM public.room_activities ra
    JOIN public.activity_types a ON a.id = ra.activity_type_id
    WHERE ra.room_id = NEW.id
    ORDER BY a.sort_order ASC
    LIMIT 1;

    IF FOUND THEN
      NEW.resource_type := v_primary_act.name;
      IF NEW.requires_screen IS NULL THEN
        NEW.requires_screen := v_primary_act.requires_screen;
      END IF;
      IF NEW.requires_controllers IS NULL THEN
        NEW.requires_controllers := v_primary_act.requires_controllers;
      END IF;
      IF NEW.pricing_model IS NULL THEN
        NEW.pricing_model := v_primary_act.pricing_model;
      END IF;
    ELSE
      NEW.resource_type := 'console';
    END IF;
  END IF;

  -- Table sports (Billiards, Table Tennis, Foosball, Darts) do not require controllers or screens
  IF NEW.resource_type IN ('billiard', 'table_tennis', 'foosball', 'darts', 'board_games') THEN
    IF NEW.requires_screen IS NULL THEN
      NEW.requires_screen := false;
    END IF;
    IF NEW.requires_controllers IS NULL THEN
      NEW.requires_controllers := false;
    END IF;
    IF NEW.controllers_count IS NULL THEN
      NEW.controllers_count := 0;
    END IF;
  END IF;

  IF NEW.resource_attributes IS NULL THEN
    NEW.resource_attributes := '{}'::jsonb;
  END IF;

  IF NEW.min_capacity IS NULL OR NEW.min_capacity < 1 THEN
    NEW.min_capacity := 1;
  END IF;

  IF NEW.max_capacity IS NULL OR NEW.max_capacity < NEW.min_capacity THEN
    NEW.max_capacity := GREATEST(4, NEW.min_capacity);
  END IF;

  NEW.updated_at := now();

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_room_resource_capabilities ON public.rooms;
CREATE TRIGGER trg_sync_room_resource_capabilities
  BEFORE INSERT OR UPDATE ON public.rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_room_resource_capabilities();

-- ----------------------------------------------------------------------------
-- 4. RLS Policy for room_activities Management
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS room_activities_manage_staff ON public.room_activities;
CREATE POLICY room_activities_manage_staff
ON public.room_activities
FOR ALL
TO authenticated
USING (
  public.is_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.rooms r
    WHERE r.id = room_activities.room_id
      AND public.has_lounge_permission(r.lounge_id, 'rooms_manage')
  )
)
WITH CHECK (
  public.is_super_admin()
  OR EXISTS (
    SELECT 1 FROM public.rooms r
    WHERE r.id = room_activities.room_id
      AND public.has_lounge_permission(r.lounge_id, 'rooms_manage')
  )
);

-- ----------------------------------------------------------------------------
-- 5. RPC: get_lounge_activities (Activity Catalog with Aggregated Room Metrics)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_lounge_activities(
  p_lounge_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_activities jsonb;
BEGIN
  IF p_lounge_id IS NULL THEN
    RAISE EXCEPTION 'Lounge ID is required' USING ERRCODE = '22023';
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'activity_id', sub.activity_id,
      'name', sub.name,
      'label', sub.label,
      'category', sub.category,
      'icon_name', sub.icon_name,
      'requires_screen', sub.requires_screen,
      'requires_controllers', sub.requires_controllers,
      'pricing_model', sub.pricing_model,
      'rooms_count', sub.rooms_count,
      'available_rooms_count', sub.available_rooms_count,
      'min_hourly_rate', sub.min_rate,
      'max_hourly_rate', sub.max_rate
    )
    ORDER BY sub.sort_order ASC, sub.rooms_count DESC
  )
  INTO v_activities
  FROM (
    SELECT
      a.id AS activity_id,
      a.name,
      a.label,
      COALESCE(a.category, 'console') AS category,
      COALESCE(a.icon_name, 'sports_esports') AS icon_name,
      COALESCE(a.requires_screen, true) AS requires_screen,
      COALESCE(a.requires_controllers, true) AS requires_controllers,
      COALESCE(a.pricing_model, 'per_room_hour') AS pricing_model,
      a.sort_order,
      count(r.id) AS rooms_count,
      count(r.id) FILTER (WHERE r.is_available IS TRUE AND r.status = 'available') AS available_rooms_count,
      ROUND(COALESCE(min(r.hourly_rate_single), 0), 2) AS min_rate,
      ROUND(COALESCE(max(r.hourly_rate_single), 0), 2) AS max_rate
    FROM public.activity_types a
    JOIN public.room_activities ra ON ra.activity_type_id = a.id
    JOIN public.rooms r ON r.id = ra.room_id
    WHERE r.lounge_id = p_lounge_id
      AND COALESCE(r.is_active, true) IS TRUE
      AND COALESCE(r.status, 'available') <> 'deleted'
    GROUP BY a.id, a.name, a.label, a.category, a.icon_name, a.requires_screen,
             a.requires_controllers, a.pricing_model, a.sort_order
  ) AS sub;

  RETURN COALESCE(v_activities, '[]'::jsonb);
END;
$function$;

REVOKE ALL ON FUNCTION public.get_lounge_activities(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_lounge_activities(uuid) TO authenticated, anon, service_role;

-- ----------------------------------------------------------------------------
-- 6. RPC: get_rooms_by_activity (Filtered Room Discovery & Capabilities)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_rooms_by_activity(
  p_lounge_id uuid,
  p_activity_id uuid,
  p_date date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_rooms jsonb;
  v_eval_date date := COALESCE(p_date, (now() AT TIME ZONE 'Africa/Cairo')::date);
BEGIN
  IF p_lounge_id IS NULL OR p_activity_id IS NULL THEN
    RAISE EXCEPTION 'Lounge ID and Activity ID are required' USING ERRCODE = '22023';
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', r.id,
      'lounge_id', r.lounge_id,
      'name', r.name,
      'name_ar', r.name_ar,
      'name_en', r.name_en,
      'resource_type', r.resource_type,
      'resource_attributes', COALESCE(r.resource_attributes, '{}'::jsonb),
      'requires_screen', COALESCE(r.requires_screen, true),
      'requires_controllers', COALESCE(r.requires_controllers, true),
      'controllers_count', COALESCE(r.controllers_count, 0),
      'screen_size', r.screen_size,
      'pricing_model', COALESCE(r.pricing_model, 'per_room_hour'),
      'hourly_rate_single', r.hourly_rate_single,
      'hourly_rate_multi', r.hourly_rate_multi,
      'hourly_rate', r.hourly_rate,
      'extra_controller_price', COALESCE(r.extra_controller_price, 0),
      'min_capacity', COALESCE(r.min_capacity, 1),
      'max_capacity', COALESCE(r.max_capacity, 4),
      'is_available', r.is_available,
      'status', r.status,
      'images', COALESCE(to_jsonb(r.images), '[]'::jsonb),
      'features', COALESCE(to_jsonb(r.features), '[]'::jsonb),
      'space_type_id', r.space_type_id,
      'has_active_bookings_on_date', EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.room_id = r.id
          AND b.date = v_eval_date
          AND b.status IN ('pending'::public.booking_status,
                           'upcoming'::public.booking_status,
                           'in_progress'::public.booking_status)
      )
    )
    ORDER BY r.name ASC
  )
  INTO v_rooms
  FROM public.rooms r
  JOIN public.room_activities ra ON ra.room_id = r.id
  WHERE r.lounge_id = p_lounge_id
    AND ra.activity_type_id = p_activity_id
    AND COALESCE(r.is_active, true) IS TRUE
    AND COALESCE(r.status, 'available') <> 'deleted';

  RETURN COALESCE(v_rooms, '[]'::jsonb);
END;
$function$;

REVOKE ALL ON FUNCTION public.get_rooms_by_activity(uuid, uuid, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_rooms_by_activity(uuid, uuid, date) TO authenticated, anon, service_role;

-- ----------------------------------------------------------------------------
-- 7. RPC: validate_resource_booking_constraints
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.validate_resource_booking_constraints(
  p_room_id uuid,
  p_players_count integer,
  p_extra_attributes jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_room public.rooms%ROWTYPE;
BEGIN
  IF p_room_id IS NULL THEN
    RAISE EXCEPTION 'Room ID is required' USING ERRCODE = '22023';
  END IF;

  SELECT r.* INTO v_room
  FROM public.rooms r
  WHERE r.id = p_room_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error_code', 'ROOM_NOT_FOUND',
      'message', 'Room not found'
    );
  END IF;

  IF p_players_count IS NOT NULL THEN
    IF p_players_count < COALESCE(v_room.min_capacity, 1) THEN
      RETURN jsonb_build_object(
        'valid', false,
        'error_code', 'CAPACITY_UNDERFLOW',
        'message', 'Player count is below minimum required capacity (' || COALESCE(v_room.min_capacity, 1) || ')'
      );
    END IF;

    IF p_players_count > COALESCE(v_room.max_capacity, 4) THEN
      RETURN jsonb_build_object(
        'valid', false,
        'error_code', 'CAPACITY_EXCEEDED',
        'message', 'Player count exceeds maximum room capacity (' || COALESCE(v_room.max_capacity, 4) || ')'
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'valid', true,
    'room_id', v_room.id,
    'resource_type', v_room.resource_type,
    'pricing_model', v_room.pricing_model,
    'min_capacity', v_room.min_capacity,
    'max_capacity', v_room.max_capacity,
    'requires_screen', v_room.requires_screen,
    'requires_controllers', v_room.requires_controllers
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.validate_resource_booking_constraints(uuid, integer, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_resource_booking_constraints(uuid, integer, jsonb) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 8. Enhanced Atomic save_lounge_room (Multi-Resource & Capabilities Support)
-- ----------------------------------------------------------------------------

-- Drop older 10-parameter signature to prevent ambiguous overload dispatch in PostgreSQL/PostgREST
DROP FUNCTION IF EXISTS public.save_lounge_room(uuid, uuid, text, uuid, numeric, numeric, numeric, uuid[], integer, boolean);

CREATE OR REPLACE FUNCTION public.save_lounge_room(
  p_room_id uuid,
  p_lounge_id uuid,
  p_name text,
  p_category_id uuid DEFAULT NULL::uuid,
  p_single_price numeric DEFAULT 0,
  p_multi_price numeric DEFAULT 0,
  p_extra_controller_price numeric DEFAULT 0,
  p_activity_ids uuid[] DEFAULT ARRAY[]::uuid[],
  p_max_capacity integer DEFAULT 4,
  p_open_time_enabled boolean DEFAULT true,
  p_resource_type text DEFAULT 'console',
  p_resource_attributes jsonb DEFAULT '{}'::jsonb,
  p_requires_screen boolean DEFAULT NULL,
  p_requires_controllers boolean DEFAULT NULL,
  p_pricing_model text DEFAULT 'per_room_hour',
  p_min_capacity integer DEFAULT 1,
  p_controllers_count integer DEFAULT NULL,
  p_screen_size text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_room_id uuid;
  v_activity_id uuid;
  v_existing_lounge_id uuid;
  v_req_screen boolean;
  v_req_controllers boolean;
  v_norm_controllers integer;
  v_norm_screen text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  IF p_lounge_id IS NULL THEN
    RAISE EXCEPTION 'Lounge ID is required' USING ERRCODE = '22023';
  END IF;

  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Room name is required' USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_super_admin()
     AND NOT public.has_lounge_permission(p_lounge_id, 'rooms_manage') THEN
    RAISE EXCEPTION 'Not authorized to manage rooms in this lounge' USING ERRCODE = '42501';
  END IF;

  IF COALESCE(p_single_price, 0) < 0 OR COALESCE(p_multi_price, 0) < 0 OR COALESCE(p_extra_controller_price, 0) < 0 THEN
    RAISE EXCEPTION 'Prices must be non-negative' USING ERRCODE = '22023';
  END IF;

  IF COALESCE(p_min_capacity, 1) < 1 THEN
    RAISE EXCEPTION 'Min capacity must be at least 1' USING ERRCODE = '22023';
  END IF;

  IF COALESCE(p_max_capacity, 1) < COALESCE(p_min_capacity, 1) THEN
    RAISE EXCEPTION 'Max capacity must be greater than or equal to min capacity' USING ERRCODE = '22023';
  END IF;

  -- Validate room does not belong to another lounge if updating
  IF p_room_id IS NOT NULL THEN
    SELECT r.lounge_id
    INTO v_existing_lounge_id
    FROM public.rooms AS r
    WHERE r.id = p_room_id;

    IF FOUND AND v_existing_lounge_id IS DISTINCT FROM p_lounge_id THEN
      RAISE EXCEPTION 'Cannot modify room belonging to another lounge' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Capability normalization for table games (Billiards, Table Tennis, etc.)
  IF p_resource_type IN ('billiard', 'table_tennis', 'foosball', 'darts', 'board_games') THEN
    v_req_screen := COALESCE(p_requires_screen, false);
    v_req_controllers := COALESCE(p_requires_controllers, false);
    v_norm_controllers := COALESCE(p_controllers_count, 0);
    v_norm_screen := COALESCE(p_screen_size, NULL);
  ELSE
    v_req_screen := COALESCE(p_requires_screen, true);
    v_req_controllers := COALESCE(p_requires_controllers, true);
    v_norm_controllers := COALESCE(p_controllers_count, 2);
    v_norm_screen := COALESCE(p_screen_size, '43"');
  END IF;

  -- Atomic Upsert of room
  INSERT INTO public.rooms (
    id,
    lounge_id,
    name,
    name_ar,
    name_en,
    hourly_rate_single,
    hourly_rate_multi,
    extra_controller_price,
    min_capacity,
    max_capacity,
    is_available,
    status,
    resource_type,
    resource_attributes,
    requires_screen,
    requires_controllers,
    pricing_model,
    controllers_count,
    screen_size,
    open_time_enabled,
    space_type_id,
    updated_at
  ) VALUES (
    COALESCE(p_room_id, gen_random_uuid()),
    p_lounge_id,
    p_name,
    p_name,
    p_name,
    p_single_price,
    p_multi_price,
    p_extra_controller_price,
    p_min_capacity,
    p_max_capacity,
    true,
    'available',
    COALESCE(p_resource_type, 'console'),
    COALESCE(p_resource_attributes, '{}'::jsonb),
    v_req_screen,
    v_req_controllers,
    COALESCE(p_pricing_model, 'per_room_hour'),
    v_norm_controllers,
    v_norm_screen,
    COALESCE(p_open_time_enabled, true),
    p_category_id,
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    name_ar = EXCLUDED.name_ar,
    name_en = EXCLUDED.name_en,
    hourly_rate_single = EXCLUDED.hourly_rate_single,
    hourly_rate_multi = EXCLUDED.hourly_rate_multi,
    extra_controller_price = EXCLUDED.extra_controller_price,
    min_capacity = EXCLUDED.min_capacity,
    max_capacity = EXCLUDED.max_capacity,
    resource_type = EXCLUDED.resource_type,
    resource_attributes = EXCLUDED.resource_attributes,
    requires_screen = EXCLUDED.requires_screen,
    requires_controllers = EXCLUDED.requires_controllers,
    pricing_model = EXCLUDED.pricing_model,
    controllers_count = EXCLUDED.controllers_count,
    screen_size = EXCLUDED.screen_size,
    open_time_enabled = EXCLUDED.open_time_enabled,
    space_type_id = COALESCE(EXCLUDED.space_type_id, public.rooms.space_type_id),
    updated_at = now()
  RETURNING id INTO v_room_id;

  -- Synchronize activities atomically
  DELETE FROM public.room_activities
  WHERE room_id = v_room_id;

  IF p_activity_ids IS NOT NULL AND cardinality(p_activity_ids) > 0 THEN
    FOREACH v_activity_id IN ARRAY p_activity_ids
    LOOP
      IF EXISTS (SELECT 1 FROM public.activity_types WHERE id = v_activity_id) THEN
        INSERT INTO public.room_activities (room_id, activity_type_id)
        VALUES (v_room_id, v_activity_id)
        ON CONFLICT DO NOTHING;
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'room_id', v_room_id,
    'lounge_id', p_lounge_id,
    'name', p_name,
    'resource_type', COALESCE(p_resource_type, 'console'),
    'pricing_model', COALESCE(p_pricing_model, 'per_room_hour'),
    'min_capacity', p_min_capacity,
    'max_capacity', p_max_capacity,
    'requires_screen', v_req_screen,
    'requires_controllers', v_req_controllers,
    'controllers_count', v_norm_controllers,
    'screen_size', v_norm_screen,
    'activities_count', COALESCE(cardinality(p_activity_ids), 0)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.save_lounge_room(uuid, uuid, text, uuid, numeric, numeric, numeric, uuid[], integer, boolean, text, jsonb, boolean, boolean, text, integer, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_lounge_room(uuid, uuid, text, uuid, numeric, numeric, numeric, uuid[], integer, boolean, text, jsonb, boolean, boolean, text, integer, integer, text) TO authenticated, service_role;

COMMIT;
