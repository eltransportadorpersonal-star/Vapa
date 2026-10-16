VAPA V36: Panel independiente /admin/

Publicar toda esta carpeta en Netlify o Vercel.
La cuenta administradora debe tener role=admin en public.profiles.
Se reutiliza el mismo proyecto Supabase y las políticas RLS de V35.
Ejecutar V35_MIGRACION_SUPABASE.sql si todavía no se ejecutó.
Entrar a https://TU-DOMINIO/admin/ y probar con una cuenta administradora y otra normal.
El panel permite revisar, aprobar, rechazar y solicitar cambios.
No incluye aún reservas, finanzas ni gestión de usuarios.
