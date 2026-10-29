-- VAPA V82: registro de liquidaciones. Ejecutar manualmente en Supabase SQL Editor.
-- IMPORTANTE: solo un backend con service_role debe insertar o actualizar movimientos.
create table if not exists public.v82_provider_settlements (
 id uuid primary key default gen_random_uuid(),
 provider_id uuid not null references auth.users(id),
 reservation_id uuid,
 payment_reference text unique,
 gross_clp bigint not null check (gross_clp>=0),
 platform_clp bigint not null check (platform_clp>=0),
 provider_clp bigint not null check (provider_clp>=0),
 processor_fee_clp bigint check (processor_fee_clp>=0),
 rate_bps integer not null check (rate_bps in (1000,1500)),
 status text not null default 'pending' check (status in ('pending','available','paid','refunded','disputed')),
 created_at timestamptz not null default now(),
 paid_at timestamptz,
 constraint v82_amounts_match check (gross_clp=platform_clp+provider_clp),
 constraint v82_paid_date check (status <> 'paid' or paid_at is not null)
);
create index if not exists v82_settlements_provider_date on public.v82_provider_settlements(provider_id,created_at desc);
alter table public.v82_provider_settlements enable row level security;
revoke all on public.v82_provider_settlements from anon, authenticated;
grant select on public.v82_provider_settlements to authenticated;
drop policy if exists v82_provider_select on public.v82_provider_settlements;
create policy v82_provider_select on public.v82_provider_settlements for select to authenticated using (provider_id=auth.uid());
-- Sin políticas INSERT/UPDATE/DELETE para usuarios. No se habilitan pagos ni transferencias.
