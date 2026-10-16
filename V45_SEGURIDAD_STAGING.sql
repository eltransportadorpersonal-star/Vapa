-- V45: correcciones de seguridad para ejecutar DESPUES de V43 y V44, solo en staging.
-- Evita aceptar reservas no pagadas y evita fotos inexistentes.
create or replace function public.v44_approve_reservation(p_id uuid,p_accept boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.reservations%rowtype;
begin
 if auth.uid() is null then raise exception 'Autenticación requerida'; end if;
 select * into r from public.reservations where id=p_id for update;
 if not found then raise exception 'Reserva inexistente'; end if;
 if not exists(select 1 from public.properties p where p.id=r.property_id and p.owner_id=auth.uid()) then raise exception 'No autorizado'; end if;
 if r.status <> 'pending_owner' then raise exception 'La reserva no espera aprobación'; end if;
 if r.payment_status <> 'paid' then raise exception 'Pago no verificado'; end if;
 if p_accept then
  update public.reservations set status='confirmed',approved_at=now(),dog_info_due_at=now()+interval '24 hours',dogs_expected=greatest(dogs_expected,1) where id=p_id;
 else
  update public.reservations set status='rejected',rejected_at=now() where id=p_id;
 end if;
 return jsonb_build_object('id',p_id,'status',case when p_accept then 'confirmed' else 'rejected' end);
end $$;
revoke all on function public.v44_approve_reservation(uuid,boolean) from public,anon;
grant execute on function public.v44_approve_reservation(uuid,boolean) to authenticated;

-- Acceso sólo si hay reserva aprobada y todas las fichas tienen fotografía REAL en storage.
-- No bloquea ni cancela automáticamente al vencer 24h.
create or replace function public.v44_entry_allowed(p_id uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare r public.reservations%rowtype; n integer;
begin
 if auth.uid() is null then raise exception 'Autenticación requerida'; end if;
 select * into r from public.reservations where id=p_id;
 if not found then return false; end if;
 if r.user_id is distinct from auth.uid() and not exists(select 1 from public.properties p where p.id=r.property_id and p.owner_id=auth.uid()) then raise exception 'No autorizado'; end if;
 select count(*) into n from public.reservation_dogs d
 where d.reservation_id=p_id and nullif(trim(d.name),'') is not null
 and d.age is not null and nullif(trim(d.breed),'') is not null
 and nullif(trim(d.size),'') is not null and nullif(trim(d.sex),'') is not null
 and nullif(trim(d.sterilized),'') is not null and nullif(trim(d.aggression),'') is not null
 and exists(select 1 from storage.objects o where o.bucket_id='vapa-dog-photos' and o.name=d.photo_path);
 return r.status='confirmed' and r.payment_status='paid' and r.dogs_expected>0 and n>=r.dogs_expected;
end $$;
revoke all on function public.v44_entry_allowed(uuid) from public,anon;
grant execute on function public.v44_entry_allowed(uuid) to authenticated;

-- Bucket privado y escritura exclusiva en carpeta del usuario autenticado.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('vapa-dog-photos','vapa-dog-photos',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists v45_dog_photo_upload on storage.objects;
create policy v45_dog_photo_upload on storage.objects for insert to authenticated
with check(bucket_id='vapa-dog-photos' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists v45_dog_photo_owner_read on storage.objects;
create policy v45_dog_photo_owner_read on storage.objects for select to authenticated
using(bucket_id='vapa-dog-photos' and (storage.foldername(name))[1]=auth.uid()::text);
-- Lectura del propietario: servir fotografías con URLs firmadas generadas en backend autorizado,
-- no conceder lectura pública a todo el bucket.
