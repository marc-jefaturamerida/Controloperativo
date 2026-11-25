import { createClient } from 'npm:@supabase/supabase-js@2.49.4';

// This endpoint accepts bearer tokens, not browser cookies. Restrict Origin to your
// actual GitHub Pages origin when known by setting CO_ALLOWED_ORIGIN.
const origin = Deno.env.get('CO_ALLOWED_ORIGIN') || '*';
const cors = {
  'Access-Control-Allow-Origin': origin,
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Vary': 'Origin',
  'Cache-Control': 'no-store',
};
const respond = (status: number, body: object) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, 'Content-Type': 'application/json' },
});
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (req.method !== 'POST') return respond(405, { error: 'Método no permitido.' });
  const token = req.headers.get('Authorization')?.match(/^Bearer\s+(\S+)$/i)?.[1];
  if (!token) return respond(401, { error: 'Sesión requerida.' });
  try {
    const url = Deno.env.get('SUPABASE_URL');
    const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !secret) return respond(503, { error: 'Configuración del servidor incompleta.' });
    const admin = createClient(url, secret, { auth: { autoRefreshToken: false, persistSession: false } });
    // Always verify token against Auth; do not trust actor/role from request body.
    const { data: auth, error: authError } = await admin.auth.getUser(token);
    if (authError || !auth.user) return respond(401, { error: 'Sesión inválida o vencida.' });
    const { data: actor, error: actorError } = await admin.from('perfiles').select('id,rol,activo,sucursal_id').eq('id', auth.user.id).maybeSingle();
    if (actorError) return respond(503, { error: 'No se pudo verificar el perfil.' });
    if (!actor?.activo || !['administrador', 'supervisor'].includes(actor.rol)) return respond(403, { error: 'Acceso no autorizado.' });
    let input;
    try { input = await req.json(); } catch { return respond(400, { error: 'Solicitud inválida.' }); }
    if (!input || typeof input !== 'object') return respond(400, { error: 'Solicitud inválida.' });
    const { nombre, email, password, rol, sucursal_id } = input;
    if (typeof nombre !== 'string' || !nombre.trim() || nombre.trim().length > 150 ||
        typeof email !== 'string' || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim()) ||
        typeof password !== 'string' || password.length < 12 || password.length > 128 ||
        !['supervisor', 'promotor'].includes(rol) || typeof sucursal_id !== 'string' || !uuid.test(sucursal_id)) {
      return respond(400, { error: 'Revisa nombre, correo, contraseña, rol y sucursal.' });
    }
    if (actor.rol === 'supervisor' && (rol !== 'promotor' || actor.sucursal_id !== sucursal_id)) return respond(403, { error: 'Solo puedes crear promotores de tu sucursal.' });
    const { data: branch, error: branchError } = await admin.from('sucursales').select('id,activa').eq('id', sucursal_id).maybeSingle();
    if (branchError) return respond(503, { error: 'No se pudo verificar la sucursal.' });
    if (!branch?.activa) return respond(400, { error: 'Sucursal no activa.' });
    const { data: created, error: createError } = await admin.auth.admin.createUser({ email: email.trim(), password, email_confirm: true });
    if (createError || !created.user) return respond(400, { error: 'No se pudo crear la cuenta Auth. Verifica que el correo no exista y que la contraseña cumpla la política del proyecto.' });
    const uid = created.user.id;
    // The database repeats authorization checks inside this RPC.
    const { error: provisionError } = await admin.rpc('aprovisionar_perfil', { p_actor: auth.user.id, p_usuario: uid, p_nombre: nombre.trim(), p_rol: rol, p_sucursal: sucursal_id });
    if (provisionError) {
      // Don't delete on an ambiguous response: first verify whether the transaction committed.
      const { data: existing, error: lookupError } = await admin.from('perfiles').select('id').eq('id', uid).maybeSingle();
      if (!lookupError && existing) return respond(200, { ok: true, id: uid });
      if (!lookupError && !existing) {
        const { error: cleanupError } = await admin.auth.admin.deleteUser(uid);
        if (!cleanupError) return respond(409, { error: 'No se pudo crear el perfil operativo. La cuenta Auth nueva fue retirada; revisa permisos y sucursal.' });
      }
      return respond(503, { error: 'Alta no confirmada. Un administrador debe revisar Authentication y perfiles antes de reintentar.' });
    }
    return respond(201, { ok: true, id: uid });
  } catch {
    return respond(503, { error: 'No se pudo confirmar la operación. Revisa Authentication y perfiles antes de reintentar.' });
  }
});
