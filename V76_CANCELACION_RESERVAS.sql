-- Ejecutar antes de publicar V76. Solo cancela reservas propias sin pago.
create or replace function public.v76_cancel_unpaid_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare r public.reservations%rowtype;
begin
 if auth.uid() is null then raise exception 'Inicia sesión'; end if;
 select * into r from public.reservations where id=p_reservation_id for update;
 if not found or r.user_id is distinct from auth.uid() then raise exception 'Reserva no encontrada'; end if;
 if r.status <> 'pending_payment' or coalesce(r.payment_status,'unpaid') <> 'unpaid' then raise exception 'La reserva no se puede cancelar sin revisión'; end if;
 update public.reservations set status='cancelled' where id=p_reservation_id;
end $$;
revoke all on function public.v76_cancel_unpaid_reservation(uuid) from public, anon;
grant execute on function public.v76_cancel_unpaid_reservation(uuid) to authenticated;
