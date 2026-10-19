VAPA V33 · BACKEND SUPABASE

1. Crea un proyecto en Supabase.
2. Abre SQL Editor y ejecuta supabase_schema.sql.
3. En Authentication > Providers activa Google (o Email para pruebas).
4. En Project Settings/API copia Project URL y anon/public key.
5. Pégalos en config.js.
6. Crea tu usuario y usa la instrucción al final del SQL para marcarlo como admin.
7. Publica esta carpeta en Vercel o Netlify.

FLUJO:
Propietario -> formulario -> pending_review -> Administrador revisa ->
published / changes_requested / rejected.

SEGURIDAD:
Las reglas RLS incluidas impiden que un propietario apruebe su propia propiedad.
Solo admin puede revisar/publicar.

NOTA:
Antes de producción conviene migrar el HTML único a una app con rutas, validación server-side,
emails transaccionales y pagos. Esta V33 establece la arquitectura y permite conectar el MVP.


V34:
- Proyecto Supabase conectado mediante Project URL + Publishable Key.
- La Publishable Key es apta para frontend; la seguridad depende de las políticas RLS.
- Tu usuario administrador ya fue creado en Supabase según la configuración realizada.
- Próximo paso recomendado: probar inicio de sesión, envío de propiedad y revisión administrativa en el sitio desplegado.

V35:
- Login real con Supabase por email/contraseña y Google OAuth.
- Registro real con confirmación de correo.
- Formulario de anfitrión conectado a Supabase + Storage.
- Estado inicial de toda propiedad: pending_review.
- Panel de administrador protegido por perfil role=admin.
- Catálogo público carga automáticamente propiedades status=published.
- Dashboard del anfitrión muestra sus propiedades y estados.
- Incluye V35_MIGRACION_SUPABASE.sql para reforzar RLS y crear perfiles automáticamente.

PASOS PARA ACTIVAR V35:
1. En Supabase > SQL Editor, ejecutar V35_MIGRACION_SUPABASE.sql.
2. Confirmar que tu perfil en public.profiles tiene role='admin'.
3. Si usarás Google: Authentication > Providers > Google, activar proveedor y configurar credenciales.
4. Authentication > URL Configuration: configurar Site URL y Redirect URLs del dominio Netlify/Vercel.
5. Publicar todos los archivos de esta carpeta en Netlify o Vercel.
6. Prueba: crear un usuario distinto, postular propiedad, entrar como admin, aprobarla y revisar Propiedades.

VAPA V78 - Prueba de despliegue de la rama desarrollo-v73 en Netlify.
