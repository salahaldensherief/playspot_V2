# Backend Requests for Supabase Backend Team / Agent
**Project Ref:** `tgpdexoitemmpruepgyt`  
**Generated From:** PlaySpot Mobile Codebase Audit (`docs/audits/mobile_audit_2026-10-05.md`)  
**Date:** 2026-10-05  

The following backend RPC functions, schema migrations, and RLS policies are required by the PlaySpot Mobile application but are currently absent from `supabase/migrations/`.

---

## 1. Critical Financial & Booking Requests

### 1.1 `attach_my_booking_receipt`
* **Calling Mobile File:** `lib/features/booking/data/datasources/remote/booking_remote_data_source.dart:270-274`
* **Trigger Flow:** Vodafone Cash & InstaPay manual transfer checkout.
* **Function Signature:**
  ```sql
  CREATE OR REPLACE FUNCTION public.attach_my_booking_receipt(
    p_booking_id uuid,
    p_receipt_url text
  )
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $$
  DECLARE
    v_user_id uuid := auth.uid();
  BEGIN
    IF v_user_id IS NULL THEN
      RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
    END IF;

    UPDATE public.bookings
    SET receipt_url = p_receipt_url,
        payment_status = 'pending_verification',
        updated_at = now()
    WHERE id = p_booking_id
      AND user_id = v_user_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Booking not found or not owned by user' USING ERRCODE = '42501';
    END IF;

    RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id);
  END;
  $$;

  REVOKE EXECUTE ON FUNCTION public.attach_my_booking_receipt(uuid, text) FROM PUBLIC, anon;
  GRANT EXECUTE ON FUNCTION public.attach_my_booking_receipt(uuid, text) TO authenticated, service_role;
  ```

---

### 1.2 `cancel_my_booking`
* **Calling Mobile File:** `lib/features/my_bookings/data/datasources/remote/my_bookings_remote_data_source.dart:61-68`
* **Trigger Flow:** Customer cancellation from My Bookings screen.
* **Function Signature:**
  ```sql
  CREATE OR REPLACE FUNCTION public.cancel_my_booking(
    p_booking_id uuid,
    p_reason text DEFAULT 'Cancelled by user'
  )
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $$
  DECLARE
    v_user_id uuid := auth.uid();
    v_booking public.bookings%ROWTYPE;
  BEGIN
    IF v_user_id IS NULL THEN
      RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
    END IF;

    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = p_booking_id
      AND user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Booking not found or not owned by user' USING ERRCODE = '42501';
    END IF;

    IF v_booking.status IN ('completed', 'cancelled') THEN
      RAISE EXCEPTION 'Cannot cancel booking in status %', v_booking.status USING ERRCODE = '55000';
    END IF;

    UPDATE public.bookings
    SET status = 'cancelled'::public.booking_status,
        cancellation_reason = p_reason,
        updated_at = now()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id);
  END;
  $$;

  REVOKE EXECUTE ON FUNCTION public.cancel_my_booking(uuid, text) FROM PUBLIC, anon;
  GRANT EXECUTE ON FUNCTION public.cancel_my_booking(uuid, text) TO authenticated, service_role;
  ```

---

## 2. Points & Loyalty Requests

### 2.1 Points Balance & History RPCs
* **Calling Mobile File:** `lib/features/profile/data/datasources/remote/profile_remote_data_source.dart:121, 147, 196`
* **Required Functions:**
  1. `public.get_user_points_balance(p_user_id uuid)`:
     - Must enforce `auth.uid() = p_user_id` or default to `auth.uid()`.
     - Returns integer points balance.
  2. `public.get_points_transactions_page(p_page int, p_page_size int)`:
     - Returns paginated list of points ledger transactions for `auth.uid()`.
  3. `public.redeem_points(p_user_id uuid, p_redemption_option_id uuid)`:
     - Validates point balance, deducts points atomically in points ledger, creates reward voucher.

---

## 3. Tournaments System Requests

### 3.1 Tournament Participation & Scoring RPCs
* **Calling Mobile File:** `lib/features/tournaments/data/datasources/remote/tournaments_remote_data_source.dart`
* **Required Functions:**
  1. `public.get_visible_tournaments(p_latitude float8, p_longitude float8)`:
     - Returns active and upcoming tournaments ordered by proximity/date.
  2. `public.register_for_tournament(p_tournament_id uuid)`:
     - Enforces max participant caps, active status, and creates participant record for `auth.uid()`.
  3. `public.submit_match_result(p_match_id uuid, p_score_player1 int, p_score_player2 int, p_proof_image_url text)`:
     - Submits match result and transitions match status to `pending_confirmation` or `disputed`.
  4. `public.withdraw_from_tournament(p_participant_id uuid)`:
     - Validates tournament bracket status and marks participant as `withdrawn`.
  5. `public.check_in_tournament_participant(p_participant_id uuid)`:
     - Marks participant checked-in for tournament.

---

## 4. Support, Content & Settings Requests

### 4.1 Content RPCs
* **Calling Mobile File:** `lib/features/profile/data/datasources/remote/support_remote_data_source.dart`
* **Required Functions:**
  1. `public.get_public_support_settings()`: Returns WhatsApp phone, support email, hotline.
  2. `public.get_public_policies(p_lang text)`: Returns active terms and privacy policy documents.
  3. `public.get_public_faqs(p_lang text)`: Returns categorized FAQ entries.
  4. `public.create_support_ticket(p_subject text, p_message text, p_category text)`: Submits customer support inquiry.
