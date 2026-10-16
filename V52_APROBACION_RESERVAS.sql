-- VAPA V52 STAGING: aplicar tras V51. No ejecuta reembolsos sin Edge Function y cron.
ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS owner_response_deadline timestamptz;
ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS owner_decided_at timestamptz;
ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS refund_status text;
ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS refund_requested_at timestamptz;
ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS refund_completed_at timestamptz;
ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS refund_reference text;
UPDATE public.reservations SET owner_response_deadline=coalesce(owner_response_deadline,created_at+interval '12 hours') WHERE status='pending_owner';
CREATE OR REPLACE FUNCTION public.v52_owner_decide(p_reservation uuid,p_accept boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r public.reservations%rowtype;
BEGIN
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM public.properties WHERE id=r.property_id AND owner_id=auth.uid()) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF r.status<>'pending_owner' OR r.payment_status<>'paid' THEN RAISE EXCEPTION 'Reserva no pendiente de aprobación'; END IF;
 IF now()>=coalesce(r.owner_response_deadline,r.created_at+interval '12 hours') THEN RAISE EXCEPTION 'Plazo vencido'; END IF;
 IF p_accept THEN
  UPDATE public.reservations SET status='confirmed',owner_decided_at=now() WHERE id=p_reservation;
  RETURN 'confirmed';
 ELSE
  UPDATE public.reservations SET status='rejected',owner_decided_at=now(),refund_status='pending',refund_requested_at=now() WHERE id=p_reservation;
  RETURN 'refund_pending';
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.v52_owner_decide(uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.v52_owner_decide(uuid,boolean) TO authenticated;
CREATE OR REPLACE FUNCTION public.v52_expire_owner_requests()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE n integer;
BEGIN
 IF current_setting('request.jwt.claim.role',true) IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Service role only'; END IF;
 UPDATE public.reservations SET status='rejected',refund_status='pending',refund_requested_at=now()
 WHERE status='pending_owner' AND now()>=coalesce(owner_response_deadline,created_at+interval '12 hours') AND payment_status='paid';
 GET DIAGNOSTICS n=ROW_COUNT; RETURN n;
END $$;
REVOKE ALL ON FUNCTION public.v52_expire_owner_requests() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.v52_expire_owner_requests() TO service_role;
-- Set deadline when payment is verified, not when reservation is created.
CREATE OR REPLACE FUNCTION public.v46_mark_payment_verified(p_reservation uuid,p_payment_id text,p_amount numeric)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r public.reservations%rowtype;
BEGIN
 IF current_setting('request.jwt.claim.role',true) IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Service role only'; END IF;
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation FOR UPDATE;
 IF NOT FOUND OR r.amount<>p_amount OR r.status NOT IN ('pending_payment','pending_owner') THEN RAISE EXCEPTION 'Payment mismatch or invalid state'; END IF;
 IF r.mp_payment_id IS NOT NULL AND r.mp_payment_id<>p_payment_id THEN RAISE EXCEPTION 'Different payment already recorded'; END IF;
 UPDATE public.reservations SET status='pending_owner',payment_status='paid',mp_payment_id=p_payment_id,expires_at=NULL,
 owner_response_deadline=coalesce(owner_response_deadline,now()+interval '12 hours') WHERE id=p_reservation;
END $$;
REVOKE ALL ON FUNCTION public.v46_mark_payment_verified(uuid,text,numeric) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.v46_mark_payment_verified(uuid,text,numeric) TO service_role;
-- Owners can see their reservations without seeing other properties' reservations.
DROP POLICY IF EXISTS v52_owner_read_reservations ON public.reservations;
CREATE POLICY v52_owner_read_reservations ON public.reservations FOR SELECT TO authenticated
USING(EXISTS(SELECT 1 FROM public.properties p WHERE p.id=property_id AND p.owner_id=auth.uid()));
