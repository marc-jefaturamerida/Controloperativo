# MARC 1.3.1 — Reasignación de supervisores

Base: ZIP de repositorio 1.2.1 recibido + actualización 1.3.0 validada por el usuario. No se modifica el importador ni se sustituye ninguna Edge Function. Si se han efectuado otros cambios posteriores no incluidos en estos archivos, comparar antes de sustituir `index.html` y `sw.js`.

## Instalación

1. Generar y verificar un respaldo protegido. Conservar copia del repositorio y de las asignaciones de supervisores vigentes. Pedir a los supervisores que sincronicen sus capturas pendientes antes de una reasignación.
2. En Supabase → SQL Editor, ejecutar `validacion_supervisores_131.sql`. Comprobar que las dependencias, `helper_revocacion` y los seis privilegios Auth sean verdaderos. Antes de instalar, `bitacora` será nulo y `rpc` vacío. El diagnóstico es de solo lectura y no expone tokens ni filas de usuarios. Si `helper_revocacion` es falso, no instalar: obtener las definiciones de `operativo_privado.marc_require_session_126()` y `operativo_privado.marc_session_valid_126()` para adaptar la migración sin debilitar la seguridad.
3. Ejecutar `202611260007_supervisor_transfer_131.sql` completo en el SQL Editor como propietario. La migración está envuelta en una transacción; no cambia ningún perfil ni revoca sesiones al instalarla. Si falla, detenerse y compartir el mensaje exacto. No omitir controles.
4. Ejecutar nuevamente `validacion_supervisores_131.sql`. Comprobar `bitacora.rls=true`, los permisos directos de tabla falsos y ambas RPC con `definer=true`, `authenticated_execute=true`, `anon_execute=false`, `service_role_execute=false`. Los roles operativos comparten el rol de base de datos `authenticated`; el permiso específico de administrador se comprueba dentro de cada función.
5. En GitHub, sustituir únicamente `index.html` y `sw.js`. Subir los tres archivos de documentación/migración/diagnóstico a la raíz si deseas mantener el historial del repositorio. Mantener los demás archivos, incluidos los dos JS del importador 1.3.0. Commit sugerido: `MARC 1.3.1 - Reasignación de supervisores y revocación de sesiones`.
6. Cuando GitHub Pages publique los cambios, abrir MARC con internet y verificar versión 1.3.1 y actualización de la PWA instalada.

## Uso

Como administrador: Administración → Usuarios visibles → localizar al supervisor → Cambiar sucursal. Seleccionar sucursal activa distinta a la actual, marcar confirmación y pulsar Confirmar cambio de sucursal. La cuenta conserva identidad, contraseña, rol y estado activo/inactivo. El supervisor debe iniciar sesión de nuevo. Se puede reasignar a supervisores inactivos sin reactivarlos; se requiere que tengan una sucursal de origen identificable. En Administración → Usuarios visibles → Bitácora de cambios de sucursal se muestran fecha, supervisor, sucursales de origen y destino, administrador y cantidad de sesiones revocadas, en páginas de 50.

## Seguridad y límites

- El servidor exige administrador activo, sesión válida y ausencia de mantenimiento/limpieza pendiente; verifica que el objetivo sea supervisor y la sucursal de destino esté activa. Rechaza vistas antiguas con sucursal de origen distinta. La operación usa un identificador idempotente en los reintentos de una misma confirmación. Si se pierde la respuesta y se cierra el formulario, consultar la bitácora y la lista antes de repetir.
- En una transacción: actualizar `perfiles.sucursal_id`, eliminar los refresh tokens y sesiones Auth del objetivo, verificar la adscripción y registrar el cambio. Una falla cancela las modificaciones. No se emiten actualizaciones de registros, tarjetas, promotores, incidencias ni otros datos operativos. Los triggers reales deben validarse en la instancia. Se usan bloqueos breves de las tablas Auth durante la revocación (espera máxima de bloqueo 5 s); otras escrituras Auth pueden esperar brevemente, pero no se revocan sesiones ajenas. Si hay conflicto de bloqueo, comprobar estado y reintentar.
- El mecanismo existente de MARC rechaza sesiones revocadas en las operaciones protegidas. La migración verifica la cadena observada en Supabase: `marc_require_session_126()` delega en `marc_session_valid_126()`, que consulta `auth.sessions` y comprueba identidad de sesión y usuario, epoch y expiración; el helper genera `MARC_SESION_NO_VIGENTE` si falla; esto no sustituye las pruebas con tokens anteriores en el servidor real. No es posible garantizar cierre instantáneo de una pantalla desconectada ni invalidación instantánea de JWT fuera de las rutas de MARC que verifican sesión. Con la PWA actualizada, la revisión periódica en línea comprueba la sesión del supervisor antes de refrescar datos; las verificaciones pueden diferirse mientras hay un formulario abierto. No se amplía la autorización offline existente.
- Capturas locales de otro módulo: se conservan como pendientes con aviso y no se envían automáticamente mientras el supervisor esté en una sucursal distinta. Las pendientes del módulo actual siguen sincronizándose. No se reasignan ni descartan capturas. Solicitar revisión administrativa si quedaron pendientes; esta versión no incorpora una recuperación asistida de esas capturas. Los dispositivos con versión anterior deben actualizarse; comprobar que el servidor también rechaza la captura de la sucursal anterior después de la reasignación.
- Bitácora independiente con RLS y sin permisos directos para clientes. No incluida en el respaldo/restauración general existente (igual que las tablas de importación 1.3.0). No se modifica la política de mantenimiento ni se agregan nuevos grupos de limpieza.
- Se permite reasignar a supervisor activo o inactivo, sin reactivarlo; se exige sucursal de destino activa y origen identificable. No se permiten promotores ni administradores como objetivo.

## Pruebas realizadas fuera de producción

- Node: sintaxis de scripts inline y service worker.
- Chromium con datos/RPC simulados: destinos activos, confirmación, rechazo de respuesta inconsistente, reintento con el mismo identificador, restricciones de interfaz, bitácora y paginación, comparación de sucursal de capturas pendientes.
- Regresión del lector 1.3.0 (sin cambios): XLS HTML original 110 códigos únicos, XLSX y CSV sintéticos.
- SQL revisado estáticamente, NO ejecutado en una instancia PostgreSQL/Supabase en este entorno. El ZIP base no contiene todos los SQL y políticas desplegados; por eso el diagnóstico y la validación real son indispensables.

## Validación recomendada con un supervisor de prueba

1. Abrir dos sesiones del supervisor en dispositivos o navegadores separados. Anotar sus permisos, registros históricos y stock de origen; verificar que no queden pendientes de prueba sin identificar.
2. Desde el administrador, reasignarlo. Confirmar en la bitácora la sucursal anterior/nueva, supervisor, administrador, fecha y número de sesiones revocadas. Verificar que otro usuario mantiene su sesión.
3. Intentar usar las sesiones anteriores (sin volver a iniciar sesión), refrescar y realizar operaciones. Deben quedar rechazadas por MARC. Comprobar también que el antiguo token de acceso no autoriza lecturas o escrituras protegidas. Si conserva acceso, no considerar liberada la versión.
4. Iniciar con la misma contraseña. Comprobar que solo tiene acceso a la nueva sucursal, que el registro y stock anteriores no cambiaron y que puede operar en destino. No utilizar datos reales para pruebas destructivas.
5. Con una cuenta de supervisor y otra de promotor, comprobar ausencia de botones y rechazo de RPC directa. Probar como administrador un destino inactivo o un objetivo promotor: deben rechazarse. Probar que no se puede confirmar mientras existe mantenimiento activo. Verificar que una sesión revocada no puede usar la RPC.
6. Simular una captura offline pendiente del supervisor antes de cambiarlo; al reconectar y reiniciar sesión debe conservarse con aviso sin enviarse a destino. Probar con otra captura de la nueva sucursal. No eliminar la cola para probar. Las capturas ya confirmadas permanecen en origen.
7. Validar importador 1.3.0, captura normal/rápida, sincronización, creación/restablecimiento de usuarios, capacitación, mantenimiento y PWA. Verificar que el respaldo anterior sigue funcionando; no interpretarlo como respaldo de las nuevas bitácoras.

No se ha realizado ninguna modificación a tu instancia de producción. La versión queda preparada para instalar y validar, no liberada automáticamente.
