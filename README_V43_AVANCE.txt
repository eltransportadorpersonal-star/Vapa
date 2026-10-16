VAPA V43 - AVANCE LOCAL NO PUBLICAR

CAMBIOS SOBRE V43 PREPARACION:
- Consulta de disponibilidad desde el calendario mediante RPC con datos privados protegidos.
- Listado de mis reservas desde la ficha, consultado con sesión y RLS.
- Indicador de horario ocupado y bloqueo de intento de reserva cuando la consulta confirma ocupación.
- Precio de portada de Casa Mila alineado con las nuevas tarifas (sin piscina/con piscina).
- Script de diagnóstico de Casa Mila (solo lectura, sin duplicar ni cambiar estados).
- SQL de disponibilidad añadida a migración de reservas.

BLOQUEANTES:
- Migración SQL no ejecutada ni probada en la instancia Supabase real.
- Casa Mila: verificar estado published, fotografías, max_dogs y propietario mediante script diagnóstico.
- Webpay no conectado: ninguna reserva se marca pagada o confirmada.
- Editor de fotos y panel de agentes aún no implementados.
- Revisión móvil visual real y pruebas de flujo de extremo a extremo pendientes.

ATENCION: El SQL de migración requiere respaldo, verificación de reservas previas,
y revisión de políticas RLS antes de aplicarlo. Nunca pegar credenciales privadas
ni service_role en HTML público o en el chat.
