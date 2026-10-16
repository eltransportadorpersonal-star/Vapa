-- Ejecutar en SQL Editor de Supabase, después de las migraciones V55.
-- Autorización de administrador basada en public.profiles.role = 'admin'.
CREATE TABLE IF NOT EXISTS public.v60_leads (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text, email text NOT NULL, commune text, interest text NOT NULL, status text NOT NULL DEFAULT 'new' CHECK(status IN ('new','reviewing','approved','rejected')), created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.v60_service_requests (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id), service_type text NOT NULL, sector text NOT NULL, requested_at timestamptz NOT NULL, notes text NOT NULL, status text NOT NULL DEFAULT 'new' CHECK(status IN ('new','reviewing','approved','rejected','cancelled','completed')), created_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.v60_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v60_service_requests ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION public.v60_is_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='admin') $$;
REVOKE ALL ON FUNCTION public.v60_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.v60_is_admin() TO authenticated;
DROP POLICY IF EXISTS v60_leads_submit ON public.v60_leads;
CREATE POLICY v60_leads_submit ON public.v60_leads FOR INSERT TO anon,authenticated WITH CHECK(status='new');
DROP POLICY IF EXISTS v60_leads_admin ON public.v60_leads;
CREATE POLICY v60_leads_admin ON public.v60_leads FOR SELECT TO authenticated USING(public.v60_is_admin());
DROP POLICY IF EXISTS v60_services_submit ON public.v60_service_requests;
CREATE POLICY v60_services_submit ON public.v60_service_requests FOR INSERT TO authenticated WITH CHECK(user_id=auth.uid() AND status='new');
DROP POLICY IF EXISTS v60_services_read ON public.v60_service_requests;
CREATE POLICY v60_services_read ON public.v60_service_requests FOR SELECT TO authenticated USING(user_id=auth.uid() OR public.v60_is_admin());
-- Administrador: lectura de solicitudes y registros existentes.
DROP POLICY IF EXISTS v60_admin_trips ON public.v55_trip_requests;
CREATE POLICY v60_admin_trips ON public.v55_trip_requests FOR SELECT TO authenticated USING(public.v60_is_admin());
DROP POLICY IF EXISTS v60_admin_drivers ON public.v55_drivers;
CREATE POLICY v60_admin_drivers ON public.v55_drivers FOR SELECT TO authenticated USING(public.v60_is_admin());
DROP POLICY IF EXISTS v60_admin_professionals ON public.v55_professionals;
CREATE POLICY v60_admin_professionals ON public.v55_professionals FOR SELECT TO authenticated USING(public.v60_is_admin());
-- Ampliar estados sin activar pagos ni prestación de servicios.
ALTER TABLE public.v55_trip_requests DROP CONSTRAINT IF EXISTS v55_trip_requests_status_check;
ALTER TABLE public.v55_trip_requests ADD CONSTRAINT v55_trip_requests_status_check CHECK(status IN ('requested','reviewing','approved','rejected','cancelled','completed'));
CREATE OR REPLACE FUNCTION public.v60_admin_review(p_table text,p_id uuid,p_action text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NOT public.v60_is_admin() THEN RAISE EXCEPTION 'Acceso denegado'; END IF;
 IF p_action NOT IN ('reviewing','approved','rejected') THEN RAISE EXCEPTION 'Estado inválido'; END IF;
 CASE p_table
 WHEN 'v60_leads' THEN UPDATE public.v60_leads SET status=p_action WHERE id=p_id;
 WHEN 'v60_service_requests' THEN UPDATE public.v60_service_requests SET status=p_action WHERE id=p_id;
 WHEN 'v55_trip_requests' THEN UPDATE public.v55_trip_requests SET status=p_action WHERE id=p_id;
 WHEN 'v55_drivers' THEN UPDATE public.v55_drivers SET status=CASE WHEN p_action='reviewing' THEN 'pending_review' ELSE p_action END WHERE id=p_id;
 WHEN 'v55_professionals' THEN UPDATE public.v55_professionals SET status=CASE WHEN p_action='reviewing' THEN 'pending_review' ELSE p_action END WHERE id=p_id;
 ELSE RAISE EXCEPTION 'Tabla no permitida'; END CASE;
END $$;
REVOKE ALL ON FUNCTION public.v60_admin_review(text,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.v60_admin_review(text,uuid,text) TO authenticated;
