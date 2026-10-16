VAPA V38 - Inscripción de Casa Mila desde la cuenta administradora

1. Publica el CONTENIDO de esta carpeta en el sitio Netlify vapa1 (no en el sitio antiguo).
2. Abre VAPA, inicia sesión como José Cabrera y entra a Tengo un lugar.
3. Desplázate hasta Mis propiedades. Si no hay propiedades, aparece «Registrar Casa Mila en Supabase» únicamente para el administrador.
4. Al pulsarlo, VAPA confirma que no exista ya Casa Mila para ese propietario, crea una única inscripción pendiente de revisión, sube la foto de muestra incluida en assets/ y registra su URL en property_photos.
5. Abre /admin/ para aprobar la propiedad. Luego, desde Mis propiedades, usa «Editar fotos y datos» para reemplazar la galería y reenviar a revisión.
6. Es indispensable haber ejecutado V37_MIGRACION_SUPABASE.sql para usar el guardado del editor V37. Si aparece un error de permisos de RLS o Storage, NO desactives RLS ni uses claves secretas en el navegador: revisa las políticas existentes.

NOTAS:
- No se crean propiedades automáticamente al cargar la página; solo al pulsar y confirmar.
- Los datos iniciales de Casa Mila son provisionales (dirección referencial, capacidad, precio). Edítalos antes de aprobar.
- La foto inicial se copia de assets/casa-mila-piscina.jpg; puedes sustituirla con fotografías originales desde el editor.
- La ficha piloto antigua sigue existiendo en otras pantallas de la interfaz; V38 evita mostrar dos tarjetas Casa Mila en el catálogo cuando existe una publicada en Supabase. La migración completa de vistas de detalle y reservas es trabajo posterior.
- La conexión se toma de config.js. No compartas claves secretas o contraseñas.
