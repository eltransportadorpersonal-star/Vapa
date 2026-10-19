# VAPA V74 | Solicitud de viajes y pagos (STAGING)

## Implementado en esta entrega
- Cotización verificada A/B/C -> formulario de solicitud con ruta, distancia, tiempo y tarifa visible.
- El formulario exige una cotización válida y guarda la solicitud en `v55_trip_requests` con estado `requested`.
- Reutiliza la asignación administrativa y aceptación de conductores de V61; no altera el checkout de propiedades.
- No inicia cobros ni declara viajes pagados.

## Requerido para producción
1. Guardar coordenadas, distancia, tiempo y tarifa en el servidor. Recalcular el precio en un endpoint autenticado; **nunca confiar en el monto enviado desde el navegador**. Asociar un `quote_id` inmutable con caducidad.
2. Conectar a los conductores aprobados mediante OAuth de Mercado Pago y comprobar habilitación Split 1:1 para Chile y la aplicación de transporte.
3. Flujo: cotización -> solicitud -> conductor asignado y acepta -> contacto seguro conductor/pasajero -> confirmación de punto de encuentro y destino -> checkout Mercado Pago -> webhook verificado -> viaje confirmado. Si se exige pago previo a asignación, establecer reglas de devolución, caducidad y reserva del dinero con el proveedor antes de implementarlo.
4. Split: 90% conductor, 10% VAPA, antes de costos de procesamiento; calcular `marketplace_fee` en el servidor según las reglas oficiales, no desde el cliente. Verificar si el conductor debe soportar tarifas del procesador y cuándo se liberan los fondos. No prometer retiros instantáneos.
5. Agregar estados de pago separados del estado operativo; webhooks firmados, idempotencia, cancelaciones, reembolsos, disputas, expiración, trazabilidad y auditoría.
6. Validar documentos de conductores, capacidad de transporte de mascotas, privacidad del teléfono y consentimiento para contacto. El conductor debe poder llamar al pasajero tras aceptar la asignación, con datos visibles solo a las partes autorizadas.
7. Ejecutar pruebas con cuentas de prueba y verificar flujos completos antes de habilitar cobros reales.

**No desplegar como funcionalidad de pagos terminada.**
