-- VAPA V51. Ejecutar en Supabase SQL Editor ANTES de publicar la web.
-- Se mantiene price_per_person como columna heredada, ahora representa precio base POR BLOQUE.
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS extra_dog_price integer NOT NULL DEFAULT 5000;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS pool_price_per_block integer NOT NULL DEFAULT 6000;
ALTER TABLE public.properties ADD CONSTRAINT v51_extra_dog_price_nonnegative CHECK (extra_dog_price>=0);
ALTER TABLE public.properties ADD CONSTRAINT v51_pool_price_nonnegative CHECK (pool_price_per_block>=0);
-- Los precios históricos de price_per_person se conservan sin modificación.

create or replace function public.v43_create_reservation(
 p_property_id uuid, p_day date, p_slot integer, p_blocks integer,
 p_people integer, p_dogs integer, p_pool boolean
) returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_user uuid := auth.uid(); v_property public.properties%rowtype;
 v_start timestamptz; v_end timestamptz; v_base integer; v_amount integer;
 v_block_discount numeric; v_id uuid; v_extra_dog_price integer; v_pool_price integer;
begin
 if v_user is null then raise exception 'Inicia sesión para reservar'; end if;
 if p_slot not between 0 and 5 or p_blocks not between 1 and 6 or p_slot+p_blocks>6 then raise exception 'Bloques fuera de horario'; end if;
 if p_people not between 1 and 4 then raise exception 'Cantidad de personas no permitida'; end if;
 if p_dogs<1 or p_dogs>12 then raise exception 'Cantidad de perros no permitida'; end if;
 select * into v_property from public.properties where id=p_property_id and status='published';
 if not found then raise exception 'Propiedad no publicada'; end if;
 if p_dogs>coalesce(v_property.max_dogs,3) then raise exception 'Supera la capacidad de perros'; end if;
 v_start := (p_day::timestamp + interval '10 hours' + p_slot*interval '90 minutes') at time zone 'America/Santiago';
 v_end := v_start+p_blocks*interval '90 minutes';
 if v_start <= now() then raise exception 'Selecciona una fecha futura'; end if;
 v_base := coalesce(v_property.price_per_person,18000);
 v_extra_dog_price := coalesce(v_property.extra_dog_price,5000);
 v_pool_price := case when p_pool then coalesce(v_property.pool_price_per_block,6000) else 0 end;
 v_block_discount := case when p_blocks>=4 then .20 when p_blocks=3 then .15 when p_blocks=2 then .10 else 0 end;
 v_amount := round(((v_base+v_pool_price+greatest(0,p_dogs-1)*v_extra_dog_price)*p_blocks)*(1-v_block_discount));
 -- Las reservas pendientes expiran en 15 minutos y dejan libre el intervalo.
 update public.reservations set status='expired' where status='pending_payment' and expires_at < now();
 insert into public.reservations(user_id,property_id,start_at,end_at,people,amount,status,pool,blocks,small_extra_dogs,large_extra_dogs,payment_status,expires_at)
 values(v_user,p_property_id,v_start,v_end,p_people,v_amount,'pending_payment',p_pool,p_blocks,0,0,'unpaid',now()+interval '15 minutes') returning id into v_id;
 return jsonb_build_object('id',v_id,'amount',v_amount,'status','pending_payment','expires_at',now()+interval '15 minutes');
exception when exclusion_violation then raise exception 'Horario ocupado, selecciona otro';
end $$;
REVOKE ALL ON FUNCTION public.v43_create_reservation(uuid,date,integer,integer,integer,integer,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.v43_create_reservation(uuid,date,integer,integer,integer,integer,boolean) TO authenticated;

create or replace function public.v43_check_availability(
 p_property_id uuid, p_day date, p_slot integer, p_blocks integer
) returns boolean language plpgsql security definer set search_path=public as $$
declare v_start timestamptz; v_end timestamptz;
begin
 if p_slot is null or p_blocks is null or p_slot not between 0 and 5 or p_blocks not between 1 and 6 or p_slot+p_blocks>6 then return false; end if;
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
REVOKE ALL ON FUNCTION public.v43_check_availability(uuid,date,integer,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.v43_check_availability(uuid,date,integer,integer) TO anon,authenticated;

-- Sustituye la firma anterior del editor sin afectar registros existentes.
DROP FUNCTION IF EXISTS public.resubmit_owned_property(uuid,text,text,text,integer,integer,integer,text,text[]);
create or replace function public.resubmit_owned_property(
  p_id uuid, p_name text, p_commune text, p_address text,
  p_sqm integer, p_price_per_person integer, p_max_dogs integer,
  p_extra_dog_price integer, p_pool_price_per_block integer,
  p_description text, p_photo_urls text[] default null
) returns void language plpgsql security definer set search_path = public
as $$
declare v_owner uuid; v_url text; v_index integer := 0;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  select owner_id into v_owner from public.properties where id = p_id for update;
  if not found or v_owner is distinct from auth.uid() then
    raise exception 'No tienes permiso para editar esta propiedad';
  end if;
  if nullif(trim(p_name),'') is null or nullif(trim(p_commune),'') is null or
     nullif(trim(p_address),'') is null or nullif(trim(p_description),'') is null or
     p_sqm <= 0 or p_price_per_person < 0 or p_max_dogs <= 0 or p_extra_dog_price < 0 or p_pool_price_per_block < 0 then
    raise exception 'Revisa los datos de la propiedad';
  end if;
  update public.properties set name=trim(p_name), commune=trim(p_commune),
    address=trim(p_address), sqm=p_sqm, price_per_person=p_price_per_person,
    max_dogs=p_max_dogs, extra_dog_price=p_extra_dog_price, pool_price_per_block=p_pool_price_per_block, description=trim(p_description),
    status='pending_review', review_note=null, reviewed_at=null
  where id=p_id;
  if p_photo_urls is not null then
    if cardinality(p_photo_urls) < 1 or cardinality(p_photo_urls) > 15 then
      raise exception 'Selecciona entre 1 y 15 fotos';
    end if;
    -- Solo admitir URLs del bucket de fotos del propio usuario.
    foreach v_url in array p_photo_urls loop
      if v_url not like '%/storage/v1/object/public/property-photos/' || auth.uid()::text || '/' || p_id::text || '/%' then
        raise exception 'La URL de fotografía no corresponde a esta propiedad';
      end if;
    end loop;
    delete from public.property_photos where property_id=p_id;
    foreach v_url in array p_photo_urls loop
      insert into public.property_photos(property_id,url,sort_order) values(p_id,v_url,v_index);
      v_index := v_index + 1;
    end loop;
  end if;
end; $$;
REVOKE ALL ON FUNCTION public.resubmit_owned_property(uuid,text,text,text,integer,integer,integer,integer,integer,text,text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resubmit_owned_property(uuid,text,text,text,integer,integer,integer,integer,integer,text,text[]) TO authenticated;
