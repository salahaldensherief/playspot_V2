CREATE SCHEMA auth;
CREATE SCHEMA private;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$
  SELECT nullif(current_setting('test.actor',true),'')::uuid
$$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;
CREATE FUNCTION private.is_lounge_manager(uuid) RETURNS boolean LANGUAGE sql AS $$
  SELECT current_setting('test.manager',true)='true'
$$;
CREATE TABLE public.tournaments(
  id uuid PRIMARY KEY,lounge_id uuid,status text,champion_participant_id uuid,updated_at timestamptz
);
CREATE TABLE public.tournament_participants(id uuid PRIMARY KEY,user_id uuid);
CREATE TABLE public.tournament_matches(
  id uuid PRIMARY KEY,tournament_id uuid,round_number integer,match_order integer,
  player1_id uuid,player2_id uuid,winner_id uuid,status text DEFAULT 'scheduled',
  next_match_id uuid,next_match_slot smallint,score_player1 integer,score_player2 integer,
  submitted_by uuid,completed_at timestamptz,updated_at timestamptz,
  resolved_by uuid,resolved_at timestamptz,resolution_notes text
);
CREATE TABLE public.tournament_placements(
  tournament_id uuid,placement integer,participant_id uuid NOT NULL,
  UNIQUE(tournament_id,placement)
);
CREATE TABLE public.fixture_audit(tournament_id uuid,event text);
CREATE FUNCTION public.tournament_audit(uuid,text,uuid,uuid,jsonb,jsonb,text DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$ INSERT INTO public.fixture_audit VALUES($1,$2) $$;
SET test.manager='true';
SET test.actor='00000000-0000-0000-0000-000000000001';
