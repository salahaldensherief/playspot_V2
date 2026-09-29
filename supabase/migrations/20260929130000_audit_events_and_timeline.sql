BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- -----------------------------------------------------------------------------
-- 1. Event Catalog
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.event_catalog (
  code text PRIMARY KEY,
  entity_type text NOT NULL,
  default_severity text NOT NULL CHECK (default_severity IN ('info', 'warning', 'critical')),
  label_key text NOT NULL,
  title_ar text NOT NULL,
  title_en text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Seed Event Catalog
INSERT INTO public.event_catalog (
  code, entity_type, default_severity, label_key, title_ar, title_en, description
) VALUES
  ('booking_created', 'booking', 'info', 'events.booking.created', 'تم إنشاء الحجز', 'Booking Placed', 'إنشاء حجز جديد بواسطة العميل أو الكاشير'),
  ('booking_approved', 'booking', 'info', 'events.booking.approved', 'تمت الموافقة على الحجز', 'Booking Approved', 'تأكيد الحجز وقبوله'),
  ('booking_checked_in', 'booking', 'info', 'events.booking.checked_in', 'بدء الجلسة / الدخول', 'Session Checked In', 'تسجيل دخول العميل وبدء استخدام الغرفة'),
  ('booking_extension_requested', 'booking', 'info', 'events.booking.extension_requested', 'طلب تمديد الوقت', 'Extension Requested', 'طلب تمديد وقت الجلسة الحالية'),
  ('booking_extension_approved', 'booking', 'info', 'events.booking.extension_approved', 'الموافقة على التمديد', 'Extension Approved', 'الموافقة على تمديد وقت الجلسة وإضافة الوقت'),
  ('booking_extension_rejected', 'booking', 'info', 'events.booking.extension_rejected', 'رفض تمديد الوقت', 'Extension Rejected', 'رفض طلب تمديد الجلسة لعدم التوفر'),
  ('booking_completed', 'booking', 'info', 'events.booking.completed', 'إكمال الحجز', 'Booking Completed', 'انتهاء الجلسة وإغلاق الحساب'),
  ('booking_cancelled', 'booking', 'warning', 'events.booking.cancelled', 'إلغاء الحجز', 'Booking Cancelled', 'إلغاء الحجز مع ذكر السبب'),
  ('payment_collected', 'payment', 'info', 'events.payment.collected', 'تحصيل دفعة مالية', 'Payment Collected', 'تسجيل عملية دفع ناجحة'),
  ('payment_refunded', 'payment', 'warning', 'events.payment.refunded', 'استرداد دفعة مالية', 'Payment Refunded', 'استرداد مبلغ مالي للعميل'),
  ('shift_opened', 'shift', 'info', 'events.shift.opened', 'فتح وردية جديدة', 'Shift Opened', 'بدء وردية كاشير برصيد افتتاح'),
  ('shift_closed', 'shift', 'info', 'events.shift.closed', 'إغلاق الوردية', 'Shift Closed', 'إنهاء وردية الكاشير وجرد المبالغ'),
  ('shift_expense_logged', 'shift_expense', 'info', 'events.shift_expense.logged', 'تسجيل مصروف', 'Expense Logged', 'تسجيل مصروفات نقدية داخل الوردية'),
  ('room_price_changed', 'room', 'info', 'events.room.price_changed', 'تعديل تسعير الغرفة', 'Room Price Updated', 'تعديل أسعار الغرفة الفردية أو المتعددة'),
  ('room_status_changed', 'room', 'info', 'events.room.status_changed', 'تغيير حالة الغرفة', 'Room Status Changed', 'تغيير حالة توفر الغرفة أو صيانتها'),
  ('lounge_settings_changed', 'lounge', 'info', 'events.lounge.settings_changed', 'تعديل إعدادات اللاونج', 'Lounge Settings Updated', 'تعديل أرقام الدفع أو مواعيد التشغيل'),
  ('permission_changed', 'permission', 'critical', 'events.permission.changed', 'تعديل الصلاحيات والأدوار', 'Permissions Changed', 'تعديل صلاحيات موظف أو دور داخل اللاونج'),
  ('profile_banned', 'profile', 'warning', 'events.profile.banned', 'حظر مستخدم', 'User Banned', 'حظر حساب مستخدم من قبل الإدارة'),
  ('points_adjusted', 'points', 'warning', 'events.points.adjusted', 'تعديل رصيد النقاط', 'Points Adjusted', 'تعديل رصيد نقاط الولاء يدوياً'),
  ('tournament_started', 'tournament', 'info', 'events.tournament.started', 'بدء البطولة', 'Tournament Started', 'انطلاق فعاليات البطولة'),
  ('tournament_match_finished', 'tournament_match', 'info', 'events.tournament.match_finished', 'تسجيل نتيجة مباراة', 'Tournament Match Recorded', 'اعتماد نتيجة مباراة بطولة')
ON CONFLICT (code) DO UPDATE SET
  entity_type = EXCLUDED.entity_type,
  default_severity = EXCLUDED.default_severity,
  label_key = EXCLUDED.label_key,
  title_ar = EXCLUDED.title_ar,
  title_en = EXCLUDED.title_en,
  description = EXCLUDED.description;

-- -----------------------------------------------------------------------------
-- 2. Audit Events Table (Append-Only & Immutable)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lounge_id uuid REFERENCES public.lounges(id) ON DELETE CASCADE,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  actor_user_id uuid,
  severity text NOT NULL DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
  event_code text NOT NULL REFERENCES public.event_catalog(code),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes for Fast Timeline & Dashboard Queries
CREATE INDEX IF NOT EXISTS idx_audit_events_lounge_timeline
  ON public.audit_events (lounge_id, occurred_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_audit_events_entity
  ON public.audit_events (entity_type, entity_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_events_booking
  ON public.audit_events (booking_id, occurred_at DESC)
  WHERE booking_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_audit_events_actor
  ON public.audit_events (actor_user_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_events_severity
  ON public.audit_events (severity, occurred_at DESC)
  WHERE severity <> 'info';

-- Immutability Enforcement Trigger
CREATE OR REPLACE FUNCTION private.prevent_audit_modification()
RETURNS trigger
LANGUAGE plpgsql
AS $f$
BEGIN
  RAISE EXCEPTION 'Audit events are immutable and cannot be updated or deleted' USING ERRCODE = '42501';
END;
$f$;

DROP TRIGGER IF EXISTS trg_audit_events_immutable ON public.audit_events;
CREATE TRIGGER trg_audit_events_immutable
  BEFORE UPDATE OR DELETE ON public.audit_events
  FOR EACH ROW EXECUTE FUNCTION private.prevent_audit_modification();

-- Enable RLS & Strict Security Policies
ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.audit_events FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.audit_events TO authenticated, service_role;

DROP POLICY IF EXISTS "audit_events_read_policy" ON public.audit_events;
CREATE POLICY "audit_events_read_policy"
  ON public.audit_events FOR SELECT
  TO authenticated
  USING (
    private.permission_role(auth.uid(), NULL) = 'super_admin'
    OR (lounge_id IS NOT NULL AND public.has_lounge_permission(lounge_id, 'audit.view'))
    OR (actor_user_id = auth.uid())
    OR (booking_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = audit_events.booking_id AND b.user_id = auth.uid()
    ))
  );

-- -----------------------------------------------------------------------------
-- 3. Internal Audit Logger Function
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.log_audit_event(
  p_lounge_id uuid,
  p_entity_type text,
  p_entity_id text,
  p_event_code text,
  p_booking_id uuid DEFAULT NULL,
  p_actor_user_id uuid DEFAULT NULL,
  p_severity text DEFAULT NULL,
  p_payload jsonb DEFAULT '{}'::jsonb,
  p_occurred_at timestamptz DEFAULT now()
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_id uuid;
  v_severity text;
  v_sanitized_payload jsonb;
  v_reason text;
  v_request_id text;
BEGIN
  -- Determine default severity if omitted
  IF p_severity IS NULL THEN
    SELECT default_severity INTO v_severity
    FROM public.event_catalog
    WHERE code = p_event_code;
    v_severity := COALESCE(v_severity, 'info');
  ELSE
    v_severity := p_severity;
  END IF;

  -- Sanitize sensitive tokens and receipts
  v_sanitized_payload := COALESCE(p_payload, '{}'::jsonb) - 'fcm_token';
  IF v_sanitized_payload ? 'receipt_url' THEN
    v_sanitized_payload := (v_sanitized_payload - 'receipt_url') || jsonb_build_object('receipt_url_present', true);
  END IF;

  -- Capture contextual reason or request_id if set in transaction
  BEGIN
    v_reason := NULLIF(btrim(current_setting('app.audit_reason', true)), '');
    IF v_reason IS NOT NULL THEN
      v_sanitized_payload := v_sanitized_payload || jsonb_build_object('reason', v_reason);
    END IF;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    v_request_id := NULLIF(btrim(current_setting('app.audit_request_id', true)), '');
    IF v_request_id IS NOT NULL THEN
      v_sanitized_payload := v_sanitized_payload || jsonb_build_object('request_id', v_request_id);
    END IF;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  INSERT INTO public.audit_events (
    lounge_id, occurred_at, entity_type, entity_id, booking_id,
    actor_user_id, severity, event_code, payload, created_at
  ) VALUES (
    p_lounge_id, COALESCE(p_occurred_at, now()), p_entity_type, p_entity_id, p_booking_id,
    COALESCE(p_actor_user_id, auth.uid()), v_severity, p_event_code, v_sanitized_payload, now()
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$f$;

-- -----------------------------------------------------------------------------
-- 4. General Multi-Table Audit Trigger
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.log_audit_event_trg()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_lounge_id uuid;
  v_booking_id uuid;
  v_code text;
  v_severity text := 'info';
  v_payload jsonb := '{}'::jsonb;
  v_should_log boolean := false;
BEGIN
  -- Handle bookings table
  IF TG_TABLE_NAME = 'bookings' THEN
    v_lounge_id := COALESCE(NEW.lounge_id, OLD.lounge_id);
    v_booking_id := COALESCE(NEW.id, OLD.id);

    IF TG_OP = 'INSERT' THEN
      v_code := 'booking_created';
      v_payload := jsonb_build_object(
        'total_price', NEW.total_price,
        'duration_hours', NEW.duration_hours,
        'payment_method', NEW.payment_method,
        'status', NEW.status
      );
      v_should_log := true;
    ELSIF TG_OP = 'UPDATE' THEN
      -- Status transition
      IF NEW.status IS DISTINCT FROM OLD.status THEN
        CASE lower(NEW.status::text)
          WHEN 'upcoming' THEN v_code := 'booking_approved';
          WHEN 'in_progress' THEN v_code := 'booking_checked_in';
          WHEN 'completed' THEN v_code := 'booking_completed';
          WHEN 'cancelled' THEN v_code := 'booking_cancelled'; v_severity := 'warning';
          ELSE v_code := 'booking_approved';
        END CASE;
        v_payload := jsonb_build_object('old_status', OLD.status, 'new_status', NEW.status);
        v_should_log := true;
      END IF;

      -- Extension transition
      IF NEW.extension_status IS DISTINCT FROM OLD.extension_status THEN
        CASE lower(COALESCE(NEW.extension_status::text, ''))
          WHEN 'pending' THEN v_code := 'booking_extension_requested';
          WHEN 'approved' THEN v_code := 'booking_extension_approved';
          WHEN 'rejected' THEN v_code := 'booking_extension_rejected';
          ELSE NULL;
        END CASE;
        IF v_code IS NOT NULL THEN
          v_payload := jsonb_build_object('extension_status', NEW.extension_status);
          v_should_log := true;
        END IF;
      END IF;
    END IF;

    IF v_should_log THEN
      PERFORM private.log_audit_event(
        v_lounge_id, 'booking', v_booking_id::text, v_code, v_booking_id,
        auth.uid(), v_severity, v_payload, now()
      );
    END IF;
    RETURN NEW;
  END IF;

  -- Handle payments table
  IF TG_TABLE_NAME = 'payments' THEN
    v_lounge_id := COALESCE(NEW.lounge_id, OLD.lounge_id);
    v_booking_id := COALESCE(NEW.booking_id, OLD.booking_id);

    IF TG_OP = 'INSERT' THEN
      v_code := 'payment_collected';
      v_payload := jsonb_build_object(
        'amount', NEW.amount,
        'payment_method', NEW.payment_method,
        'status', NEW.status
      );
      PERFORM private.log_audit_event(
        v_lounge_id, 'payment', NEW.id::text, v_code, v_booking_id,
        auth.uid(), 'info', v_payload, now()
      );
    ELSIF TG_OP = 'UPDATE' AND NEW.status = 'refunded' AND OLD.status <> 'refunded' THEN
      v_code := 'payment_refunded';
      v_payload := jsonb_build_object('amount', NEW.amount, 'payment_method', NEW.payment_method);
      PERFORM private.log_audit_event(
        v_lounge_id, 'payment', NEW.id::text, v_code, v_booking_id,
        auth.uid(), 'warning', v_payload, now()
      );
    END IF;
    RETURN NEW;
  END IF;

  -- Handle shifts table
  IF TG_TABLE_NAME = 'shifts' THEN
    v_lounge_id := COALESCE(NEW.lounge_id, OLD.lounge_id);
    IF TG_OP = 'INSERT' THEN
      PERFORM private.log_audit_event(
        v_lounge_id, 'shift', NEW.id::text, 'shift_opened', NULL,
        auth.uid(), 'info', jsonb_build_object('opening_balance', NEW.opening_balance), now()
      );
    ELSIF TG_OP = 'UPDATE' AND NEW.status = 'closed' AND OLD.status <> 'closed' THEN
      PERFORM private.log_audit_event(
        v_lounge_id, 'shift', NEW.id::text, 'shift_closed', NULL,
        auth.uid(), 'info', jsonb_build_object('closing_balance', NEW.closing_balance), now()
      );
    END IF;
    RETURN NEW;
  END IF;

  -- Handle permissions change (severity critical)
  IF TG_TABLE_NAME IN ('staff_permissions', 'lounge_role_permissions', 'app_permissions') THEN
    v_lounge_id := NULL;
    IF TG_TABLE_NAME = 'lounge_role_permissions' THEN
      v_lounge_id := COALESCE(NEW.lounge_id, OLD.lounge_id);
    END IF;
    PERFORM private.log_audit_event(
      v_lounge_id, 'permission', COALESCE(NEW.id::text, gen_random_uuid()::text),
      'permission_changed', NULL, auth.uid(), 'critical',
      jsonb_build_object('table', TG_TABLE_NAME, 'op', TG_OP), now()
    );
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$f$;

-- Attach trigger to sensitive tables
DROP TRIGGER IF EXISTS trg_audit_bookings_changes ON public.bookings;
CREATE TRIGGER trg_audit_bookings_changes
  AFTER INSERT OR UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION private.log_audit_event_trg();

DROP TRIGGER IF EXISTS trg_audit_payments_changes ON public.payments;
CREATE TRIGGER trg_audit_payments_changes
  AFTER INSERT OR UPDATE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION private.log_audit_event_trg();

DROP TRIGGER IF EXISTS trg_audit_shifts_changes ON public.shifts;
CREATE TRIGGER trg_audit_shifts_changes
  AFTER INSERT OR UPDATE ON public.shifts
  FOR EACH ROW EXECUTE FUNCTION private.log_audit_event_trg();

-- -----------------------------------------------------------------------------
-- 5. Legacy View (Unifying Historical Logs without Backfill)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.audit_timeline_legacy_v AS
SELECT
  s.id::text AS event_id,
  s.lounge_id,
  s.entity_type,
  s.entity_id::text,
  s.booking_id,
  s.user_id AS actor_user_id,
  'info'::text AS severity,
  CASE
    WHEN s.action ILIKE '%create%' THEN 'booking_created'
    WHEN s.action ILIKE '%approved%' OR s.action ILIKE '%confirm%' THEN 'booking_approved'
    WHEN s.action ILIKE '%check_in%' OR s.action ILIKE '%start%' THEN 'booking_checked_in'
    WHEN s.action ILIKE '%complete%' THEN 'booking_completed'
    WHEN s.action ILIKE '%cancel%' THEN 'booking_cancelled'
    ELSE 'booking_created'
  END AS event_code,
  COALESCE(s.created_at, now()) AS occurred_at,
  (to_jsonb(s.details) - 'fcm_token' - 'receipt_url') ||
    CASE WHEN to_jsonb(s.details) ? 'receipt_url' THEN jsonb_build_object('receipt_url_present', true) ELSE '{}'::jsonb END AS payload
FROM public.shift_audit_logs s
WHERE s.created_at < now();

-- -----------------------------------------------------------------------------
-- 6. RPC: get_audit_timeline (Dashboard & Staff Management)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_audit_timeline(
  p_lounge_id uuid,
  p_entity_type text DEFAULT NULL,
  p_entity_id text DEFAULT NULL,
  p_actor uuid DEFAULT NULL,
  p_from timestamptz DEFAULT NULL,
  p_to timestamptz DEFAULT NULL,
  p_severity text DEFAULT NULL,
  p_cursor_at timestamptz DEFAULT NULL,
  p_cursor_id uuid DEFAULT NULL,
  p_limit int DEFAULT 50
)
RETURNS TABLE(
  id uuid,
  lounge_id uuid,
  occurred_at timestamptz,
  entity_type text,
  entity_id text,
  booking_id uuid,
  actor_user_id uuid,
  actor_name text,
  severity text,
  event_code text,
  title_ar text,
  title_en text,
  payload jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_is_super boolean;
  v_has_access boolean;
  v_role text;
  v_query_limit int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  v_role := private.permission_role(auth.uid(), p_lounge_id);
  v_is_super := (v_role = 'super_admin');
  v_has_access := v_is_super OR public.has_lounge_permission(p_lounge_id, 'audit.view');

  IF NOT v_has_access AND v_role <> 'cashier' THEN
    RAISE EXCEPTION 'Access denied to audit timeline' USING ERRCODE = '42501';
  END IF;

  v_query_limit := LEAST(COALESCE(p_limit, 50), 100);

  RETURN QUERY
  SELECT
    a.id,
    a.lounge_id,
    a.occurred_at,
    a.entity_type,
    a.entity_id,
    a.booking_id,
    a.actor_user_id,
    p.full_name AS actor_name,
    a.severity,
    a.event_code,
    c.title_ar,
    c.title_en,
    a.payload
  FROM public.audit_events a
  LEFT JOIN public.event_catalog c ON c.code = a.event_code
  LEFT JOIN public.profiles p ON p.id = a.actor_user_id
  WHERE (v_is_super OR a.lounge_id = p_lounge_id)
    AND (v_role <> 'cashier' OR a.actor_user_id = auth.uid())
    AND (p_entity_type IS NULL OR a.entity_type = p_entity_type)
    AND (p_entity_id IS NULL OR a.entity_id = p_entity_id)
    AND (p_actor IS NULL OR a.actor_user_id = p_actor)
    AND (p_from IS NULL OR a.occurred_at >= p_from)
    AND (p_to IS NULL OR a.occurred_at <= p_to)
    AND (p_severity IS NULL OR a.severity = p_severity)
    AND (p_cursor_at IS NULL OR (a.occurred_at, a.id) < (p_cursor_at, p_cursor_id))
  ORDER BY a.occurred_at DESC, a.id DESC
  LIMIT v_query_limit;
END;
$f$;

REVOKE ALL ON FUNCTION public.get_audit_timeline(uuid, text, text, uuid, timestamptz, timestamptz, text, timestamptz, uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_audit_timeline(uuid, text, text, uuid, timestamptz, timestamptz, text, timestamptz, uuid, int) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 7. RPC: get_booking_timeline (Detailed Booking Timeline for Staff/Admin)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_booking_timeline(
  p_booking_id uuid
)
RETURNS TABLE(
  event_code text,
  occurred_at timestamptz,
  actor_name text,
  summary_payload jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_booking record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT b.id, b.lounge_id, b.user_id INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id;

  IF v_booking.id IS NULL THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    private.permission_role(auth.uid(), NULL) = 'super_admin'
    OR public.has_lounge_access(v_booking.lounge_id, 'cashier')
    OR v_booking.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Access denied to booking timeline' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH combined_events AS (
    SELECT
      a.id::text AS evt_id,
      a.event_code,
      a.occurred_at,
      p.full_name AS actor_name,
      a.payload AS summary_payload
    FROM public.audit_events a
    LEFT JOIN public.profiles p ON p.id = a.actor_user_id
    WHERE a.booking_id = p_booking_id

    UNION ALL

    SELECT
      l.event_id AS evt_id,
      l.event_code,
      l.occurred_at,
      p.full_name AS actor_name,
      l.payload AS summary_payload
    FROM public.audit_timeline_legacy_v l
    LEFT JOIN public.profiles p ON p.id = l.actor_user_id
    WHERE l.booking_id = p_booking_id
      AND NOT EXISTS (
        SELECT 1 FROM public.audit_events ae
        WHERE ae.booking_id = p_booking_id AND ae.event_code = l.event_code
      )
  )
  SELECT c.event_code, c.occurred_at, COALESCE(c.actor_name, 'Staff'), c.summary_payload
  FROM combined_events c
  ORDER BY c.occurred_at ASC;
END;
$f$;

REVOKE ALL ON FUNCTION public.get_booking_timeline(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_booking_timeline(uuid) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 8. RPC: get_booking_timeline_for_customer (Customer-Facing Safe Timeline)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_booking_timeline_for_customer(
  p_booking_id uuid
)
RETURNS TABLE(
  id text,
  event_code text,
  title_ar text,
  title_en text,
  occurred_at timestamptz,
  payload jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $f$
DECLARE
  v_booking record;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT b.id, b.user_id, b.status, b.created_at, b.updated_at, b.total_price, b.duration_hours
  INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id;

  IF v_booking.id IS NULL THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  -- Strictly gate to booking owner
  IF v_booking.user_id <> auth.uid() AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Access denied to booking timeline' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH raw_events AS (
    -- Direct recorded audit events
    SELECT
      a.id::text AS evt_id,
      a.event_code AS evt_code,
      c.title_ar AS t_ar,
      c.title_en AS t_en,
      a.occurred_at AS evt_time,
      a.payload AS evt_payload
    FROM public.audit_events a
    LEFT JOIN public.event_catalog c ON c.code = a.event_code
    WHERE a.booking_id = p_booking_id
      AND a.event_code IN (
        'booking_created', 'booking_approved', 'booking_checked_in',
        'booking_extension_requested', 'booking_extension_approved',
        'booking_extension_rejected', 'booking_completed', 'booking_cancelled'
      )

    UNION ALL

    -- Fallback synthesis from booking state if audit_events has no records yet
    SELECT
      (v_booking.id::text || '_created'),
      'booking_created'::text,
      'تم إنشاء الحجز'::text,
      'Booking Placed'::text,
      v_booking.created_at,
      jsonb_build_object('total_price', v_booking.total_price, 'duration_hours', v_booking.duration_hours)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.audit_events ae
      WHERE ae.booking_id = p_booking_id AND ae.event_code = 'booking_created'
    )
  )
  SELECT
    r.evt_id AS id,
    r.evt_code AS event_code,
    COALESCE(r.t_ar, 'تحديث بالحجز') AS title_ar,
    COALESCE(r.t_en, 'Booking Activity') AS title_en,
    r.evt_time AS occurred_at,
    r.evt_payload AS payload
  FROM raw_events r
  ORDER BY r.evt_time ASC;
END;
$f$;

REVOKE ALL ON FUNCTION public.get_booking_timeline_for_customer(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_booking_timeline_for_customer(uuid) TO authenticated, service_role;

COMMIT;
