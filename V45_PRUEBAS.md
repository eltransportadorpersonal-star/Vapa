# VAPA V45: plan de pruebas antes de producción

## Estado
Este paquete NO está conectado a una pasarela de pago ni a un servicio de correo. No se ha ejecutado SQL en Supabase ni se ha desplegado Netlify. El frontend V44 sigue siendo un prototipo.

## Requisitos para completar el circuito
1. Backend de pago (Transbank/Mercado Pago) que valide el webhook con credenciales privadas y cambie pending_payment -> pending_owner, payment_status -> paid; nunca desde JavaScript público.
2. Integrar en Mis perros un formulario móvil que suba JPEG/PNG/WEBP al bucket privado y llame a v44_save_reservation_dog. Endurecer esa RPC para comprobar existencia de objeto y pertenencia a usuario.
3. Implementar lectura segura de fotos para propietario mediante URL firmada desde backend autenticado.
4. Edge Function y cron para recordatorios (por ejemplo, 18 horas después de aprobación, si faltan fichas) con registro idempotente de envío.
5. Verificar RLS, roles, esquema real y posibles reservas previas antes de ejecutar migraciones.

## Pruebas manuales con dos cuentas (huésped y propietario)
- Sin sesión: no puede reservar ni aprobar.
- Huésped solicita: pending_payment, nunca confirmada sin pago real.
- Webhook validado: pending_owner; propietario recibe solicitud.
- Un propietario ajeno no puede aprobarla.
- Propietario acepta: confirmed, dog_info_due_at = approved_at + 24 horas.
- Huésped con 0 fichas: ingreso bloqueado.
- Huésped con foto y todos los datos por cada perro: ingreso habilitado.
- Al vencer 24h sin ficha: reserva sigue confirmed, ingreso bloqueado.
- Al completar fichas después de plazo: ingreso habilitado.
- Rechazo: rejected; política de reembolso a definir.
- Cerrar y abrir Safari móvil: estado de sesión y reservas persiste.
- Subida de imagen >5MB o tipo distinto: rechazada.
- Dos huéspedes intentan mismo horario: no se deben confirmar ambos.

## Advertencias
La migración V43 actual sólo reserva el horario durante 15 minutos. La regla de exclusión no incluye pending_owner; antes de habilitar pagos hay que resolver la concurrencia y los reembolsos. No ejecutar V45 en producción sin resolverlo.
