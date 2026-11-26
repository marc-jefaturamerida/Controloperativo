# MARC 1.2.0-pre.1 — mantenimiento (preliminar, NO liberar a producción)

Base: repositorio 1.1.1 recibido. Esta compilación no implementa borrado, respaldo recuperable, restauración, ni cierre global de sesiones. No ejecuta ninguna operación destructiva. Incorpora una vista administrativa de cantidades reales y un diagnóstico complementario.

## Prueba en un entorno de pruebas
1. Ejecutar `supabase/migrations/202611260003_maintenance_preview_120.sql` en SQL Editor. No volver a ejecutar migraciones previas ya instaladas.
2. Publicar `index.html` y `sw.js` del mismo paquete en un entorno de prueba (no mezclar versiones). Conservar los archivos de marca y manifiesto. Recargar en línea para actualizar la PWA.
3. Iniciar sesión con administrador activo → Administración → Mantenimiento del sistema → Consultar estado de la base. Verificar que aparecen cantidades, incluidas las tablas de tutoriales.
4. Iniciar sesión como supervisor y promotor. El apartado no debe aparecer. Desde sus sesiones, una llamada directa a `marc_maintenance_status_120` debe fallar con 42501. La vista de capacitación y el resto de la aplicación deben seguir funcionando.
5. Ejecutar por separado `supabase/diagnostics/validacion_120_previa.sql` y compartir la salida, previa revisión de secretos incrustados en definiciones de funciones (si existieran).

## Decisiones pendientes antes de añadir operaciones destructivas
- Metas semanales: conservar o limpiar.
- Inventario físico Excel: conservar o limpiar registros, filas y archivos originales. Los originales se guardan en Storage privado. El respaldo recuperable debe contemplar los archivos si se eliminan.
- Limpieza selectiva: los registros y las tarjetas tienen referencias en ambos sentidos. No se deben separar sin reglas de negocio explícitas. Se recomienda agruparlos con sus dependencias y resolver qué ocurre con inventarios físicos que referencian tarjetas.
- Sesiones y sincronización: inspeccionar funciones y políticas existentes, incluidos servicios privilegiados. Diseñar bloqueo de escrituras, generaciones de datos, invalidación de sesiones y recuperación de backups sin romper las referencias. Los dispositivos desconectados se enterarán al reconectar, no inmediatamente.

## Retirar esta prueba
Volver a publicar index.html y sw.js de 1.1.1 y recargar en línea. Para retirar únicamente la RPC preliminar: `DROP FUNCTION public.marc_maintenance_status_120();` (no borra datos operativos).

No se ha ejecutado ninguna migración contra la base del usuario. Las pruebas estáticas no sustituyen pruebas de integración, permisos ni restauración en una base aislada.
