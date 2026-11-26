# MARC 1.3.1 — Administración integral de usuarios y sucursales

**Estado: paquete de implementación preparado, pendiente de ejecución y validación en Supabase. No es una liberación validada.**

Base utilizada: paquete 1.3.1 corregido (reasignación instalada) y diagnóstico integral de PostgreSQL 17.12 entregado por el administrador. El diagnóstico contiene las definiciones de las funciones existentes, no datos de clientes. No se necesita repetir la migración 1.3.1 anterior ni la de stock 1.3.0.

## Fase única: instalación y validación

1. Coordina una ventana sin operaciones. Solicita a los usuarios que sincronicen capturas pendientes. Genera y verifica el respaldo protegido actual desde MARC. Ten también disponible un mecanismo de recuperación de base de datos de Supabase: el respaldo operativo existente no guarda credenciales, cuentas Auth ni todo el esquema.
2. **Preferentemente utiliza una copia de prueba de la base antes de aplicar a producción**, en particular por el cambio de correo en Auth y el motor de restauración. Esta comprobación pertenece a la misma fase de liberación, no requiere otra versión.
3. En Supabase SQL Editor, ejecuta íntegramente `202611260008_admin_integral_131.sql`, una sola vez. Es una transacción. Incluye un bloqueo de mantenimiento, precondiciones, validación de privilegios Auth y huellas SHA-256 de las funciones que modifica, calculadas del diagnóstico real. Si una definición cambió o falta un permiso, cancela la instalación. Si aparece cualquier error, NO subas los archivos de interfaz y comparte el mensaje exacto. Si el editor conserva una transacción abortada, ejecuta ROLLBACK antes de volver a consultar.
4. Ejecuta `validacion_integral_131.sql`. Debe mostrar `estructura_correcta: true`; comprueba los resultados individuales. Es un diagnóstico de estructura, no prueba que el cambio de correo, sesiones ni restauración funcionen.
5. En GitHub, sustituye únicamente `index.html` y `sw.js` en la raíz. Opcionalmente conserva el SQL, diagnóstico y este documento como historial del repositorio. No borres `stock-import-130.js`, `stock-import-ui-130.js`, iconos, manifest ni otras funciones. No es necesario desplegar una Edge Function nueva. Commit sugerido: `MARC 1.3.1 - Administración integral de usuarios y sucursales`.
6. Abre la PWA con conexión; comprueba `Versión 1.3.1` y el botón **Editar usuario** en Administración. Se cambia la clave del caché PWA a `v1-3-1-integral-marc`, incluso si ya había una instalación 1.3.1.
7. Ejecuta las pruebas de la sección siguiente antes de liberar. Usa cuentas y sucursales de prueba y evita eliminar una sucursal en uso. Genera un nuevo respaldo protegido con las 17 tablas y verifica su integridad. No hagas un restablecimiento general de producción solo para probar.

## Funciones y reglas

- Administrador: editar nombre, correo de acceso, rol, sucursal y estado; editar nombre, código, zona horaria y estado de sucursales; eliminar lógicamente promotores, supervisores y sucursales; recuperar desde Papelera sin activar.
- La cuenta del propio administrador protege correo, rol y estado. Los administradores no se eliminan en el editor. Otros administradores pueden editarse; la política anterior de restablecimiento de contraseñas se conserva (no concede nuevo permiso para restablecer administradores). El editor no almacena contraseñas.
- Los supervisores conservan sus permisos anteriores de creación de promotores y restablecimiento de contraseña de promotores autorizados; no pueden editar perfiles mediante las antiguas RPC. Las antiguas RPC `gestionar_perfil` y `marc_transfer_supervisor_131` quedan sin acceso desde el cliente; el nuevo editor sustituye ambas vías. Se conserva la bitácora antigua y se muestra en la bitácora unificada.
- Cambio de rol o sucursal de promotor: bloquear con tarjetas asignadas. Si cambia la adscripción o deja el rol, se conserva su fila operativa histórica en su sucursal original, inactiva y desvinculada de la cuenta, con sus ID, metas, registros, tarjetas consumidas y movimientos; si pasa a promotor en otra adscripción se crea una nueva fila operativa vinculada al mismo perfil. Por ello los reportes históricos y los futuros pueden mostrar dos filas de promotor con el mismo nombre. Es una decisión técnica para evitar trasladar ventas y metas antiguas.
- La eliminación de usuario es lógica: desactivar, marcar en papelera y revocar sesiones; la cuenta Auth no se borra. No puede acceder a MARC mientras esté inactiva. La autenticación de Supabase por sí sola puede seguir emitiendo una sesión, pero las reglas operativas de MARC la rechazan; no se modifican prohibiciones Auth preexistentes.
- Cambio de correo: limitado a cuenta de correo local, confirmada, no SSO/anónima, con una sola identidad `email` consistente. Se valida duplicidad sin distinguir mayúsculas; se actualizan `auth.users`, la identidad de correo y los tokens de cambio/recuperación pendientes en la misma transacción, sin alterar contraseña ni UUID. Es una modificación directa del esquema Auth, dependiente de la versión de Supabase; probar inicio de sesión y recuperación de contraseña antes de usar en producción. Si `auth.one_time_tokens` no está disponible o falta permiso, la migración no se instala. Verifica que el titular controle el nuevo correo antes de confirmar; la opción aprobada no pide confirmación por correo.
- Cambios de rol, sucursal, estado o correo revocan las sesiones del usuario afectado; nombre sin cambios de permisos no revoca. La activación también revoca para exigir inicio de sesión nuevo. Los dispositivos desconectados no reciben la revocación hasta reconectarse; se conservan las capturas de un ámbito anterior sin enviarlas automáticamente. La comprobación por fecha usa el reloj del dispositivo, por lo que debe ser correcto. Las capturas antiguas pendientes (incluidas las que pudieron llegar a servidor antes de perderse la respuesta) requieren revisión manual; no se sobrescriben ni reenvían a otra sucursal.
- Eliminar sucursal: bloquear con perfiles/promotores activos, stock disponible o asignado, o inventarios abiertos. Desactivar también exige resolver usuarios/promotores activos; se conserva stock y puede reactivarse si es necesario para resolverlo. El stock bloqueado y consumido no se borra. Se conserva el nombre e ID de sucursal en referencias y bitácoras; el nombre actual aparecerá en reportes que consultan el catálogo, no se reescribe cada registro histórico. Equivalencias quedan inhabilitadas mientras su destino no esté activo; desde Equivalencias se puede cambiar explícitamente el destino de futuras importaciones sin mover tarjetas existentes. La recuperación no reactiva la sucursal ni los usuarios.
- El administrador puede leer Excel históricos de sucursales inactivas para permitir el respaldo protegido, sin habilitar cargas nuevas. La vista `metas_efectivas` queda con `security_invoker=true` para respetar los permisos del usuario. Se agregan bloqueos al inicio de RPC que crean o cambian operaciones, además de las protecciones de escritura existentes.

## Respaldo y restauración

Se conservan formato, manifiesto, sello de servidor, límites, verificación de archivos y política de recuperación de filas faltantes sin sobrescribir datos existentes. Al respaldo anterior de 11 tablas se añaden:

- `marc_stock_modules_130` — equivalencias de módulos.
- `marc_stock_imports_130` — bitácora de importaciones.
- `marc_supervisor_transfers_131` — historial de reasignaciones anteriores.
- `marc_admin_changes_131` — historial administrativo integral.
- `marc_admin_archived_users_131` — papelera de usuarios.
- `marc_admin_archived_branches_131` — papelera de sucursales.

El nuevo respaldo contiene 17 tablas. La verificación local y el motor de recuperación aceptan el conjunto antiguo exacto de 11 o el conjunto nuevo exacto de 17. Los respaldos anteriores no contienen los seis conjuntos añadidos; no los pueden recuperar y no los borran. Para una nueva limpieza general, utiliza un respaldo nuevo de 17 tablas. La bitácora administrativa y papelera no forman parte de los grupos de eliminación del restablecimiento general existente, por lo que se preservan. No se restaura un estado de papelera que contradiga perfiles/sucursales activos o dependencias operativas actuales.

**Límite deliberado:** el motor de restauración no reconstruye usuarios de Auth, contraseñas, sesiones, perfiles ni sucursales físicamente ausentes y no sobrescribe registros maestros existentes. Restaura marcas de papelera y bitácoras solo cuando las entidades correspondientes existen y su estado es compatible. Para recuperar toda una instancia o cambiar datos maestros desde un respaldo anterior se requiere un respaldo de base de datos, no solo el ZIP operativo de MARC. Un respaldo de prueba debe ser generado, sellado, verificado y restaurado (si es necesario, en una copia de prueba) con la propia instancia; la verificación local de ZIP no equivale a comprobar el sello de servidor.

## Validación definitiva (una sola fase)

| Control | Resultado esperado |
|---|---|
| SQL y diagnóstico | La transacción completa termina sin error y `estructura_correcta: true`. |
| PWA | Carga el nuevo editor y se actualiza el caché. |
| Permisos | Administrador edita usuarios/sucursales; supervisor/promotor no pueden ejecutar las nuevas RPC ni las antiguas de edición. Creación/restablecimiento autorizados siguen funcionando. |
| Propia cuenta | Correo, rol, estado no modificables; nombre editable. No hay eliminación de administradores. |
| Cambio de rol | Promotor, supervisor, administrador pueden cambiar de puesto según reglas. Nueva sesión muestra permisos correctos; otro administrador permanece activo. |
| Traslado de promotor | Con tarjeta asignada, bloquear. Sin asignadas, su historial y metas antiguas permanecen en la sucursal original. |
| Traslado de supervisor | Revocación en dos dispositivos; nueva sucursal y contraseña habitual. |
| Cambio de correo | Bloquear duplicado, conservar UUID y contraseña, nuevo correo inicia sesión y el viejo no. Probar además recuperación de contraseña con cuenta de prueba. |
| Sesiones | Solo se revocan las del afectado; sesiones revocadas no leen ni escriben. |
| Offline | Capturas de un ámbito anterior se conservan sin sincronizar automáticamente; otras cuentas siguen sincronizando. |
| Eliminar usuario | Bloquear si tiene tarjetas asignadas; exigir nombre exacto; conservar historial, impedir acceso; papelera y recuperación inactiva. |
| Eliminar sucursal | Bloquear cada dependencia activa; exigir nombre exacto; conservar referencias y archivos; recuperación inactiva. |
| Sucursales y equivalencias | Nombre, código, zona y estado editables; zona inválida bloqueada; destino inactivo impide importar; corregir equivalencia sin mover tarjetas existentes. |
| Bitácora | Actor, fecha, valores previos/nuevos y sesiones revocadas; conserva bitácora anterior. |
| Mantenimiento | Bloquea cambios administrativos e importaciones; no hay rutas antiguas para evadirlo. |
| Respaldo | 17 tablas, sello válido, incluye las seis nuevas; archivos históricos descargables. El respaldo antiguo de 11 puede verificarse. |
| Restauración | Ensayo y recuperación de filas faltantes compatibles en entorno de prueba; rechaza sobrescrituras, inconsistencias de papelera y alteración del sello. |
| Regresión | Captura normal/rápida, WhatsApp, stock e importador, inventarios, metas, capacitación y respaldos continúan funcionando. |

## Pruebas hechas durante la preparación

- Se contrastaron definiciones y restricciones del diagnóstico integral (577 entradas de metadatos).
- Node.js: sintaxis de cuatro scripts embebidos en `index.html` y de `sw.js` correcta.
- Chromium aislado, sin conexión al proyecto real: comprobación con catálogo y RPC simulados de edición de usuario, confirmación de eliminación, papelera, recuperación, edición de sucursal, equivalencia, autoedición protegida, conjuntos de respaldo de 11/17 tablas y protección de cola anterior. Cinco solicitudes simuladas confirmadas; sin excepciones JavaScript en esa prueba.
- No se dispone de un servidor PostgreSQL local ni acceso directo a tu Supabase. No se ha compilado/ejecutado la migración SQL ni probado Auth o recuperación real. Las comprobaciones anteriores no justifican liberar sin realizar la validación funcional.
