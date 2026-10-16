VAPA V43 - PREPARACION TECNICA, NO LISTA PARA PRODUCCION

CAMBIOS REALIZADOS SOBRE V42:
- Agenda por bloques de 90 minutos, 10:00 a 19:00.
- Tarifas Casa Mila por persona: $18.000 sin piscina / $24.000 con piscina.
- Cada persona incluye un perro; extras pequeños $2.000 y grandes $3.000 por bloque.
- Descuentos por grupo 2/3/4 personas: 10/15/20%; por 2/3 bloques: 10/15%.
- Advertencia de retiro 5 minutos antes y exclusividad de grupo conocido.
- RPC SQL para registrar reserva pendiente de pago con bloqueo de superposiciones.
- Nombre visible VAPA.

PENDIENTE Y BLOQUEANTE ANTES DE PUBLICAR:
1. Ejecutar V43_MIGRACION_RESERVAS.sql en Supabase de pruebas y validar políticas/RLS.
2. Integrar Webpay con backend seguro y credenciales de comercio. No existe pago real en esta preparación.
3. Implementar paneles de huésped/agente, editor mejorado de fotografías y navegación móvil.
4. Recuperar/verificar Casa Mila publicada y fotos reales; probar con usuarios de prueba.
5. Probar flujos móviles y pagos en sandbox antes de desplegar.

NOTAS: El SQL asume 6 bloques diarios de 10:00 a 19:00 en horario America/Santiago.
Las reservas pendientes se liberan al expirar cuando se ejecuta una nueva reserva.
El límite de perros también depende de max_dogs registrado en cada propiedad.
No se ha aplicado ningún cambio a la base de datos ni a Netlify.
