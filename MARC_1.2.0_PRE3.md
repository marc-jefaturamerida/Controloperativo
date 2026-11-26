# MARC 1.2.0-pre.3 — Corrección de respaldo y grupos

Compilación de pruebas basada en pre.2. No ejecuta limpiezas, restauraciones ni cierres globales de sesión. No contiene cambios en las tablas de negocio.

## Instalación
1. Si pre.2 ya está instalada, ejecuta `supabase/migrations/202611260005_maintenance_groups_123.sql` en Supabase SQL Editor. El SQL combinado entregado por separado también es válido (reinstala funciones de pre.1/pre.2 y añade pre.3).
2. Sustituye `index.html` y `sw.js` del sitio de pruebas de GitHub. El ZIP contiene el repositorio completo. Conserva la copia anterior. No es necesario cambiar la Edge Function.
3. Abre en línea, recarga y comprueba que se vea 1.2.0-pre.3. La caché de la PWA cambia.

## Correcciones
- Los respaldos nuevos usan manifiesto `marc-backup-v2` y nombres `excel/000001_Nombre original.xlsx` o `.xlsm` (prefijo único; caracteres incompatibles con nombres seguros se sustituyen). Se conservan los bytes originales, la ruta del objeto, tamaño y SHA-256. El verificador admite también los ZIP anteriores `marc-backup-v1` con `.bin`. Si un objeto no tiene inventario, se usa el nombre y extensión de su ruta; una extensión desconocida bloquea la generación.
- El RPC nuevo `marc_maintenance_plan_123` calcula los grupos adicionales necesarios de forma transitiva a partir de las referencias existentes. Las casillas permanecen independientes. No se marcan grupos adicionales hasta que el administrador pulsa el botón correspondiente. La selección rápida de operación vinculada marca registros, stock, inventarios y sincronización (no historial ni tutoriales). Es una selección explícita, no una eliminación. Cada cambio invalida el resultado previo y requiere nueva validación. Los tutoriales solos no tienen dependencias en este modelo. Los inventarios, historial y sincronización tienen opciones independientes. La simulación valida las FK conocidas, no garantiza seguridad de una futura eliminación (por ejemplo, aún falta resolver la repetición de operaciones sincronizadas).
- La versión nueva del RPC permite detectar una instalación SQL anterior en vez de interpretar su respuesta como válida.

## Pruebas de aceptación en el sitio de pruebas
- Generar ZIP y abrir los 3 Excel (si el conteo no cambió); confirmar extensiones, nombres, contenido y verificación del ZIP.
- Seleccionar solo tutoriales; debe ser compatible y mostrar los intentos y solicitudes.
- Seleccionar solo registros y solo stock: si hay referencias, debe indicar qué grupos faltan. Pulsar «Agregar grupos requeridos y verificar» debe volver a verificar con los grupos necesarios, sin borrar nada.
- Seleccionar solo inventarios, historial y sincronización por separado: deben ser compatibles según las FK verificadas. No ejecutar borrados.
- Selección rápida de operación vinculada: debe resultar compatible, dejando tutoriales e historial sin seleccionar.
- Cambiar una casilla tras verificar: el resultado previo desaparece. Verificar de nuevo.
- Simulación general, acceso por roles y funciones operativas de pre.2 deben mantenerse.

## Verificaciones locales y límites
Sintaxis de todos los scripts y service worker con Node; pruebas sintéticas del verificador ZIP para ambos formatos y rechazo de alteración, archivo adicional y proyecto distinto; pruebas de interfaz con DOM y RPC simulados. SQL revisado estáticamente; no ejecutado en Supabase real. No se probaron los archivos Excel reales. El respaldo aún no bloquea escrituras; no es una autorización para eliminar datos. Restauración, protección offline, revocación de sesiones, borrado de Storage y eliminación definitiva siguen pendientes.
