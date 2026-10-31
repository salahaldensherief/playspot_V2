CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;CREATE SCHEMA private;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT NULLIF(current_setting('test.actor',true),'')::uuid$$;
 CREATE TABLE auth.users(id uuid PRIMARY KEY);
 CREATE TABLE public.profiles(id uuid PRIMARY KEY,role text,is_active boolean,is_banned boolean);
 CREATE TABLE public.platform_super_admins(user_id uuid PRIMARY KEY);
 CREATE TABLE public.lounges(id uuid PRIMARY KEY,is_active boolean,status text);
 CREATE TABLE public.fixture_permissions(actor uuid,lounge uuid,permission text);
 CREATE FUNCTION public.has_lounge_permission(uuid,text) RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path='' AS
 $$SELECT EXISTS(SELECT 1 FROM public.fixture_permissions WHERE actor=auth.uid() AND lounge=$1 AND permission=$2)$$;
 CREATE FUNCTION private.platform_commission_rate() RETURNS numeric LANGUAGE sql IMMUTABLE AS $$SELECT 0.15::numeric$$;
 CREATE TABLE public.shifts(id uuid PRIMARY KEY,lounge_id uuid,cashier_id uuid,staff_user_id uuid,status text,closed_at timestamptz);
 CREATE TABLE public.bookings(id uuid PRIMARY KEY,user_id uuid,lounge_id uuid,status text,is_open_time boolean DEFAULT false,
 total_price numeric,payment_status text DEFAULT 'unpaid',payment_method text,updated_at timestamptz);
 CREATE TABLE public.payments(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),booking_id uuid UNIQUE REFERENCES public.bookings(id),
 user_id uuid,lounge_id uuid,amount numeric CHECK(amount>=0),commission_rate numeric CHECK(commission_rate BETWEEN 0 AND 1),
 commission numeric,net_to_lounge numeric,payment_method text,status text,payout_id uuid,paid_at timestamptz);
 CREATE TABLE public.shift_payments(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),shift_id uuid REFERENCES public.shifts(id),
 lounge_id uuid,booking_id uuid,payment_method text,category text CHECK(category IN ('gaming_time','snacks','extra_controllers','other')),
 amount numeric CHECK(amount>=0),paid_at timestamptz);
 CREATE FUNCTION public.enforce_payment_financials() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
 BEGIN NEW.commission_rate:=private.platform_commission_rate();NEW.commission:=round(NEW.amount*NEW.commission_rate,2);
 NEW.net_to_lounge:=NEW.amount-NEW.commission;RETURN NEW;END;$$;
 CREATE TRIGGER finance BEFORE INSERT OR UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.enforce_payment_financials();
 CREATE FUNCTION public.prevent_closed_shift_transaction() RETURNS trigger LANGUAGE plpgsql AS $$
 BEGIN IF NOT EXISTS(SELECT 1 FROM public.shifts WHERE id=NEW.shift_id AND status='open') THEN
 RAISE EXCEPTION 'CLOSED_SHIFT' USING ERRCODE='55000';END IF;RETURN NEW;END;$$;
 CREATE TRIGGER closed_shift BEFORE INSERT ON public.shift_payments FOR EACH ROW EXECUTE FUNCTION public.prevent_closed_shift_transaction();
