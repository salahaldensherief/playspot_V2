DO $$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='supabase_auth_admin') THEN CREATE ROLE supabase_auth_admin NOLOGIN; END IF;
END $$;
CREATE SCHEMA auth; CREATE SCHEMA private;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
CREATE TABLE profiles(id uuid PRIMARY KEY,lounge_id uuid,role text,is_active boolean DEFAULT true,is_banned boolean DEFAULT false,allowed boolean DEFAULT true);
CREATE OR REPLACE FUNCTION is_super_admin() RETURNS boolean LANGUAGE sql AS $$SELECT EXISTS(SELECT FROM public.profiles WHERE id=auth.uid() AND role='super_admin')$$;
CREATE OR REPLACE FUNCTION has_lounge_permission(venue uuid,key text) RETURNS boolean LANGUAGE sql AS $$SELECT EXISTS(SELECT FROM public.profiles WHERE id=auth.uid() AND lounge_id=venue AND allowed)$$;
CREATE TABLE rooms(id uuid PRIMARY KEY,lounge_id uuid,status text,is_available boolean,updated_at timestamptz);
CREATE TABLE bookings(id uuid PRIMARY KEY,room_id uuid,status text);
