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
-- Incentivo fijo: 300 a 1000 m² = 5000 CLP; >1000 m² = 10000 CLP.
-- Comisión: reparto 50/50 de la comisión neta de plataforma por reserva efectivamente pagada.
-- Agente recibe 50%; VAPA conserva 50% antes de otros gastos. No es 50% del total de la reserva.
-- La creación automática de earnings requiere webhook verificado de Mercado Pago y lógica backend.
