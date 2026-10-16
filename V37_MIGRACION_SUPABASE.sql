-- VAPA V37: edición con nueva revisión, sin duplicar propiedades.
-- Ejecutar en Supabase > SQL Editor, una vez. La función valida propiedad y usuario.
create or replace function public.resubmit_owned_property(
  p_id uuid, p_name text, p_commune text, p_address text,
  p_sqm integer, p_price_per_person integer, p_max_dogs integer,
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
     p_sqm <= 0 or p_price_per_person < 0 or p_max_dogs <= 0 then
    raise exception 'Revisa los datos de la propiedad';
  end if;
  update public.properties set name=trim(p_name), commune=trim(p_commune),
    address=trim(p_address), sqm=p_sqm, price_per_person=p_price_per_person,
    max_dogs=p_max_dogs, description=trim(p_description),
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
revoke all on function public.resubmit_owned_property(uuid,text,text,text,integer,integer,integer,text,text[]) from public;
grant execute on function public.resubmit_owned_property(uuid,text,text,text,integer,integer,integer,text,text[]) to authenticated;
