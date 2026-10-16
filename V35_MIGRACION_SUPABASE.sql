-- VAPA V35 · Ejecutar UNA VEZ en Supabase > SQL Editor
-- Refuerza permisos para que solo un administrador pueda publicar propiedades.

-- 1) Crear perfil automáticamente para cada cuenta nueva.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)), 'user')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- 2) Políticas de perfiles.
drop policy if exists "users read own profile" on public.profiles;
drop policy if exists "users insert own profile" on public.profiles;
drop policy if exists "users update own profile" on public.profiles;
drop policy if exists "admins read profiles" on public.profiles;

create policy "users read own profile" on public.profiles
for select to authenticated
using (id = auth.uid() or public.is_admin());

create policy "users insert own profile" on public.profiles
for insert to authenticated
with check (id = auth.uid() and role = 'user');

create policy "users update own profile" on public.profiles
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid() and role = 'user');

-- 3) Corregir política de propiedades: un anfitrión NUNCA puede ponerse published.
drop policy if exists "owners update own unpublished" on public.properties;
create policy "owners update own unpublished" on public.properties
for update to authenticated
using (owner_id = auth.uid() and status <> 'published')
with check (
  owner_id = auth.uid()
  and status in ('draft','pending_review','changes_requested','rejected')
);

-- 4) Reforzar carga de fotos para que cada usuario use su propia carpeta.
drop policy if exists "authenticated upload property photos" on storage.objects;
create policy "authenticated upload property photos" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'property-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- 5) Crear perfiles faltantes para usuarios ya existentes.
insert into public.profiles (id, full_name, role)
select u.id, coalesce(u.raw_user_meta_data->>'full_name', split_part(u.email,'@',1)), 'user'
from auth.users u
left join public.profiles p on p.id=u.id
where p.id is null
on conflict (id) do nothing;

-- IMPORTANTE: si tu usuario administrador todavía no figura como admin,
-- reemplaza TU_CORREO por tu correo real y ejecuta estas 3 líneas aparte:
-- update public.profiles p set role='admin'
-- from auth.users u
-- where p.id=u.id and u.email='TU_CORREO';
