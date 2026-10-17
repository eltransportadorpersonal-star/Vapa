-- V72: admin update without changing owner, status or existing booking links.
-- Run in Supabase SQL Editor before using administrative editing.
CREATE OR REPLACE FUNCTION public.v72_admin_update_property(
 p_id uuid,p_name text,p_commune text,p_address text,p_sqm numeric,
 p_price_per_person numeric,p_extra_dog_price numeric,p_pool_price_per_block numeric,
 p_max_dogs integer,p_description text,p_photo_urls text[] DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='admin') THEN
   RAISE EXCEPTION 'No autorizado';
 END IF;
 IF p_photo_urls IS NOT NULL THEN RAISE EXCEPTION 'Edición administrativa de fotos pendiente de permisos Storage'; END IF;
 IF p_sqm<=0 OR p_price_per_person<0 OR p_extra_dog_price<0 OR p_pool_price_per_block<0 OR p_max_dogs<1 THEN
   RAISE EXCEPTION 'Valores fuera de rango';
 END IF;
 UPDATE public.properties SET name=p_name,commune=p_commune,address=p_address,sqm=p_sqm,
  price_per_person=p_price_per_person,extra_dog_price=p_extra_dog_price,
  pool_price_per_block=p_pool_price_per_block,max_dogs=p_max_dogs,description=p_description
 WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Propiedad no encontrada'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.v72_admin_update_property(uuid,text,text,text,numeric,numeric,numeric,numeric,integer,text,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.v72_admin_update_property(uuid,text,text,text,numeric,numeric,numeric,numeric,integer,text,text[]) TO authenticated;
