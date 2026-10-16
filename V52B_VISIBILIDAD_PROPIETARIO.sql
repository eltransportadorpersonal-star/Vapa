-- Ejecutar después de V52_APROBACION_RESERVAS.sql. No modifica pagos ni estados.
-- Lectura limitada a propietarios de la propiedad y administradores.
DROP POLICY IF EXISTS v52b_owner_read_reservation_dogs ON public.reservation_dogs;
CREATE POLICY v52b_owner_read_reservation_dogs ON public.reservation_dogs FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.reservations r JOIN public.properties p ON p.id=r.property_id WHERE r.id=reservation_id AND p.owner_id=auth.uid()));
-- Permite mostrar el nombre del titular SOLO a propietarios con reservas de ese usuario.
DROP POLICY IF EXISTS v52b_owner_read_guest_profile ON public.profiles;
CREATE POLICY v52b_owner_read_guest_profile ON public.profiles FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.reservations r JOIN public.properties p ON p.id=r.property_id WHERE r.user_id=profiles.id AND p.owner_id=auth.uid()));
