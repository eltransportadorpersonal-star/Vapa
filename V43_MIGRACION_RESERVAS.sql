-- VAPA V43: descuento único máximo entre personas y bloques, un perro por persona.
-- Si ejecutaste una migración V43 anterior, revoca y elimina la firma RPC antigua por separado después de revisar dependencias.
-- VAPA V43: ejecutar en Supabase SQL Editor, después de respaldar datos.
-- No activar cobros reales hasta integrar una pasarela con verificación del servidor.
create extension if not exists btree_gist;
alter table public.reservations add column if not exists pool boolean not null default false;
alter table public.reservations add column if not exists blocks integer not null default 1;
alter table public.reservations add column if not exists small_extra_dogs integer not null default 0;
alter table public.reservations add column if not exists large_extra_dogs integer not null default 0;
alter table public.reservations add column if not exists payment_status text not null default 'unpaid';
alter table public.reservations add column if not exists expires_at timestamptz;
-- Evitar reservas superpuestas, incluso bajo solicitudes simultáneas.
-- No elimina reservas existentes.
do $$ begin
 if not exists (select 1 from pg_constraint where conname='v43_reservation_no_overlap') then
  alter table public.reservations add constraint v43_reservation_no_overlap
   exclude using gist (property_id with =, tstzrange(start_at,end_at,'[)') with &&)
   where (status in ('pending_payment','confirmed'));
 end if;
end $$;

create or replace function public.v43_create_reservation(
 p_property_id uuid, p_day date, p_slot integer, p_blocks integer,
 p_people integer, p_dogs integer, p_pool boolean
) returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_user uuid := auth.uid(); v_property public.properties%rowtype;
 v_start timestamptz; v_end timestamptz; v_base integer; v_amount integer;
 v_person_discount numeric; v_block_discount numeric; v_id uuid;
begin
 if v_user is null then raise exception 'Inicia sesión para reservar'; end if;
 if p_slot not between 0 and 5 or p_blocks not between 1 and 3 or p_slot+p_blocks>6 then raise exception 'Bloques fuera de horario'; end if;
 if p_people not between 1 and 4 then raise exception 'Cantidad de personas no permitida'; end if;
 if p_dogs<0 or p_dogs>3 or p_dogs>p_people then raise exception 'Máximo tres perros y uno por persona'; end if;
 select * into v_property from public.properties where id=p_property_id and status='published';
 if not found then raise exception 'Propiedad no publicada'; end if;
 if p_dogs>coalesce(v_property.max_dogs,3) then raise exception 'Supera la capacidad de perros'; end if;
 v_start := (p_day::timestamp + interval '10 hours' + p_slot*interval '90 minutes') at time zone 'America/Santiago';
 v_end := v_start+p_blocks*interval '90 minutes';
 if v_start <= now() then raise exception 'Selecciona una fecha futura'; end if;
 v_base := case when p_pool then 24000 else 18000 end;
 v_person_discount := case p_people when 2 then .10 when 3 then .15 when 4 then .20 else 0 end;
 v_block_discount := case p_blocks when 2 then .10 when 3 then .15 else 0 end;
 v_amount := round((v_base*p_people*p_blocks)*(1-greatest(v_person_discount,v_block_discount)));
 -- Las reservas pendientes expiran en 15 minutos y dejan libre el intervalo.
 update public.reservations set status='expired' where status='pending_payment' and expires_at < now();
 insert into public.reservations(user_id,property_id,start_at,end_at,people,amount,status,pool,blocks,small_extra_dogs,large_extra_dogs,payment_status,expires_at)
 values(v_user,p_property_id,v_start,v_end,p_people,v_amount,'pending_payment',p_pool,p_blocks,0,0,'unpaid',now()+interval '15 minutes') returning id into v_id;
 return jsonb_build_object('id',v_id,'amount',v_amount,'status','pending_payment','expires_at',now()+interval '15 minutes');
exception when exclusion_violation then raise exception 'Horario ocupado, selecciona otro';
end $$;
revoke all on function public.v43_create_reservation(uuid,date,integer,integer,integer,integer,boolean) from public;
grant execute on function public.v43_create_reservation(uuid,date,integer,integer,integer,integer,boolean) to authenticated;
-- IMPORTANTE: no se incluye una función pública que confirme pagos.
-- La confirmación deberá realizarse exclusivamente desde una función servidor autenticada con la pasarela.

-- Consulta de disponibilidad sin exponer nombres ni datos de otros huéspedes.
create or replace function public.v43_check_availability(
 p_property_id uuid, p_day date, p_slot integer, p_blocks integer
) returns boolean language plpgsql security definer set search_path=public as $$
declare v_start timestamptz; v_end timestamptz;
begin
 if p_slot is null or p_blocks is null or p_slot not between 0 and 5 or p_blocks not between 1 and 3 or p_slot+p_blocks>6 then return false; end if;
 if not exists(select 1 from public.properties where id=p_property_id and status='published') then return false; end if;
 v_start := (p_day::timestamp + interval '10 hours' + p_slot*interval '90 minutes') at time zone 'America/Santiago';
 v_end := v_start+p_blocks*interval '90 minutes';
 if v_start<=now() then return false; end if;
 return not exists (
  select 1 from public.reservations r where r.property_id=p_property_id
  and (r.status='confirmed' or (r.status='pending_payment' and r.expires_at>now()))
  and tstzrange(r.start_at,r.end_at,'[)') && tstzrange(v_start,v_end,'[)')
 );
end $$;
revoke all on function public.v43_check_availability(uuid,date,integer,integer) from public;
grant execute on function public.v43_check_availability(uuid,date,integer,integer) to anon,authenticated;

-- Para evitar que pendientes vencidas bloqueen horarios hasta una nueva reserva,
-- la función de reserva las cambia a 'expired' antes del INSERT.
-- Verificar antes de aplicar que no existan reservas históricas superpuestas con
-- estado pending_payment/confirmed; de lo contrario fallará la restricción EXCLUDE.

-- Deshabilitar ejecución de la firma anterior de ocho parámetros si existe.
do $$ begin
 if to_regprocedure('public.v43_create_reservation(uuid,date,integer,integer,integer,boolean,integer,integer)') is not null then
  execute 'revoke all on function public.v43_create_reservation(uuid,date,integer,integer,integer,boolean,integer,integer) from public, anon, authenticated';
 end if;
end $$;

-- Retirar acceso a la versión anterior de la función sin cantidad de perros.
do $$ begin if to_regprocedure('public.v43_create_reservation(uuid,date,integer,integer,integer,boolean)') is not null then execute 'revoke all on function public.v43_create_reservation(uuid,date,integer,integer,integer,boolean) from public, anon, authenticated'; end if; end $$;
