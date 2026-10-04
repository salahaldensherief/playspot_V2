CREATE SCHEMA auth;
CREATE SCHEMA private;
DO $$DECLARE role_name text; BEGIN FOREACH role_name IN ARRAY ARRAY['anon','authenticated','service_role','supabase_auth_admin'] LOOP IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname=role_name) THEN EXECUTE format('CREATE ROLE %I',role_name); END IF; END LOOP; END$$;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql AS $$SELECT COALESCE(NULLIF(current_setting('test.role',true),''),'authenticated')$$;
CREATE TABLE public.profiles(id uuid PRIMARY KEY,role text,lounge_id uuid,is_active boolean DEFAULT true,is_banned boolean DEFAULT false,can_close boolean DEFAULT true);
CREATE FUNCTION private.can_operate_playspot_lounge(lounge uuid) RETURNS boolean LANGUAGE sql AS $$SELECT EXISTS(SELECT FROM public.profiles p WHERE p.id=auth.uid() AND p.is_active AND NOT p.is_banned AND (p.lounge_id=lounge OR p.role='super_admin'))$$;
CREATE FUNCTION private.can_manage_playspot_lounge(lounge uuid) RETURNS boolean LANGUAGE sql AS $$SELECT EXISTS(SELECT FROM public.profiles p WHERE p.id=auth.uid() AND p.is_active AND NOT p.is_banned AND p.role IN ('owner','manager','super_admin') AND (p.lounge_id=lounge OR p.role='super_admin'))$$;
CREATE FUNCTION public.has_lounge_permission(lounge uuid,key text) RETURNS boolean LANGUAGE sql AS $$SELECT EXISTS(SELECT FROM public.profiles p WHERE p.id=auth.uid() AND p.can_close AND (p.lounge_id=lounge OR p.role='super_admin') AND key='shifts_blind_close')$$;
CREATE TABLE public.shifts(id uuid PRIMARY KEY,lounge_id uuid,cashier_id uuid,staff_user_id uuid,status text DEFAULT 'open',starting_cash numeric DEFAULT 100,expected_cash numeric,actual_cash_counted numeric,difference numeric,total_cash_sales numeric,total_digital_sales numeric,total_expenses numeric,closed_at timestamptz,end_time timestamptz,notes text);
CREATE TABLE public.shift_payments(shift_id uuid,payment_method text,amount numeric);
CREATE TABLE public.shift_expenses(shift_id uuid,expense_type text,amount numeric);
CREATE TABLE public.shift_audit_logs(lounge_id uuid,shift_id uuid,entity_type text,entity_id uuid,action text,actor_user_id uuid,old_data jsonb,new_data jsonb);

ALTER TABLE public.shifts ADD COLUMN opened_at timestamptz DEFAULT now();
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql AS $$SELECT EXISTS(SELECT FROM public.profiles WHERE id=auth.uid() AND role='super_admin' AND is_active AND NOT is_banned)$$;
CREATE FUNCTION private.assert_lounge_operator(lounge uuid, unused boolean) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF NOT private.can_operate_playspot_lounge(lounge) THEN RAISE EXCEPTION 'Denied' USING ERRCODE='42501'; END IF; END$$;
