CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
CREATE SCHEMA auth; CREATE SCHEMA private;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TYPE public.booking_status AS ENUM('pending','upcoming','in_progress','completed','cancelled','rejected');
CREATE TABLE public.fixture_permissions(actor uuid,lounge uuid,permission text);
CREATE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql STABLE AS 'SELECT false';
CREATE FUNCTION public.has_lounge_permission(p_lounge uuid,p_permission text)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.fixture_permissions
 WHERE actor=auth.uid() AND lounge=p_lounge AND permission=p_permission)
$$;
CREATE TABLE public.bookings(id uuid PRIMARY KEY,user_id uuid,lounge_id uuid,room_id uuid,
 status public.booking_status,payment_status text,payment_method text,total_price numeric,
 is_open_time boolean DEFAULT false,discount_amount numeric,discount_percentage numeric,
 discount_reason text,discount_approved_by uuid,shift_id uuid,updated_at timestamptz);
CREATE TABLE public.shifts(id uuid PRIMARY KEY,lounge_id uuid,status text,closed_at timestamptz,opened_at timestamptz);
CREATE TABLE public.payments(id uuid DEFAULT gen_random_uuid(),booking_id uuid UNIQUE,
 user_id uuid,lounge_id uuid,amount numeric CHECK(amount>=0),commission numeric,net_to_lounge numeric,
 payment_method text,status text,paid_at timestamptz,discount_amount numeric,discount_percentage numeric,
 discount_reason text,discount_approved_by uuid);
CREATE TABLE public.shift_payments(id uuid DEFAULT gen_random_uuid(),shift_id uuid,lounge_id uuid,
 booking_id uuid,payment_method text,category text,amount numeric CHECK(amount>=0),paid_at timestamptz);
GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated,anon;
