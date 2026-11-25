# Control operativo · Integración 01 (pruebas)

## Alcance

Esta versión utiliza el proyecto Supabase ya configurado y el esquema SQL instalado. No se vuelve a ejecutar el SQL inicial. El HTML original no se modifica. Esta versión es una página de prueba separada, con el estilo base y la calculadora original incorporada. No es una sustitución funcional del sistema anterior.

- Inicio y cierre de sesión, lectura de perfil y sucursal desde Supabase.
- Administrador: creación de sucursales (RPC `crear_sucursal`), listado de usuarios y sucursales; alta de supervisores y promotores mediante Edge Function.
- Supervisor: alta de promotores de su sucursal mediante Edge Function y consultas limitadas por RLS.
- Promotor: consultas de registros propios y de su stock según RLS.
- Registros y tarjetas: consultas de solo lectura, máximo 100 filas en las tablas visibles. La cifra total de registros activos utiliza conteo de base de datos. No muestra todavía ventas, KPIs ni reportes completos.
- Calculadora original: simulación manual en un iframe aislado. No se ha probado la exportación PNG ni el portapapeles en ese aislamiento. Los ajustes generales, manual y personalización del HTML anterior aún no están incorporados.
- No hay edición/desactivación de cuentas, gestión de stock, edición de registros, carga Excel ni modo offline en esta etapa.

## 1. Verificar Auth

En Authentication, comprueba que el acceso por correo y contraseña esté habilitado y el registro público de usuarios esté desactivado (la opción puede variar de nombre). No hace falta cambiar el perfil administrador ya creado. No compartas contraseñas ni claves privadas. La clave publishable está en el HTML porque es una clave pública; la seguridad depende de RLS y RPC autorizadas.

## 2. Probar el HTML sin reemplazar el sitio actual

1. En el repositorio publicado de GitHub Pages, crea una carpeta `pruebas-supabase` dentro del directorio que realmente se publica.
2. Sube solamente el `index.html` de este paquete a esa carpeta. No subas el LEEME o el código de la función al directorio público si no lo necesitas.
3. Abre la URL habitual de GitHub Pages añadiendo `/pruebas-supabase/` al final. Se requiere internet y HTTPS; no lo pruebes desde `file://`.
4. Inicia sesión con la cuenta administradora que ya verificaste.
5. Comprueba que aparece Administrador y Acceso global. Crea una sucursal de prueba únicamente si quieres conservarla o si estás trabajando en un proyecto de pruebas. Define su código, nombre y zona horaria IANA; la sugerencia inicial es America/Mexico_City, cámbiala si no corresponde.
6. Comprueba el resultado en Table Editor > sucursales y configuracion_sucursal. No vuelvas a ejecutar el SQL inicial.

## 3. Desplegar la función de alta de usuarios

El login y las sucursales funcionan sin esta función. Para que el panel cree cuentas, despliega `supabase/functions/crear-usuario/index.ts` como Edge Function de nombre exacto `crear-usuario`.

Opción A: desde el panel de Supabase, Edge Functions, crear/desplegar una función, pegar el contenido de `index.ts` y desplegarla. Si hay una opción para verificar JWT en el gateway, conserva la verificación habilitada cuando sea compatible con los JWT del proyecto. La función también valida siempre el token contra Supabase Auth con `auth.getUser(token)` y vuelve a comprobar el perfil activo. Si el gateway rechaza tokens válidos antes de llegar al código, revisa su compatibilidad con las claves de firma del proyecto; no desactives la validación interna.

Opción B: con Supabase CLI instalado, desde la carpeta del paquete (si todavía no hay configuración local, ejecutar `supabase init`), autenticarse y vincular:

```sh
supabase login
supabase link --project-ref ocojvnotzsdczqojfysy
supabase functions deploy crear-usuario
```

La función usa `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` del entorno privado de Edge Functions. Nunca pegues la clave privada en el HTML ni en el repositorio. Para restringir CORS al origen del sitio, opcionalmente configura el secreto `CO_ALLOWED_ORIGIN` con `https://TU-USUARIO.github.io` (solo esquema y dominio, sin ruta). Mientras no se conozca la URL del sitio, permite cualquier origen CORS; siempre exige un token válido y aplica permisos del servidor.

## 4. Pruebas de roles

- Crea un supervisor de la sucursal de prueba desde el administrador. Crea un promotor de esa misma sucursal. Usa contraseñas iniciales únicas de mínimo 12 caracteres, comunícalas de manera segura. Las cuentas se confirman al crearse; no se envía correo de invitación en esta versión.
- En Authentication > Users deben existir las cuentas. En `perfiles` deben tener el rol correcto. En `promotores` debe existir la fila del promotor.
- Inicia sesión en diferentes perfiles de navegador. Un promotor no debe ver Administración ni datos de otros usuarios. Un supervisor no debe poder crear sucursales ni supervisores y solo debe ver su sucursal. Crea una segunda sucursal para probar aislamiento si es apropiado.
- Prueba correo/contraseña inválidos, usuario Auth sin perfil, cierre de sesión, y pérdida de internet. La pantalla debe quedar bloqueada si no puede verificar el acceso. Esta etapa exige conexión y no promete revocación offline.
- Verifica RLS con usuarios no privilegiados; no basta con ocultar botones. El administrador de SQL Editor tiene privilegios que no representan a un promotor.
- Si el alta falla de forma ambigua, verifica Authentication y perfiles antes de reintentar. No borres usuarios con perfiles relacionados.

## Decisiones técnicas y limitaciones

El inicio del administrador abre Administración, los otros roles abren Registros; el alta UI solo permite supervisor y promotor (no otros administradores). Se sugiere zona horaria de Ciudad de México, editable por sucursal. Se usa Supabase JS 2.49.4 desde CDN y sesión de navegador persistente; no se guardan contraseñas. Se bloquea acceso sin conexión. La URL del proyecto está configurada, pero no se dispone de sesión real para probar el servidor, ni de la URL de GitHub Pages para verificar el despliegue. Las pruebas de sintaxis y estructura locales no sustituyen pruebas de integración. No publiques esta versión como reemplazo de producción hasta terminar la migración de las funciones restantes.
