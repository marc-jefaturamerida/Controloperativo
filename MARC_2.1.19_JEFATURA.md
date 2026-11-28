# MARC v2.1.19 — Optimización de Jefatura

Actualización sobre el repositorio v2.1.18 entregado. No requiere migraciones SQL ni cambios de configuración en Supabase.

## Publicación

1. Respaldar la versión activa (`index.html`, `jefatura-21.js`, `sw.js`).
2. Sustituir esos tres archivos juntos en la raíz del repositorio principal (no en `talleres-piloto/`).
3. Publicar el cambio en el alojamiento habitual. Verificar que el título y las etiquetas de versión muestran v2.1.19 y que se sirve `jefatura-21.js?v=2.1.19`.
4. Cerrar y volver a abrir la PWA o recargar la página para que se active el nuevo service worker. La caché del shell pasa a `v2-1-19`. No borrar datos del sitio ni almacenamiento local, especialmente si hay capturas pendientes.
5. Validar con una cuenta administradora antes de dar por terminada la publicación.

## Cambios

- Revalidación automática con intervalo objetivo de 60 segundos, únicamente con Jefatura y el documento visibles. Al regresar rápidamente a la ventana, no se repite la consulta comercial.
- Los resultados de la misma selección permanecen visibles mientras se actualizan, con sello de última consulta y estado de error recuperable. Al cambiar realmente la selección, se retiran los resultados de la selección anterior para evitar atribuirlos a los nuevos filtros.
- El estado del módulo se conserva en memoria mientras la sesión está autorizada: filtros aplicados y borrador, pestaña, fuente, página, columnas, orden de rankings, posición de desplazamiento y paneles abiertos. Al volver de otro módulo se reconsulta el catálogo sin borrar la vista. Si una selección anterior deja de estar disponible en el catálogo se indica como tal, sin convertirla silenciosamente en una selección de todos los elementos.
- Resultados de consultas comerciales idénticas reutilizables entre pestañas internas de Jefatura por hasta 60 segundos, con un máximo de 12 entradas en memoria; actualización manual y retorno de otros módulos consultan datos frescos. No se comparte información comercial entre ventanas del navegador ni se guarda en almacenamiento persistente.
- Peticiones de consulta de Jefatura serializadas mientras el módulo está visible, con descarte de respuestas de selecciones obsoletas. Al salir del módulo no se inician más consultas periódicas; una petición ya enviada puede terminar, pero su resultado obsoleto no se aplica.
- Se evita reconstruir la vista si los datos y el catálogo no cambiaron. Tablas extensas de objetivos, rankings, supervisores y alertas se paginan a 50 filas; las fuentes con paginación del servidor conservan su funcionamiento. Se indexan catálogos y metas para acelerar búsquedas locales, sin modificar fórmulas de indicadores.
- Alertas con consulta y estado propios; fuentes independientes consultadas en paralelo; si falla una fuente se conserva la última revisión completa, cuando existe. Sin datos previos se identifica una revisión parcial.
- No se sustituye la interfaz durante ediciones, selecciones de eliminación o diálogos; las eliminaciones confirmadas solicitan una actualización explícita. El botón global Actualizar, cuando está en Jefatura, actualiza el módulo sin reiniciar la sesión.
- Se mantiene el borrado de datos de Jefatura al cerrar sesión, perder conexión, cambiar de cuenta o detectar denegación de acceso. Los mecanismos de sesión existentes se mantienen. No se cachean respuestas de API en el service worker.

## Pruebas locales realizadas

En Chromium, con RPC simuladas y datos ficticios: inicio de Jefatura; regreso rápido sin otra consulta; paginación de ranking; actualización lenta con indicadores visibles; persistencia de orden, página y borrador; error temporal; salida de módulo sin consultas; retorno al módulo; cambio de consulta durante petición pendiente; descarte de respuesta obsoleta; paginación de explorador; reutilización de consulta comercial; actualización al superar 60 s; denegación de acceso; borrado al evento offline. Sin errores JavaScript del navegador en esas pruebas. También se comprobó sintaxis de JavaScript y coherencia de versiones.

## Validación pendiente en producción

- Verificar cuenta administradora, supervisor y promotor; el acceso a Jefatura debe continuar limitado a administrador.
- Cambiar de ventana durante y después de una consulta; comprobar que los resultados no desaparecen. Mantener la ventana fuera de foco más de un minuto, regresar y comprobar actualización silenciosa.
- Aplicar filtros nuevos y cambiar de pestaña/fuente rápidamente. Comprobar fechas, indicadores y filas con los datos reales.
- Cambiar el orden y la página de un ranking, editar filtros sin aplicarlos, ocultar/mostrar el panel y salir a otro módulo. Al regresar comprobar el estado conservado.
- Probar exportaciones, favoritos, seguimiento de alertas y eliminación con registros de prueba y las reglas vigentes. Verificar que una eliminación confirmada actualiza el listado.
- Verificar que una revocación de sesión o desconexión retira los datos y que no se guardan datos de Jefatura en almacenamiento persistente.
- Comprobar instalación/actualización de PWA y funcionamiento de módulos ajenos a Jefatura.

No se accedió a Supabase de producción ni se midieron latencias reales. La prueba local valida el comportamiento del cliente, no sustituye la prueba de integración con el backend. La memoria no sobrevive a una recarga completa, cierre de pestaña, reinicio de la PWA, sesión cerrada o pérdida de autorización.
