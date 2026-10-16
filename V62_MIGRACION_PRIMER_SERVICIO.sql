-- VAPA V62: primera reserva o traslado sin ficha, desde el segundo servicio ficha obligatoria.
-- Ejecutar en Supabase SQL Editor. Requiere tablas de V43 y V55.
ALTER TABLE public.v55_trip_requests ALTER COLUMN dog_id DROP NOT NULL;
DROP POLICY IF EXISTS v55_trip_insert ON public.v55_trip_requests;
CREATE POLICY v55_trip_insert ON public.v55_trip_requests FOR INSERT TO authenticated
WITH CHECK (user_id=auth.uid() AND status='requested' AND (dog_id IS NULL OR EXISTS
 (SELECT 1 FROM public.dogs d WHERE d.id=dog_id AND d.owner_id=auth.uid())));

CREATE OR REPLACE FUNCTION public.v62_require_dog_after_first()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE prior_count integer; has_dog boolean;
BEGIN
 IF TG_TABLE_NAME='reservations' THEN
   SELECT (SELECT count(*) FROM public.reservations r WHERE r.user_id=NEW.user_id
      AND r.status NOT IN ('rejected','cancelled')) +
      (SELECT count(*) FROM public.v55_trip_requests t WHERE t.user_id=NEW.user_id
      AND t.status NOT IN ('rejected','cancelled')) INTO prior_count;
 ELSE
   SELECT (SELECT count(*) FROM public.reservations r WHERE r.user_id=NEW.user_id
      AND r.status NOT IN ('rejected','cancelled')) +
      (SELECT count(*) FROM public.v55_trip_requests t WHERE t.user_id=NEW.user_id
      AND t.status NOT IN ('rejected','cancelled')) INTO prior_count;
 END IF;
 SELECT EXISTS(SELECT 1 FROM public.dogs d WHERE d.owner_id=NEW.user_id) INTO has_dog;
 IF prior_count>=1 AND NOT has_dog THEN
   RAISE EXCEPTION 'Desde tu segunda reserva o viaje debes registrar tu perro en Mis perros.';
 END IF;
 IF TG_TABLE_NAME='v55_trip_requests' AND prior_count>=1 AND NEW.dog_id IS NULL THEN
   RAISE EXCEPTION 'Selecciona tu perro registrado para este viaje.';
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS v62_reservation_dog_rule ON public.reservations;
CREATE TRIGGER v62_reservation_dog_rule BEFORE INSERT ON public.reservations
FOR EACH ROW EXECUTE FUNCTION public.v62_require_dog_after_first();
DROP TRIGGER IF EXISTS v62_trip_dog_rule ON public.v55_trip_requests;
CREATE TRIGGER v62_trip_dog_rule BEFORE INSERT ON public.v55_trip_requests
FOR EACH ROW EXECUTE FUNCTION public.v62_require_dog_after_first();
