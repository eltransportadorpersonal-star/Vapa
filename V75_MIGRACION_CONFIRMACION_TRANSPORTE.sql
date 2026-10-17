-- V75. Ejecutar después de V61. No crea ni captura pagos.
ALTER TABLE public.v55_trip_requests ADD COLUMN IF NOT EXISTS confirmed_pickup text;
ALTER TABLE public.v55_trip_requests ADD COLUMN IF NOT EXISTS confirmed_dropoff text;
ALTER TABLE public.v55_trip_requests ADD COLUMN IF NOT EXISTS route_confirmed_at timestamptz;
ALTER TABLE public.v55_trip_requests ADD COLUMN IF NOT EXISTS passenger_confirmed_at timestamptz;
ALTER TABLE public.v55_trip_requests DROP CONSTRAINT IF EXISTS v55_trip_requests_status_check;
ALTER TABLE public.v55_trip_requests ADD CONSTRAINT v55_trip_requests_status_check CHECK(status IN ('requested','reviewing','approved','driver_pending','driver_accepted','route_confirmed','awaiting_payment','rejected','cancelled','completed'));
CREATE OR REPLACE FUNCTION public.v75_driver_confirm_route(p_trip uuid,p_pickup text,p_dropoff text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF length(trim(p_pickup))<8 OR length(trim(p_dropoff))<8 OR length(p_pickup)>300 OR length(p_dropoff)>300 THEN RAISE EXCEPTION 'Direcciones incompletas'; END IF;
 UPDATE public.v55_trip_requests t SET confirmed_pickup=trim(p_pickup),confirmed_dropoff=trim(p_dropoff),route_confirmed_at=now(),passenger_confirmed_at=NULL,status='route_confirmed'
 WHERE t.id=p_trip AND t.status='driver_accepted' AND EXISTS(SELECT 1 FROM public.v55_drivers d WHERE d.id=t.assigned_driver_id AND d.user_id=auth.uid() AND d.status='approved');
 IF NOT FOUND THEN RAISE EXCEPTION 'Viaje no disponible para confirmación'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.v75_passenger_confirm_route(p_trip uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 UPDATE public.v55_trip_requests SET passenger_confirmed_at=now(),status='awaiting_payment'
 WHERE id=p_trip AND user_id=auth.uid() AND status='route_confirmed' AND confirmed_pickup IS NOT NULL AND confirmed_dropoff IS NOT NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'Solicitud no disponible para confirmar'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.v75_driver_confirm_route(uuid,text,text),public.v75_passenger_confirm_route(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.v75_driver_confirm_route(uuid,text,text),public.v75_passenger_confirm_route(uuid) TO authenticated;
-- Falta: cotización firmada en servidor, token OAuth de conductor, split habilitado, checkout y webhook idempotente.
