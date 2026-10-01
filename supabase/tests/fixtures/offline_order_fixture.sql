ALTER TABLE public.lounges ADD is_open boolean DEFAULT true;
CREATE TYPE public.booking_status AS ENUM('upcoming','completed','cancelled','pending','in_progress','rejected','expired');
ALTER TABLE public.bookings ALTER COLUMN status TYPE public.booking_status USING status::public.booking_status;
CREATE TABLE public.rooms(id uuid PRIMARY KEY,lounge_id uuid,hourly_rate_single numeric,hourly_rate_multi numeric,
 extra_controller_price numeric DEFAULT 0);
ALTER TABLE public.bookings ADD room_id uuid,ADD date date,ADD start_time time,ADD end_time time,
 ADD shift_id uuid REFERENCES public.shifts(id),ADD room_price numeric,ADD addons_price numeric DEFAULT 0,
 ADD addons_total numeric DEFAULT 0,ADD discount_amount numeric DEFAULT 0,ADD discount_percentage numeric DEFAULT 0,
 ADD duration_minutes integer DEFAULT 60,ADD play_mode text DEFAULT 'single',ADD extra_controllers integer DEFAULT 0,
 ADD open_time_pricing_snapshot jsonb;
CREATE TABLE public.extras(id uuid PRIMARY KEY,lounge_id uuid,name text NOT NULL,price numeric NOT NULL,
 is_active boolean DEFAULT true,is_available boolean DEFAULT true,track_stock boolean DEFAULT true,stock_quantity integer DEFAULT 0);
CREATE TABLE public.canteen_orders(id uuid PRIMARY KEY,booking_id uuid REFERENCES public.bookings(id),lounge_id uuid,
 user_id uuid,shift_id uuid REFERENCES public.shifts(id),items jsonb,total_price numeric NOT NULL,note text,status text,
 created_at timestamptz DEFAULT now());
CREATE TABLE public.canteen_order_items(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_id uuid REFERENCES public.canteen_orders(id),
 extra_id uuid REFERENCES public.extras(id),quantity integer NOT NULL,unit_price numeric NOT NULL,total_price numeric NOT NULL,item_name text);
CREATE TABLE public.booking_items(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),booking_id uuid REFERENCES public.bookings(id),
 product_id uuid REFERENCES public.extras(id),extra_id uuid REFERENCES public.extras(id),quantity integer NOT NULL,
 unit_price numeric NOT NULL,total_price numeric NOT NULL,price numeric,name text,note text,status text);
CREATE FUNCTION private.user_permission_value(uuid,uuid,text) RETURNS boolean LANGUAGE sql AS
 $$SELECT EXISTS(SELECT 1 FROM public.fixture_permissions WHERE actor=$1 AND lounge=$2 AND permission=$3)$$;
GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
