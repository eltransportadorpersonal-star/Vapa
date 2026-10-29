# VAPA V82 | Mi dinero (primera etapa)

## Implementado
- Acceso desde Propietarios > Mi dinero.
- Interfaz responsive: Disponible, Por recibir, Recibido este mes e historial.
- Consulta real a Supabase con sesión autenticada y política RLS por prestador.
- Sin datos ficticios: si no existe la tabla, se informa que falta configurar.
- SQL opcional `V82_LIQUIDACIONES_SQL.sql` para crear el registro con permisos de solo lectura para prestadores.

## Límites importantes
- No se ha conectado Mercado Pago Split, no se han creado pagos ni se han transferido fondos.
- El SQL crea una tabla vacía. Solo un backend de confianza podrá registrar movimientos tras verificar pagos.
- Los totales mostrados cubren únicamente los últimos 100 movimientos; para producción se necesita una vista agregada en servidor y conciliación contable.
- La fecha de registro del prestador debe definirse de forma inmutable y verificada en servidor para aplicar 10% por 12 meses y 15% después.
- VAPA asume la tarifa del procesador con cargo a su comisión. El costo real debe reconciliarse desde el procesador.
- Mantener el checkout actual sin cambios hasta confirmar soporte de split en Chile y completar onboarding, webhooks y conciliación.
