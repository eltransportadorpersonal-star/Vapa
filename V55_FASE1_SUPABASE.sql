-- VAPA V55 Fase 1: mapa por coordenadas aproximadas, inscripciones y solicitudes piloto.
-- No habilita cobros ni liquida comisiones.
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS map_lat double precision;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS map_lng double precision;
ALTER TABLE public.properties ADD COLUMN IF NOT EXISTS has_pool boolean NOT NULL DEFAULT false;
-- No insertar coordenadas de domicilios privados. Usar puntos aproximados autorizados.
CREATE TABLE IF NOT EXISTS public.v55_drivers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id),
 sector text NOT NULL, vehicle_type text NOT NULL, dog_capacity integer NOT NULL CHECK(dog_capacity BETWEEN 1 AND 20),
 notes text NOT NULL, status text NOT NULL DEFAULT 'pending_review' CHECK(status IN ('pending_review','approved','rejected','suspended')),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.v55_professionals (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id),
 service_type text NOT NULL CHECK(service_type IN ('walker','trainer','veterinarian','groomer','sitter','other')),
 display_name text NOT NULL, sector text NOT NULL, base_price integer NOT NULL CHECK(base_price>=0),
 description text NOT NULL, status text NOT NULL DEFAULT 'pending_review' CHECK(status IN ('pending_review','approved','rejected','suspended')),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.v55_trip_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id),
 dog_id uuid NOT NULL REFERENCES public.dogs(id), origin_sector text NOT NULL, destination_sector text NOT NULL,
 requested_at timestamptz NOT NULL, notes text, status text NOT NULL DEFAULT 'requested' CHECK(status IN ('requested','reviewing','cancelled','completed')),
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.v55_drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v55_professionals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.v55_trip_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS v55_drivers_insert ON public.v55_drivers;
CREATE POLICY v55_drivers_insert ON public.v55_drivers FOR INSERT TO authenticated WITH CHECK (user_id=auth.uid() AND status='pending_review');
DROP POLICY IF EXISTS v55_drivers_own ON public.v55_drivers;
CREATE POLICY v55_drivers_own ON public.v55_drivers FOR SELECT TO authenticated USING (user_id=auth.uid());
DROP POLICY IF EXISTS v55_professionals_insert ON public.v55_professionals;
CREATE POLICY v55_professionals_insert ON public.v55_professionals FOR INSERT TO authenticated WITH CHECK (user_id=auth.uid() AND status='pending_review');
DROP POLICY IF EXISTS v55_professionals_read ON public.v55_professionals;
CREATE POLICY v55_professionals_read ON public.v55_professionals FOR SELECT TO authenticated USING (user_id=auth.uid() OR status='approved');
DROP POLICY IF EXISTS v55_professionals_public ON public.v55_professionals;
CREATE POLICY v55_professionals_public ON public.v55_professionals FOR SELECT TO anon USING (status='approved');
DROP POLICY IF EXISTS v55_trip_insert ON public.v55_trip_requests;
CREATE POLICY v55_trip_insert ON public.v55_trip_requests FOR INSERT TO authenticated WITH CHECK (user_id=auth.uid() AND status='requested' AND EXISTS (SELECT 1 FROM public.dogs d WHERE d.id=dog_id AND d.owner_id=auth.uid()));
DROP POLICY IF EXISTS v55_trip_own ON public.v55_trip_requests;
CREATE POLICY v55_trip_own ON public.v55_trip_requests FOR SELECT TO authenticated USING (user_id=auth.uid());
-- Administradores gestionan revisiones desde el panel seguro de Supabase hasta integrar moderación VAPA.
-- No se crean permisos UPDATE/DELETE desde el navegador para proteger el estado de las solicitudes.
