DO $$ BEGIN
 IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
 IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
END $$;
CREATE SCHEMA auth; CREATE SCHEMA private;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
CREATE TABLE public.profiles(id uuid PRIMARY KEY,role text,lounge_id uuid,full_name text,is_active boolean DEFAULT true,is_banned boolean DEFAULT false,can_audit boolean DEFAULT true,can_finance boolean DEFAULT true);
CREATE TABLE public.app_permissions(key text PRIMARY KEY,name_ar text,name_en text,category text,description_ar text,description_en text,default_super_admin boolean,default_owner boolean,default_cashier boolean);
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql AS $$SELECT EXISTS(SELECT FROM public.profiles WHERE id=auth.uid() AND role='super_admin')$$;
CREATE FUNCTION public.has_lounge_permission(lounge uuid,key text) RETURNS boolean LANGUAGE sql AS $$SELECT EXISTS(SELECT FROM public.profiles p WHERE p.id=auth.uid() AND p.is_active AND NOT p.is_banned AND (p.lounge_id=lounge OR p.role='super_admin') AND CASE WHEN key='audit.view' THEN p.can_audit ELSE p.can_finance END)$$;
CREATE TABLE public.room_status_audit(id uuid PRIMARY KEY,room_id uuid,lounge_id uuid,booking_id uuid,old_status text,new_status text,old_is_available boolean,new_is_available boolean,changed_by uuid,operation text,source text,changed_at timestamptz);
CREATE TABLE public.shift_audit_logs(id uuid PRIMARY KEY,lounge_id uuid,shift_id uuid,entity_type text,entity_id uuid,action text,actor_user_id uuid,old_data jsonb,new_data jsonb,created_at timestamptz);
CREATE TABLE private.booking_cancellation_events(id bigint PRIMARY KEY,booking_id uuid,user_id uuid,lounge_id uuid,cancellation_reason text,cancellation_source text,was_approved boolean,cancelled_by uuid,cancelled_at timestamptz);
CREATE TABLE public.payouts(id uuid PRIMARY KEY,lounge_id uuid);
CREATE TABLE public.payout_audit_logs(id uuid PRIMARY KEY,payout_id uuid,action text,actor_user_id uuid,old_data jsonb,new_data jsonb,reason text,created_at timestamptz);
CREATE TABLE public.tournaments(id uuid PRIMARY KEY,lounge_id uuid);
CREATE TABLE public.tournament_audit_logs(id uuid PRIMARY KEY,tournament_id uuid,action text,actor_user_id uuid,old_data jsonb,new_data jsonb,reason text,created_at timestamptz);
