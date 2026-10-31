BEGIN;

REVOKE UPDATE ON TABLE public.lounges FROM authenticated;

GRANT UPDATE (
  name,
  image_url,
  images,
  location,
  city,
  maps_link,
  location_point,
  description_ar,
  description_en,
  address,
  contact_phone,
  opening_time,
  closing_time,
  has_discount,
  discount_percentage,
  discount_title_ar,
  discount_title_en,
  discount_expires_at,
  name_ar,
  name_en,
  city_id,
  vodafone_cash_number,
  instapay_account,
  allow_cash_payment,
  require_prepaid_first_time,
  cash_grace_period_minutes,
  wallet_number,
  instapay_handle,
  branch_name,
  allow_open_time_sessions,
  open_time_rounding_minutes,
  open_time_minimum_minutes,
  open_time_max_minutes,
  timezone,
  allow_future_bookings,
  allow_request_without_shift,
  future_booking_max_days_advance,
  unconfirmed_alert_lead_minutes,
  require_deposit_for_future,
  future_deposit_percentage
) ON public.lounges TO authenticated;

COMMIT;
