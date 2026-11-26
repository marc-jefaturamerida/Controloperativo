# MARC 1.3.0 — Importación masiva de stock

Base: ZIP `Controloperativo-main (2).zip` (MARC 1.2.1, commit a6f71afa7a56ea4d24cc1db44c6e3e26b9c2e3f6). Este paquete contiene únicamente archivos nuevos o modificados. No elimina archivos del repositorio ni cambia la Edge Function de usuarios.

## Instalación

1. Genera y verifica un respaldo protegido de MARC antes de cambiar la base. Comprueba que no haya mantenimiento ni eliminación de archivos pendiente. No uses el importador sobre datos reales hasta completar las pruebas.
2. En Supabase → SQL Editor → New query, pega el contenido completo de `202611260006_stock_import_130.sql` y pulsa Run. La migración se ejecuta en una transacción. Comprueba que finaliza correctamente. No ejecuta altas de tarjetas. Crea tablas privadas por RLS, RPC de catálogo, análisis, confirmación y bitácora, y un índice único global del código completo. Si hay duplicados previos o las dependencias no coinciden, falla y revierte la instalación; no borres duplicados ni adaptes firmas a ciegas. Comparte el error exacto para revisar la definición instalada.
3. En GitHub, en la raíz del repositorio, sustituye `index.html` y `sw.js`; añade `stock-import-130.js`, `stock-import-ui-130.js`, `202611260006_stock_import_130.sql`, `validacion_stock_130.sql` y este archivo de instrucciones. Puedes subirlos juntos en un único commit. No borres otros archivos. El SQL raíz es un registro de la migración: GitHub Pages no lo ejecuta automáticamente.
4. Espera a que GitHub Pages publique el commit. Abre MARC con internet y recarga. Cierra y reabre la PWA si seguía mostrando 1.2.1. La nueva caché v1-3-0 incluye los dos JS del importador. Comprueba la versión visible 1.3.0.
5. Entra como administrador → Inventario operativo de tarjetas → Importar tarjetas. Carga el archivo de ejemplo. En la primera ocasión, selecciona explícitamente `Aviacion` para `SAMS MERIDA AVIACIÓN` (comprueba que sea la sucursal real). La equivalencia se guarda al confirmar, no al leer ni analizar. No se precarga ninguna equivalencia sin aprobación en el sistema.
6. Analiza el stock general, revisa las tarjetas nuevas y las discrepancias, descarga el análisis si lo necesitas y confirma. La operación se realiza en una transacción y vuelve a comparar el resultado contra el análisis aprobado. Si cambia, vuelve a analizar. Las tarjetas existentes no se modifican. Reintenta con el mismo botón ante una respuesta de red incierta: el identificador evita repetir la importación confirmada. También puedes verificarla en la bitácora antes de iniciar otra.

## Comportamiento y restricciones

- Solo administradores activos en línea. Los controles se aplican también mediante RPC del servidor; la interfaz oculta las acciones a los demás roles.
- La columna Módulo determina la sucursal. La columna Cod Barras determina la identidad global; 21 dígitos exactos. No se usan las demás columnas para asignación.
- Archivos XLS del exportador HTML, XLSX y CSV (coma, punto y coma o tabulador). El XLS binario BIFF8 tiene lector opcional en Worker con SheetJS 0.20.3, cargado desde `https://cdn.sheetjs.com/xlsx-0.20.3/package/dist/xlsx.full.min.js` solo al elegir ese formato. No se pudo comprobar su descarga ni ejecución en este entorno sin internet. Si no carga, el archivo se rechaza con aviso; los otros archivos válidos pueden seguir. Para despliegues que no permitan dependencias externas, se recomienda alojar una copia verificada de esa librería antes de usar XLS binario. Los XLS HTML, XLSX y CSV se leen localmente sin descargar ese lector; el archivo original no se sube a Supabase.
- XLS/XLSX: celdas de código numéricas y fórmulas se rechazan (Excel solo garantiza 15 dígitos significativos). CSV y HTML: se exige texto de 21 dígitos, admitiendo las comillas simples del exportador. No es posible detectar todos los códigos ya redondeados antes de exportar a CSV/HTML.
- Límites conservadores: 10 archivos simultáneos, 10 MiB por archivo, 10 000 filas por archivo y 2 000 códigos únicos por confirmación; se recomienda dividir lotes grandes si el servidor tarda. XLSX: máximo 50 MiB descomprimido. Los límites son nuevos y no se basan en una capacidad medida del Supabase de producción.
- Se normalizan mayúsculas y espacios del módulo, conservando acentos. Las equivalencias existentes se conservan; si su sucursal queda inactiva, se bloquea el análisis hasta corregir el catálogo. No se reasignan equivalencias automáticamente. No hay interfaz de edición de equivalencias en esta versión; si se requiere, se debe implementar un flujo explícito de cambio auditado.
- Código repetido en el mismo módulo: solo cuenta una vez. Código repetido en módulos distintos: se omiten sus filas y se reporta la ambigüedad, incluso si ambos módulos apuntaran a una misma sucursal. No se elige una sucursal arbitrariamente.
- Las filas no válidas y archivos/hojas no legibles se reportan; las demás filas válidas se pueden importar. Si un módulo válido no tiene equivalencia, hay que resolverlo antes del análisis.
- El análisis previo consulta la base completa vía RPC. Los conflictos con otras sucursales no impiden importar las nuevas. El índice único y la revalidación en la transacción protegen contra altas concurrentes. Se invoca `alta_tarjetas_consecutivas` con cantidad 1 para cada código nuevo, reutilizando la lógica de stock y sus movimientos. Un fallo del servidor revierte el conjunto; los errores de lectura son los que se omiten por fila.
- La bitácora registra solicitud y resultado confirmados, actor, fecha, metadatos y cantidades. La interfaz muestra las últimas 50 y el catálogo. Los informes descargables JSON incluyen los detalles de filas omitidas y discrepancias. El detalle de errores locales no se almacena en la base, solo sus conteos. No se guardan los archivos originales.
- Las dos tablas nuevas son auxiliares y no forman parte del formato de respaldo/restauración/limpieza de MARC 1.2.1. Se conservan separadamente incluso tras una limpieza operativa. No se alteró el protocolo protegido de respaldo ni las RPC de mantenimiento existentes. Para respaldo completo, exporta las dos tablas por separado mediante SQL Editor (conserva el resultado en lugar protegido), además del respaldo operativo. La versión del manifiesto de respaldo visible se actualiza a 1.3.0; comprueba que el sello del servidor acepte la versión en la prueba de respaldo.

## Pruebas locales efectuadas

- Archivo original `filename (1).xls` leído en Chromium: 110 códigos únicos de 21 dígitos, 0 errores, módulo `SAMS MERIDA AVIACIÓN`.
- XLSX de prueba: 2 códigos de texto conservados, 2 filas de código numérico/fórmula rechazadas.
- CSV: lectura con punto y coma; notación científica rechazada; duplicado del mismo módulo omitido y conflicto de módulos reportado.
- Sintaxis de los scripts inline, los dos nuevos JS y el service worker validada con Node.js.
- No se ejecutó SQL en Supabase, no se comprobó el lector binario externo, ni se realizó una prueba integral contra la base real. La definición completa de las RPC de stock y mantenimiento no venía en el ZIP. La migración comprueba las firmas requeridas; el comportamiento de las guardas y los movimientos debe verificarse en producción o preferentemente en un proyecto de prueba.

## Validación de liberación (preferiblemente con base de pruebas)

Marca cada punto Correcto / Incorrecto / No probado. Para probar altas, usa tarjetas autorizadas; no inventes tarjetas en el inventario real.

- Instalación: SQL termina correctamente y se muestra 1.3.0 en web/PWA.
- Permisos: administrador puede abrir importador y consultar bitácora; supervisor y promotor no ven los botones ni pueden invocar las RPC (incluida la confirmación directa).
- Archivo original: se leen 110 tarjetas y un único módulo; no hay escrituras antes de confirmar.
- Equivalencias: se puede elegir Aviacion, se conserva al recargar y no se asigna por supervisor/ciudad/producto.
- Confirmación: el conteo de nuevas coincide con altas reales; disponibles y sin asignar; movimientos de alta visibles.
- Existentes: se conservan estado, sucursal, asignación, consumo e historial. Incluye una discrepancia de sucursal y una tarjeta consumida.
- Reimportación: 0 tarjetas nuevas y no hay movimientos de alta adicionales. No se duplican códigos.
- Multiples archivos: repetidos del mismo módulo omitidos, módulo contradictorio reportado. XLSX/CSV/XLS binario probados con códigos de texto exactos.
- Filas incorrectas: se reportan y se importan las válidas; Excel numérico o fórmula se rechaza.
- Concurrencia: si cambia una tarjeta tras el análisis, la confirmación exige nuevo análisis. Si falla una alta del servidor, se revierte toda la importación.
- Seguridad: mantenimiento activo y limpieza pendiente impiden confirmar. Sesión revocada y generación anterior rechazadas por el servidor. Comprueba también una importación sin altas durante mantenimiento.
- Bitácora: identificador, fecha, actor, resultado y descargas correctos.
- Regresión: alta manual/consecutiva, asignación, transferencia, inventario físico, captura normal/rápida/offline, creación y restablecimiento de usuarios, tutoriales, respaldo protegido y verificación del sello.

## Reversión

Si la aplicación falla, vuelve al `index.html` y `sw.js` originales mediante GitHub; recarga la PWA con conexión. Las nuevas tablas/RPC pueden permanecer inactivas hasta resolver el error. La reversión del código NO elimina las tarjetas previamente importadas ni modifica su historial. No se proporciona un script de borrado automático.

Respaldo auxiliar manual (SQL Editor, solo lectura):

```sql
SELECT * FROM public.marc_stock_modules_130 ORDER BY modulo;
SELECT * FROM public.marc_stock_imports_130 ORDER BY fecha;
```
