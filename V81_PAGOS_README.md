# VAPA V81: política de comisiones y preparación de split

## Decisiones aprobadas
- Cada prestador recibe 12 meses al 10% desde su fecha de registro; después 15%.
- Se busca que el procesador divida el pago automáticamente entre VAPA y prestador.
- VAPA asume el 100% de las tarifas del procesador de pagos, con cargo a su propia comisión. No se descuentan al prestador ni se agregan como recargo al cliente.
- Impuestos, reembolsos y contracargos aún requieren reglas operativas y revisión.

## Incluido en este paquete
- `vapa-commissions.js`: cálculo ilustrativo, con CLP enteros y aniversario de registro en UTC. No realiza cobros ni transferencias.
- `index.html` carga el módulo. La experiencia de pago existente permanece intacta.

## Pendiente antes de habilitar cobros split reales
1. Confirmar disponibilidad contractual/técnica de marketplace y split de Mercado Pago en Chile para VAPA y prestadores.
2. Implementar onboarding verificado de cuentas receptoras, OAuth y almacenamiento seguro de tokens solo en backend.
3. Implementar órdenes, preferencias de pago y comisiones en backend; no aceptar montos ni tasas enviados por el navegador.
4. Verificar firmas de webhooks, idempotencia, estados de cobro, conciliación y liquidaciones.
5. Implementar la contabilización de las tarifas reales del procesador como gasto de VAPA, y definir impuestos, devoluciones y contracargos, incluyendo cambios de tasa durante reservas futuras.
6. Mostrar `Mi dinero` con saldos confirmados por servidor, sin simular pagos realizados.

IMPORTANTE: no existe distribución real de dinero en esta versión. No activar pagos automáticos hasta completar las verificaciones anteriores.
