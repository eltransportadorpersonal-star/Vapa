-- V53: aprobación previa al pago, autorización por propietario o admin.
-- No procesa pagos ni reembolsos; conservar webhooks verificados y cron por separado.
ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS owner_decided_at timestamptz;
ALTER TABLE public.reservations ADD COLUMN IF NOT EXISTS owner_preapproved boolean NOT NULL DEFAULT false;
CREATE OR REPLACE FUNCTION public.v53_owner_decide(p_reservation uuid,p_accept boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r public.reservations%rowtype; actor uuid:=auth.uid(); is_admin boolean;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'Autenticación requerida'; END IF;
 SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id=actor AND role='admin') INTO is_admin;
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Reserva inexistente'; END IF;
 IF NOT is_admin AND NOT EXISTS(SELECT 1 FROM public.properties WHERE id=r.property_id AND owner_id=actor) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF r.status NOT IN ('pending_payment','pending_owner') THEN RAISE EXCEPTION 'Reserva no gestionable'; END IF;
 IF r.status='pending_payment' AND now()>=r.created_at+interval '12 hours' THEN RAISE EXCEPTION 'Plazo de pago vencido'; END IF;
 IF r.status='pending_owner' AND now()>=coalesce(r.owner_response_deadline,r.created_at+interval '12 hours') THEN RAISE EXCEPTION 'Plazo de aprobación vencido'; END IF;
 IF p_accept THEN
  IF r.payment_status='paid' THEN
   UPDATE public.reservations SET status='confirmed',owner_preapproved=true,owner_decided_at=now() WHERE id=r.id;
   RETURN 'confirmed';
  ELSE
   UPDATE public.reservations SET owner_preapproved=true,owner_decided_at=now() WHERE id=r.id;
   RETURN 'approved_awaiting_payment';
  END IF;
 ELSE
  UPDATE public.reservations SET status='rejected',owner_preapproved=false,owner_decided_at=now(),
    refund_status=CASE WHEN r.payment_status='paid' THEN 'pending' ELSE refund_status END,
    refund_requested_at=CASE WHEN r.payment_status='paid' THEN now() ELSE refund_requested_at END WHERE id=r.id;
  RETURN CASE WHEN r.payment_status='paid' THEN 'refund_pending' ELSE 'rejected_unpaid' END;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.v53_owner_decide(uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.v53_owner_decide(uuid,boolean) TO authenticated;
-- Solo lecturas propias de agentes para registros de liquidación, sin escritura cliente.
DROP POLICY IF EXISTS v53_agent_earnings_read ON public.vapa_agent_earnings;
CREATE POLICY v53_agent_earnings_read ON public.vapa_agent_earnings FOR SELECT TO authenticated USING (
 EXISTS(SELECT 1 FROM public.vapa_agent_referrals f WHERE f.id=referral_id AND f.agent_id=auth.uid())
 OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.role='admin')
);
-- Para pagos verificados: en el webhook seguro, si owner_preapproved=true, confirmar;
-- en caso contrario iniciar las 12h de aprobación. Nunca desde el navegador.
