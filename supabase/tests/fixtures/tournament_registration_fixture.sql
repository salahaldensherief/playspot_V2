CREATE SCHEMA auth;
CREATE SCHEMA private;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT nullif(current_setting('test.actor',true),'')::uuid $$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;
CREATE FUNCTION private.is_lounge_manager(uuid) RETURNS boolean LANGUAGE sql AS $$ SELECT current_setting('test.manager',true)='true' $$;
CREATE FUNCTION private.can_operate_playspot_lounge(uuid) RETURNS boolean LANGUAGE sql AS $$ SELECT private.is_lounge_manager($1) $$;
CREATE FUNCTION public.is_lounge_member_or_admin(uuid) RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;
CREATE FUNCTION public.has_lounge_permission(uuid,text) RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;
CREATE TABLE public.profiles(id uuid PRIMARY KEY,is_active boolean,is_banned boolean);
CREATE FUNCTION private.require_active_booking_actor() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND is_active IS TRUE AND is_banned IS NOT TRUE)
  THEN RAISE EXCEPTION 'inactive_account' USING ERRCODE='42501'; END IF;
END; $$;
CREATE TABLE public.tournaments(
  id uuid PRIMARY KEY,lounge_id uuid,status text,entry_fee numeric,max_participants integer,
  registration_opens_at timestamptz,registration_closes_at timestamptz,
  check_in_closes_at timestamptz,payment_deadline_minutes integer,updated_at timestamptz
);
CREATE TABLE public.tournament_participants(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),tournament_id uuid,user_id uuid,
  registration_status text DEFAULT 'pending_payment',payment_status text DEFAULT 'unpaid',
  waitlist_position integer,payment_deadline timestamptz,payment_method text,
  approved_by uuid,approved_at timestamptz,cash_received_by uuid,cash_received_at timestamptz,
  cash_reference_note text,created_at timestamptz DEFAULT now(),updated_at timestamptz,
  CONSTRAINT tournament_participants_payment_status_check CHECK(payment_status IN('unpaid','pending','paid')),
  UNIQUE(tournament_id,user_id)
);
CREATE TABLE public.tournament_refunds(tournament_id uuid,participant_id uuid,user_id uuid,amount numeric,reason text,
  UNIQUE(tournament_id,participant_id));
CREATE TABLE public.payments(id uuid PRIMARY KEY,amount numeric);
CREATE TABLE public.fixture_audit(tournament_id uuid,event text);
CREATE FUNCTION public.tournament_audit(uuid,text,uuid,uuid,jsonb,jsonb,text DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$ INSERT INTO public.fixture_audit VALUES($1,$2) $$;
SET test.actor='00000000-0000-0000-0000-000000000001';
SET test.manager='true';
