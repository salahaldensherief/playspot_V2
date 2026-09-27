BEGIN;

CREATE OR REPLACE FUNCTION public.claim_referral_code(
  p_referral_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_referrer_id uuid;
  v_referral public.referrals%ROWTYPE;
  v_email_confirmed_at timestamptz;
  v_referrer_award jsonb;
  v_referred_award jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT u.email_confirmed_at
  INTO v_email_confirmed_at
  FROM auth.users AS u
  WHERE u.id = v_user_id;

  IF v_email_confirmed_at IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'confirm_email_first'
    );
  END IF;

  SELECT p.id
  INTO v_referrer_id
  FROM public.profiles AS p
  WHERE p.referral_code = upper(btrim(p_referral_code))
    AND p.id <> v_user_id
  LIMIT 1;

  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_referral_code'
    );
  END IF;

  SELECT *
  INTO v_referral
  FROM public.referrals
  WHERE referred_id = v_user_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_referral.referrer_id <> v_referrer_id THEN
      RETURN jsonb_build_object(
        'success', false,
        'already_claimed', true,
        'status', v_referral.status,
        'reward_claimed', v_referral.reward_claimed
      );
    END IF;

    IF v_referral.reward_claimed IS TRUE THEN
      RETURN jsonb_build_object(
        'success', false,
        'already_claimed', true,
        'status', v_referral.status,
        'reward_claimed', true
      );
    END IF;
  ELSE
    UPDATE public.profiles
    SET referred_by = v_referrer_id,
        updated_at = now()
    WHERE id = v_user_id
      AND referred_by IS NULL;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'success', false,
        'already_claimed', true
      );
    END IF;

    INSERT INTO public.referrals (
      referrer_id,
      referred_id,
      status,
      reward_claimed
    )
    VALUES (
      v_referrer_id,
      v_user_id,
      'pending',
      false
    )
    RETURNING *
    INTO v_referral;
  END IF;

  v_referrer_award := public.award_points(
    p_user_id => v_referrer_id,
    p_points => 100,
    p_type => 'earn_referral',
    p_reference_id => v_user_id,
    p_description => 'مكافأة دعوة صديق',
    p_source_type => 'referral',
    p_source_id => v_referral.id,
    p_idempotency_key => 'referral:referrer:' || v_referral.id::text,
    p_metadata => jsonb_build_object(
      'referral_id', v_referral.id,
      'referred_user_id', v_user_id
    )
  );

  v_referred_award := public.award_points(
    p_user_id => v_user_id,
    p_points => 50,
    p_type => 'earn_referral',
    p_reference_id => v_referral.id,
    p_description => 'هدية ترحيبية من دعوة صديق',
    p_source_type => 'referral',
    p_source_id => v_referral.id,
    p_idempotency_key => 'referral:referred:' || v_referral.id::text,
    p_metadata => jsonb_build_object(
      'referral_id', v_referral.id,
      'referrer_user_id', v_referrer_id
    )
  );

  UPDATE public.referrals
  SET status = 'completed',
      reward_claimed = true
  WHERE id = v_referral.id;

  RETURN jsonb_build_object(
    'success', true,
    'referral_id', v_referral.id,
    'referrer_points', 100,
    'referred_points', 50,
    'referrer_award_applied',
      COALESCE((v_referrer_award->>'applied')::boolean, false),
    'referred_award_applied',
      COALESCE((v_referred_award->>'applied')::boolean, false)
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.claim_referral_code(text)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.claim_referral_code(text)
TO authenticated, service_role, supabase_auth_admin;

COMMIT;
