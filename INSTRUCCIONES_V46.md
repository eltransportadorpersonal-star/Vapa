# VAPA V46: integración inicial Mercado Pago (STAGING, NO PRODUCCIÓN)

Se agregó `mp-create-checkout` para crear preferencias desde Supabase Edge Functions usando el usuario autenticado, y `mp-webhook` para validar la firma y consultar el pago directamente a Mercado Pago antes de marcarlo como pagado. El botón de reserva ahora inicia el checkout. SQL incluye exclusión de `pending_owner` y RPC restringida a service_role.

## Antes de probar
1. Crear proyecto staging Supabase con copia del esquema, sin datos personales de producción. Aplicar migraciones V43, V44, V45 y V46 en orden, inspeccionando conflictos de horarios antes de V46.
2. Configurar secretos en Supabase Edge Functions: `MP_ACCESS_TOKEN` (credencial TEST), `MP_WEBHOOK_SECRET`, `SITE_ORIGIN` (URL de staging). No incluirlos en config.js.
3. Desplegar ambas funciones. Para webhook público de Mercado Pago, deshabilitar verificación JWT **solo en mp-webhook**; la firma HMAC se valida dentro de la función.
4. Registrar la URL `https://<project-ref>.supabase.co/functions/v1/mp-webhook` como webhook de pagos en Mercado Pago y obtener el secreto de firma.
5. Publicar el frontend V46 en URL staging de Netlify; configurar SITE_ORIGIN con ese origen exacto y habilitarlo en Auth de Supabase.
6. Hacer pagos con usuarios y tarjetas de prueba de Mercado Pago. Confirmar status `pending_owner` solo tras webhook aprobado y monto coincidente.

## Bloqueadores para producción
- Política y automatización de reembolso cuando el propietario rechaza.
- Carrera de vencimiento de reserva a los 15 minutos contra pago aprobado tardío. Implementar reconciliación automática y reembolso para cobros que no puedan ocupar el horario.
- Probar la compatibilidad exacta de `sandbox_init_point` con credenciales de prueba Chile y validación de firma del webhook según configuración real.
- Completar subida móvil de fotos, recordatorios y lectura de fichas de perros. Este paquete NO implementa esas funciones pendientes.
- Auditar políticas RLS, función SQL, idempotencia, errores y estados reales antes de activar cobros.

No se ha ejecutado SQL ni desplegado a Supabase o Netlify desde esta conversación.
