-- V57: ubicación aproximada de cobertura para conductores aprobados.
-- Ejecutar después de V55_FASE1_SUPABASE.sql.
ALTER TABLE public.v55_drivers ADD COLUMN IF NOT EXISTS map_lat double precision;
ALTER TABLE public.v55_drivers ADD COLUMN IF NOT EXISTS map_lng double precision;
ALTER TABLE public.v55_drivers ADD CONSTRAINT v57_driver_lat_range CHECK (map_lat IS NULL OR map_lat BETWEEN -90 AND 90);
ALTER TABLE public.v55_drivers ADD CONSTRAINT v57_driver_lng_range CHECK (map_lng IS NULL OR map_lng BETWEEN -180 AND 180);
-- Solo exponer datos no personales de conductores aprobados.
DROP POLICY IF EXISTS v57_drivers_public ON public.v55_drivers;
CREATE POLICY v57_drivers_public ON public.v55_drivers FOR SELECT TO anon USING (status='approved');
DROP POLICY IF EXISTS v57_drivers_authenticated ON public.v55_drivers;
CREATE POLICY v57_drivers_authenticated ON public.v55_drivers FOR SELECT TO authenticated USING (status='approved');
-- Los administradores asignan coordenadas de zonas aproximadas desde Supabase.
-- No publicar direcciones privadas ni ubicación GPS en vivo.
