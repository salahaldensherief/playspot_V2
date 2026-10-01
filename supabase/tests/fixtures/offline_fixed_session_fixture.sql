CREATE EXTENSION IF NOT EXISTS btree_gist;
ALTER TABLE public.profiles ADD completed_bookings_count integer DEFAULT 0;
ALTER TABLE public.lounges ADD timezone text DEFAULT 'Africa/Cairo',ADD allow_cash_payment boolean DEFAULT true,
 ADD require_prepaid_first_time boolean DEFAULT true;
ALTER TABLE public.rooms ADD name text DEFAULT 'Room',ADD hourly_rate numeric,ADD status text DEFAULT 'available',
 ADD is_active boolean DEFAULT true,ADD is_available boolean DEFAULT true,ADD updated_at timestamptz;
ALTER TABLE public.bookings ADD start_at time,ADD end_at time,ADD user_name text,ADD user_phone text,ADD room_name text,
 ADD created_at timestamptz DEFAULT now(),ADD checked_in_at timestamptz,ADD actual_start_time timestamptz,
 ADD is_first_booking boolean DEFAULT false,ADD sender_wallet_phone text;
ALTER TABLE public.bookings ADD booking_period tsrange GENERATED ALWAYS AS (
 tsrange(date+start_time,date+end_time+CASE WHEN end_time<=start_time THEN interval '1 day' ELSE interval '0' END)) STORED;
ALTER TABLE public.bookings ADD duration_hours numeric GENERATED ALWAYS AS (
 extract(epoch FROM ((end_time-start_time)+CASE WHEN end_time<=start_time THEN interval '1 day' ELSE interval '0' END))/3600) STORED;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_room_booking_period_excl EXCLUDE USING gist
 (room_id WITH =,booking_period WITH &&) WHERE(status NOT IN ('cancelled','rejected') AND room_id IS NOT NULL AND booking_period IS NOT NULL);
CREATE TABLE public.tournament_matches(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),room_id uuid,status text,
 scheduled_at timestamptz,scheduled_end_at timestamptz);
