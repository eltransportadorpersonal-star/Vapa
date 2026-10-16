-- Apply ONLY after V43, V44, V45 and after checking existing rows in staging.
-- Pending owner must block competing reservations; use exclusion constraint.
ALTER TABLE public.reservations DROP CONSTRAINT IF EXISTS v43_reservation_no_overlap;
ALTER TABLE public.reservations ADD CONSTRAINT v43_reservation_no_overlap
 EXCLUDE USING gist (property_id WITH =, tstzrange(start_at,end_at,'[)') WITH &&)
 WHERE (status IN ('pending_payment','pending_owner','confirmed'));
ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS mp_payment_id text;
CREATE UNIQUE INDEX IF NOT EXISTS v46_mp_payment_unique ON public.reservations(mp_payment_id) WHERE mp_payment_id IS NOT NULL;
CREATE OR REPLACE FUNCTION public.v46_mark_payment_verified(p_reservation uuid,p_payment_id text,p_amount numeric)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r public.reservations%rowtype;
BEGIN
 IF current_setting('request.jwt.claim.role',true) IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Service role only'; END IF;
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation FOR UPDATE;
 IF NOT FOUND OR r.amount<>p_amount OR r.status NOT IN ('pending_payment','pending_owner') THEN RAISE EXCEPTION 'Payment mismatch or invalid state'; END IF;
 IF r.mp_payment_id IS NOT NULL AND r.mp_payment_id<>p_payment_id THEN RAISE EXCEPTION 'Different payment already recorded'; END IF;
 UPDATE public.reservations SET status='pending_owner',payment_status='paid',mp_payment_id=p_payment_id,expires_at=NULL WHERE id=p_reservation;
END $$;
REVOKE ALL ON FUNCTION public.v46_mark_payment_verified(uuid,text,numeric) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.v46_mark_payment_verified(uuid,text,numeric) TO service_role;
-- NOTE: Expired payment or rejection requires reconciliation/refund workflow before real money.
