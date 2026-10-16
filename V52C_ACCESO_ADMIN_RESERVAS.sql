-- VAPA V52C: acceso de lectura del administrador, sin alterar reservas ni pagos.
-- Se usa una función SECURITY DEFINER para evitar recursión de políticas de profiles.
CREATE OR REPLACE FUNCTION public.v52c_is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'admin');
$$;
REVOKE ALL ON FUNCTION public.v52c_is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.v52c_is_admin() TO authenticated;

DROP POLICY IF EXISTS v52c_admin_read_properties ON public.properties;
CREATE POLICY v52c_admin_read_properties ON public.properties FOR SELECT TO authenticated
USING (public.v52c_is_admin());

DROP POLICY IF EXISTS v52c_admin_read_reservations ON public.reservations;
CREATE POLICY v52c_admin_read_reservations ON public.reservations FOR SELECT TO authenticated
USING (public.v52c_is_admin());

DROP POLICY IF EXISTS v52c_admin_read_reservation_dogs ON public.reservation_dogs;
CREATE POLICY v52c_admin_read_reservation_dogs ON public.reservation_dogs FOR SELECT TO authenticated
USING (public.v52c_is_admin());

DROP POLICY IF EXISTS v52c_admin_read_profiles ON public.profiles;
CREATE POLICY v52c_admin_read_profiles ON public.profiles FOR SELECT TO authenticated
USING (public.v52c_is_admin());
