-- VAPA V33 · Ejecutar en Supabase SQL Editor
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'user' check (role in ('user','admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  commune text not null,
  address text not null,
  sqm integer,
  price_per_person integer,
  max_dogs integer,
  description text,
  status text not null default 'draft' check (status in ('draft','pending_review','changes_requested','published','rejected')),
  review_note text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.property_photos (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  url text not null,
  sort_order integer default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.dogs (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null, breed text, size text, sex text, age integer,
 created_at timestamptz default now()
);

create table if not exists public.reservations (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id),
 property_id uuid not null references public.properties(id),
 start_at timestamptz not null, end_at timestamptz not null,
 people integer not null default 1, amount integer,
 status text not null default 'pending',
 created_at timestamptz default now()
);

alter table profiles enable row level security;
alter table properties enable row level security;
alter table property_photos enable row level security;
alter table dogs enable row level security;
alter table reservations enable row level security;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from profiles where id=auth.uid() and role='admin'); $$;

create policy "published properties public" on properties for select using (status='published' or owner_id=auth.uid() or public.is_admin());
create policy "owners insert properties" on properties for insert to authenticated with check(owner_id=auth.uid());
create policy "owners update own unpublished" on properties for update to authenticated using(owner_id=auth.uid() and status<>'published') with check(owner_id=auth.uid());
create policy "admins update properties" on properties for update to authenticated using(public.is_admin()) with check(public.is_admin());

create policy "photos public for visible properties" on property_photos for select using(exists(select 1 from properties p where p.id=property_id and (p.status='published' or p.owner_id=auth.uid() or public.is_admin())));
create policy "owners add photos" on property_photos for insert to authenticated with check(exists(select 1 from properties p where p.id=property_id and p.owner_id=auth.uid()));

create policy "own dogs" on dogs for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "own reservations" on reservations for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy "create own reservations" on reservations for insert to authenticated with check(user_id=auth.uid());

insert into storage.buckets (id,name,public) values ('property-photos','property-photos',true) on conflict (id) do nothing;
create policy "authenticated upload property photos" on storage.objects for insert to authenticated with check(bucket_id='property-photos');
create policy "public property photos" on storage.objects for select using(bucket_id='property-photos');

-- Después de crear tu primera cuenta, conviértela en admin manualmente:
-- insert into profiles(id,full_name,role) values ('TU_USER_UUID','José Cabrera','admin')
-- on conflict(id) do update set role='admin';
