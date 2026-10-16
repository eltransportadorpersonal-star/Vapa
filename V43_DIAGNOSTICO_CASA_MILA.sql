-- SOLO LECTURA: ejecutar en Supabase SQL Editor y revisar resultados.
select id,name,status,owner_id,commune,max_dogs,price_per_person,created_at
from public.properties where name ilike '%mila%' order by created_at desc;

select p.id,p.name,p.status,count(pp.id) as fotos,
 min(pp.url) as foto_ejemplo
from public.properties p left join public.property_photos pp on pp.property_id=p.id
where p.name ilike '%mila%'
group by p.id,p.name,p.status order by p.name;

-- Si Casa Mila no aparece, revisar registros recientes sin modificar nada:
select id,name,status,commune,max_dogs,created_at
from public.properties order by created_at desc limit 20;

-- Para 4 personas con un perro incluido por persona, max_dogs debe ser >=4.
-- No se cambia automáticamente: confirmar aforo real con propietario.
