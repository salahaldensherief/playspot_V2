-- Migration: Add UNIQUE Constraint & Atomic Guard for Tournament Payments (Resolves TOCTOU Race Condition)
-- Description: Ensures that even if multiple payment submission requests arrive simultaneously,
-- Postgres enforces strict database-level uniqueness on (tournament_id, participant_id).

DO $$
BEGIN
    -- 1. Add Unique Constraint on tournament_participants / tournament_payments if table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'tournament_payments'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint WHERE conname = 'uq_tournament_payments_participant'
        ) THEN
            ALTER TABLE public.tournament_payments
            ADD CONSTRAINT uq_tournament_payments_participant UNIQUE (tournament_id, participant_id);
        END IF;
    END IF;

    -- 2. Ensure atomic state check inside submit_tournament_payment RPC function if exists
    IF EXISTS (
        SELECT 1 FROM pg_proc WHERE proname = 'submit_tournament_payment'
    ) THEN
        CREATE OR REPLACE FUNCTION public.submit_tournament_payment(
            p_participant_id UUID,
            p_tournament_id UUID,
            p_user_id UUID,
            p_amount NUMERIC,
            p_payment_method TEXT,
            p_receipt_url TEXT
        ) RETURNS JSONB
        LANGUAGE plpgsql
        SECURITY DEFINER
        AS $func$
        DECLARE
            v_curr_status TEXT;
            v_result JSONB;
        BEGIN
            -- Atomic row lock on participant row to prevent TOCTOU race conditions
            SELECT status INTO v_curr_status
            FROM public.tournament_participants
            WHERE id = p_participant_id
            FOR UPDATE;

            IF v_curr_status IN ('payment_submitted', 'paid', 'confirmed') THEN
                RETURN jsonb_build_object(
                    'success', true,
                    'already_submitted', true,
                    'message', 'Payment receipt already submitted and under review.'
                );
            END IF;

            -- Update status atomically
            UPDATE public.tournament_participants
            SET status = 'payment_submitted',
                payment_method = p_payment_method,
                receipt_url = p_receipt_url,
                updated_at = NOW()
            WHERE id = p_participant_id;

            RETURN jsonb_build_object(
                'success', true,
                'already_submitted', false,
                'participant_id', p_participant_id
            );
        END;
        $func$;
    END IF;
END $$;
