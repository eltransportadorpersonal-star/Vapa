-- V61: asignación y aceptación de viajes. Ejecutar DESPUÉS de V60.
ALTER TABLE public.v55_trip_requests ADD COLUMN IF NOT EXISTS assigned_driver_id uuid REFERENCES public.v55_drivers(id);
ALTER TABLE public.v55_trip_requests ADD COLUMN IF NOT EXISTS driver_accepted_at timestamptz;
ALTER TABLE public.v55_trip_requests ADD COLUMN IF NOT EXISTS assigned_at timestamptz;
ALTER TABLE public.v55_trip_requests DROP CONSTRAINT IF EXISTS v55_trip_requests_status_check;
ALTER TABLE public.v55_trip_requests ADD CONSTRAINT v55_trip_requests_status_check CHECK(status IN ('requested','reviewing','approved','driver_pending','driver_accepted','rejected','cancelled','completed'));
DROP POLICY IF EXISTS v61_driver_assigned_read ON public.v55_trip_requests;
CREATE POLICY v61_driver_assigned_read ON public.v55_trip_requests FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.v55_drivers d WHERE d.id=assigned_driver_id AND d.user_id=auth.uid() AND d.status='approved'));
CREATE OR REPLACE FUNCTION public.v61_assign_driver(p_trip uuid,p_driver uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NOT public.v60_is_admin() THEN RAISE EXCEPTION 'Solo administrador'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.v55_drivers WHERE id=p_driver AND status='approved') THEN RAISE EXCEPTION 'Conductor no aprobado'; END IF;
 UPDATE public.v55_trip_requests SET assigned_driver_id=p_driver,assigned_at=now(),driver_accepted_at=NULL,status='driver_pending' WHERE id=p_trip AND status IN ('requested','reviewing','approved','driver_pending');
 IF NOT FOUND THEN RAISE EXCEPTION 'Viaje no asignable'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.v61_driver_respond(p_trip uuid,p_accept boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 UPDATE public.v55_trip_requests t SET status=CASE WHEN p_accept THEN 'driver_accepted' ELSE 'reviewing' END, driver_accepted_at=CASE WHEN p_accept THEN now() ELSE NULL END, assigned_driver_id=CASE WHEN p_accept THEN t.assigned_driver_id ELSE NULL END
 WHERE t.id=p_trip AND t.status='driver_pending' AND EXISTS(SELECT 1 FROM public.v55_drivers d WHERE d.id=t.assigned_driver_id AND d.user_id=auth.uid() AND d.status='approved');
 IF NOT FOUND THEN RAISE EXCEPTION 'Viaje no disponible para este conductor'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.v61_assign_driver(uuid,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.v61_driver_respond(uuid,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.v61_assign_driver(uuid,uuid),public.v61_driver_respond(uuid,boolean) TO authenticated;
-- No se inicia ni se captura ningún pago. La aceptación del conductor no confirma el servicio al cliente.
