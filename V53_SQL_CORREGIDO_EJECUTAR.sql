-- VAPA V53: migración ordenada para instalaciones sin tablas de agentes.
-- No activa cobros, reembolsos ni liquidaciones automáticas.

-- V49: estructura inicial para captadores. Ejecutar en Supabase SQL Editor tras revisar políticas.
create table if not exists public.vapa_agent_referrals (
 id uuid primary key default gen_random_uuid(),
 agent_id uuid not null references auth.users(id),
 property_id uuid not null references public.properties(id),
 area_m2 numeric(12,2) not null check(area_m2 > 0),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 approved_at timestamptz,
 created_at timestamptz not null default now(),
 unique(property_id)
);
create table if not exists public.vapa_agent_earnings (
 id uuid primary key default gen_random_uuid(),
 referral_id uuid not null references public.vapa_agent_referrals(id),
 reservation_id uuid,
 kind text not null check(kind in ('activation','booking_share','reversal')),
 amount_clp bigint not null,
 status text not null default 'pending' check(status in ('pending','approved','paid','void')),
 created_at timestamptz not null default now(),
 paid_at timestamptz,
 unique(referral_id,reservation_id,kind)
);
create unique index if not exists vapa_agent_one_activation on public.vapa_agent_earnings(referral_id) where kind='activation';
alter table public.vapa_agent_referrals enable row level security;
alter table public.vapa_agent_earnings enable row level security;
-- Sin políticas de escritura desde el navegador: únicamente backend seguro con service role.
-- V53: bono objetivo 10000 CLP por propiedad con primer huésped pagado; automatización pendiente.
-- Comisión: reparto 50/50 de la comisión neta de plataforma por reserva efectivamente pagada.
-- Agente recibe 50%; VAPA conserva 50% antes de otros gastos. No es 50% del total de la reserva.
-- La creación automática de earnings requiere webhook verificado de Mercado Pago y lógica backend.


-- V50: ejecutar después de V49_CAPTADORES.sql, primero en staging.
create table if not exists public.vapa_agents (
 user_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
alter table public.vapa_agents enable row level security;
drop policy if exists v50_agent_self_read on public.vapa_agents;
create policy v50_agent_self_read on public.vapa_agents for select to authenticated using (user_id=auth.uid());
drop policy if exists v50_agent_self_enroll on public.vapa_agents;
create policy v50_agent_self_enroll on public.vapa_agents for insert to authenticated with check (user_id=auth.uid());
create or replace function public.v50_attribute_agent_property()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.owner_id=auth.uid() and exists(select 1 from public.vapa_agents where user_id=auth.uid()) then
  insert into public.vapa_agent_referrals(agent_id,property_id,area_m2,status)
  values(auth.uid(),new.id,new.sqm,'pending') on conflict(property_id) do nothing;
 end if;
 return new;
end $$;
drop trigger if exists v50_property_agent_attribution on public.properties;
create trigger v50_property_agent_attribution after insert on public.properties
for each row execute function public.v50_attribute_agent_property();
drop policy if exists v50_agent_referrals_read on public.vapa_agent_referrals;
create policy v50_agent_referrals_read on public.vapa_agent_referrals
for select to authenticated using(agent_id=auth.uid());
-- Comisión comercial: agente recibe 50% de la comisión neta de VAPA,
-- solo por reservas efectivamente pagadas y no reembolsadas.
-- No hay liquidación automática en esta versión.


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
