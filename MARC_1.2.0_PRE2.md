# MARC 1.2.0-pre.2 — Validación de respaldo y mantenimiento

**No es una versión de producción. No ejecuta borrados ni restauraciones.** Basada en 1.1.1 y pre.1. No modifica las funcionalidades operativas existentes ni las credenciales.

## Instalación en entorno de pruebas
1. Conserva una copia de la versión 1.1.1 y un respaldo externo de la base.
2. Ejecuta `202611260003_maintenance_preview_120.sql` y después `202611260004_maintenance_backup_120.sql` en el SQL Editor de Supabase. Ambos son idempotentes. Alternativamente usa el SQL combinado entregado por separado. No ejecutan DML sobre tablas de negocio.
3. Publica los archivos del repositorio en una rama/sitio de prueba. Conserva el archivo `supabase/functions/crear-usuario/index.ts` sin cambios. No hace falta desplegar otra Edge Function en esta fase.
4. Abre MARC en línea y verifica la versión 1.2.0-pre.2. El service worker usa una caché nueva. Entra como administrador.

## Pruebas
- Administración → Mantenimiento del sistema → Estado de la base: verificar cantidades (no se alteran los datos).
- Generar respaldo: descarga ZIP. Verificar que el ZIP existe y seleccionar el mismo archivo en Verificar respaldo. Debe indicar integridad verificada y mostrar 11 tablas operativas y los Excel.
- El ZIP incluye `datos.json`, `manifest.json` y los originales en `excel/NNNNNN.bin` (nombre seguro; `path` en el manifiesto identifica la ruta original y su extensión). Los binarios son los archivos originales, sin transformación. El respaldo no incluye contraseñas, tokens, sesiones, metas, perfiles ni configuración como tablas independientes; el historial operativo sí puede contener valores históricos de configuración/perfiles. Almacénalo en un sitio seguro. No publicar ni enviar el ZIP a terceros.
- Limpieza selectiva: probar solo registros, solo stock, solo inventarios, solo tutoriales y todos los grupos. Las selecciones incompatibles deben mostrar el motivo y número de referencias. La compatibilidad es una evaluación de las FK conocidas, no una autorización de ejecución.
- Restablecimiento general: muestra simulación, nunca ejecuta el borrado.
- Supervisor y promotor: no deben ver el apartado. Si se prueba el RPC directamente con sus JWT, debe denegar el acceso (42501). El RPC no acepta identidad indicada por el cliente.
- Comprobar que registro normal/rápido, stock, sincronización, tutorial y login siguen funcionando.

## Límites
El respaldo se genera con una instantánea SQL y una segunda comprobación posterior de datos/metadatos; no congela escrituras ni garantiza consistencia transaccional con Storage. Límite cliente 50 MiB sin comprimir; la API puede imponer límites inferiores. SHA-256 detecta alteraciones accidentales, no firma ni autentica el archivo. No es un respaldo de desastre de la base completa. El formato está sujeto a validación posterior para restauración. No usarlo como autorización para borrar información.

Pendiente de implementar y probar: habilitación temporal en servidor, bloqueo de escrituras, generación offline, revocación efectiva de sesiones, restablecimiento/limpieza transaccional, API de eliminación de Storage con recuperación de fallos, restauración y auditoría independiente. No se ha desplegado esta compilación ni probado contra Supabase real.

## Validación local realizada
- Sintaxis de todos los scripts JavaScript y del service worker con Node.
- Prueba de verificador de ZIP con datos sintéticos: aceptación de respaldo válido y rechazo de hash alterado, entrada extra y proyecto diferente.
- Integridad del ZIP de distribución.
- SQL revisado estáticamente; sin instancia PostgreSQL/Supabase en el entorno de trabajo para ejecutarlo.
