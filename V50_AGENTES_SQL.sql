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
