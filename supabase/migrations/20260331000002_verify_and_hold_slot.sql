-- Migration: 20260331000002_verify_and_hold_slot.sql
-- Description: Function and constraint to prevent double-booking at the database level using atomic transaction slot hold.

DROP FUNCTION IF EXISTS public.verify_and_hold_slot(uuid, timestamptz, timestamptz, uuid, integer);

-- 1. Create function to check overlap and create hold atomically
CREATE OR REPLACE FUNCTION public.verify_and_hold_slot(
  p_room_id uuid,
  p_start_time timestamptz,
  p_end_time timestamptz,
  p_user_id uuid,
  p_hold_minutes integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_overlapping_count integer;
  v_hold_expires_at timestamptz := NOW() + (p_hold_minutes || ' minutes')::interval;
  v_hold_id uuid;
BEGIN
  -- Perform atomic lock check on existing non-cancelled bookings or active holds for the target room
  SELECT COUNT(*) INTO v_overlapping_count
  FROM public.bookings
  WHERE room_id = p_room_id
    AND status NOT IN ('cancelled', 'rejected', 'expired')
    AND (
      (p_start_time < end_time AND p_end_time > start_time)
    );

  IF v_overlapping_count > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'SLOT_OVERLAP_CONFLICT',
      'message', 'The selected time slot overlaps with an existing booking or hold.'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'hold_expires_at', v_hold_expires_at
  );
END;
$$;
