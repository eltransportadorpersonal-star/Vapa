-- VAPA V44. Aplicar SOLO después de V43_MIGRACION_RESERVAS.sql.
-- Revisar en ambiente de pruebas y respaldar antes de producción.
alter table public.reservations add column if not exists approved_at timestamptz;
alter table public.reservations add column if not exists rejected_at timestamptz;
alter table public.reservations add column if not exists dog_info_due_at timestamptz;
alter table public.reservations add column if not exists dog_info_completed_at timestamptz;
alter table public.reservations add column if not exists dogs_expected integer not null default 0;
alter table public.reservations add column if not exists reminder_sent_at timestamptz;
create table if not exists public.reservation_dogs (
 id uuid primary key default gen_random_uuid(), reservation_id uuid not null references public.reservations(id) on delete cascade,
 owner_id uuid not null references auth.users(id), name text not null,
 age integer, breed text, size text, sex text, sterilized text, aggression text,
 photo_path text, created_at timestamptz not null default now(),
 unique(reservation_id,name)
);
alter table public.reservation_dogs enable row level security;
-- No policies for direct writes: all writes go through validated RPC.
create or replace function public.v44_approve_reservation(p_id uuid,p_accept boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.reservations%rowtype;
begin
 select * into r from public.reservations where id=p_id for update;
 if not found then raise exception 'Reserva inexistente'; end if;
 if not exists(select 1 from public.properties p where p.id=r.property_id and p.owner_id=auth.uid()) then raise exception 'No autorizado'; end if;
 if r.status <> 'pending_owner' then raise exception 'La reserva ya fue procesada'; end if;
 if p_accept then
  update public.reservations set status='confirmed',approved_at=now(),dog_info_due_at=now()+interval '24 hours' where id=p_id;
 else
  update public.reservations set status='rejected',rejected_at=now() where id=p_id;
 end if;
 return jsonb_build_object('id',p_id,'status',case when p_accept then 'confirmed' else 'rejected' end);
end $$;
revoke all on function public.v44_approve_reservation(uuid,boolean) from public,anon;
grant execute on function public.v44_approve_reservation(uuid,boolean) to authenticated;
-- Requiere que el huésped suba imágenes a un bucket PRIVADO y pase la ruta del objeto.
-- Esta RPC solo registra metadatos; no certifica por sí misma que el archivo exista.
create or replace function public.v44_save_reservation_dog(p_reservation uuid,p_name text,p_photo_path text,p_age integer,p_breed text,p_size text,p_sex text,p_sterilized text,p_aggression text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.reservations%rowtype; v_count integer;
begin
 select * into r from public.reservations where id=p_reservation for update;
 if not found or r.user_id is distinct from auth.uid() then raise exception 'No autorizado'; end if;
 if r.status not in ('pending_owner','confirmed') then raise exception 'Reserva no editable'; end if;
 if nullif(trim(p_name),'') is null or nullif(trim(p_photo_path),'') is null or p_age is null or nullif(trim(p_breed),'') is null or nullif(trim(p_size),'') is null or nullif(trim(p_sex),'') is null or nullif(trim(p_sterilized),'') is null or nullif(trim(p_aggression),'') is null then raise exception 'Completa la ficha y la foto'; end if;
 if p_photo_path not like auth.uid()::text || '/%' then raise exception 'Ruta de fotografía inválida'; end if;
 select count(*) into v_count from public.reservation_dogs where reservation_id=p_reservation;
 if v_count >= r.dogs_expected and not exists(select 1 from public.reservation_dogs where reservation_id=p_reservation and name=p_name) then raise exception 'Cantidad de perros superada'; end if;
 insert into public.reservation_dogs(reservation_id,owner_id,name,photo_path,age,breed,size,sex,sterilized,aggression)
 values(p_reservation,auth.uid(),trim(p_name),p_photo_path,p_age,p_breed,p_size,p_sex,p_sterilized,p_aggression)
 on conflict(reservation_id,name) do update set photo_path=excluded.photo_path,age=excluded.age,breed=excluded.breed,size=excluded.size,sex=excluded.sex,sterilized=excluded.sterilized,aggression=excluded.aggression;
 select count(*) into v_count from public.reservation_dogs where reservation_id=p_reservation;
 if v_count >= r.dogs_expected then update public.reservations set dog_info_completed_at=now() where id=p_reservation; end if;
 return jsonb_build_object('saved',true,'complete',v_count>=r.dogs_expected);
end $$;
revoke all on function public.v44_save_reservation_dog(uuid,text,text,integer,text,text,text,text,text) from public,anon;
grant execute on function public.v44_save_reservation_dog(uuid,text,text,integer,text,text,text,text,text) to authenticated;
-- Acceso de ingreso calculado en servidor. El vencimiento de 24h NO cancela la reserva.
create or replace function public.v44_entry_allowed(p_id uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare r public.reservations%rowtype; n integer;
begin
 select * into r from public.reservations where id=p_id;
 if not found then return false; end if;
 if r.user_id is distinct from auth.uid() and not exists(select 1 from public.properties p where p.id=r.property_id and p.owner_id=auth.uid()) then raise exception 'No autorizado'; end if;
 select count(*) into n from public.reservation_dogs where reservation_id=p_id and photo_path is not null;
 return r.status='confirmed' and n>=r.dogs_expected and r.dogs_expected>0;
end $$;
revoke all on function public.v44_entry_allowed(uuid) from public,anon;
grant execute on function public.v44_entry_allowed(uuid) to authenticated;
-- ATENCION: revisar políticas RLS de reservations y properties para lectura por propietarios.
-- El envío de recordatorios necesita un job servidor autenticado, no JavaScript en el navegador.
