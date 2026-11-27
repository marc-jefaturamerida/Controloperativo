import { createClient } from 'npm:@supabase/supabase-js@2.49.4';
const origin = Deno.env.get('CO_ALLOWED_ORIGIN') || 'https://marc-jefaturamerida.github.io';
const cors = {'Access-Control-Allow-Origin':origin,'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Vary':'Origin','Cache-Control':'no-store'};
const reply=(status:number,body:object)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const opts={auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}};
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers:cors});
 if(req.method!=='POST')return reply(405,{error:'Método no permitido.'});
 if(req.headers.get('origin') && origin!=='*' && req.headers.get('origin')!==origin)return reply(403,{error:'Origen no autorizado.'});
 const token=req.headers.get('Authorization')?.match(/^Bearer\s+(\S+)$/i)?.[1];
 if(!token)return reply(401,{error:'Sesión requerida.'});
 try{
  const url=Deno.env.get('SUPABASE_URL'),secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),anon=Deno.env.get('SUPABASE_ANON_KEY');
  if(!url||!secret||!anon)return reply(503,{error:'Configuración incompleta.'});
  const admin=createClient(url,secret,opts);
  const {data:auth,error:authError}=await admin.auth.getUser(token);
  if(authError||!auth.user)return reply(401,{error:'Sesión inválida.'});
  const actorClient=createClient(url,anon,{...opts,global:{headers:{Authorization:'Bearer '+token}}});
  const {error:sessionError}=await actorClient.rpc('marc_epoch_state_126');
  if(sessionError)return reply(401,{error:'Sesión revocada o no autorizada.'});
  const payloadPart=token.split('.')[1];
  const sessionId=JSON.parse(atob(payloadPart.replace(/-/g,'+').replace(/_/g,'/').padEnd(Math.ceil(payloadPart.length/4)*4,'='))).session_id;
  if(typeof sessionId!=='string'||!uuid.test(sessionId))return reply(401,{error:'Sesión no confirmada.'});
  const {data:actor,error:actorError}=await admin.from('perfiles').select('id,rol,activo,sucursal_id').eq('id',auth.user.id).maybeSingle();
  if(actorError)return reply(503,{error:'No se pudo verificar el perfil.'});
  if(!actor?.activo||!['administrador','supervisor'].includes(actor.rol))return reply(403,{error:'Acceso no autorizado.'});
  let input;try{const raw=await req.text();if(raw.length>8192)return reply(400,{error:'Solicitud inválida.'});input=JSON.parse(raw)}catch{return reply(400,{error:'Solicitud inválida.'});}
  if(!input||typeof input!=='object')return reply(400,{error:'Solicitud inválida.'});
  const {nombre,password,rol,sucursal_id}=input;
  const correo=typeof input.email==='string'?input.email.trim():(input.email==null?'':null);
  const usuario=typeof input.usuario==='string'?input.usuario.trim():(input.usuario==null?'':null);
  if(typeof nombre!=='string'||!nombre.trim()||nombre.trim().length>150||correo===null||correo.length>254||(correo&&(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo)||correo.toLowerCase().endsWith('@marc.invalid')))||usuario===null||typeof password!=='string'||password.length<12||password.length>128||!['supervisor','promotor'].includes(rol)||typeof sucursal_id!=='string'||!uuid.test(sucursal_id))return reply(400,{error:'Revisa nombre, usuario, correo opcional, contraseña, rol y sucursal.'});
  if(actor.rol==='administrador'&&!/^[a-z0-9._]{1,64}$/.test(usuario))return reply(400,{error:'Nombre de usuario obligatorio: minúsculas, números, puntos y guiones bajos (1–64).'});
  if(actor.rol==='supervisor'&&(usuario||rol!=='promotor'||actor.sucursal_id!==sucursal_id))return reply(403,{error:'Solo puedes crear promotores de tu sucursal, pendientes de asignación por el administrador.'});
  const {data:branch,error:branchError}=await admin.from('sucursales').select('id,activa').eq('id',sucursal_id).maybeSingle();
  if(branchError||!branch?.activa)return reply(400,{error:'Sucursal no disponible.'});
  const email='marc-'+crypto.randomUUID()+'@marc.invalid';
  const {data:created,error:createError}=await admin.auth.admin.createUser({email,password,email_confirm:true});
  input.password='';
  if(createError||!created.user)return reply(400,{error:'No se pudo crear la identidad Auth. Verifica la política de contraseñas y configuración del proyecto.'});
  const uid=created.user.id;
  const {data:provision,error:provisionError}=await admin.rpc('marc_provision_login_143',{p_actor:auth.user.id,p_session:sessionId,p_usuario:uid,p_nombre:nombre.trim(),p_rol:rol,p_sucursal:sucursal_id,p_login:usuario||null,p_correo:correo||null});
  if(provisionError||provision!==uid){
   const {data:existing,error:lookupError}=await admin.from('perfiles').select('id').eq('id',uid).maybeSingle();
   if(!lookupError&&existing)return reply(200,{ok:true,id:uid,pendiente:!usuario});
   if(!lookupError&&!existing){const {error:cleanupError}=await admin.auth.admin.deleteUser(uid);if(!cleanupError)return reply(409,{error:provisionError?.message?.includes('Nombre de usuario ya utilizado')?'Nombre de usuario ya utilizado.':'Alta no realizada. Cuenta Auth retirada; revisa permisos y sucursal.'});}
   return reply(503,{error:'Alta no confirmada. Revisa Authentication y perfiles antes de reintentar.'});
  }
  return reply(201,{ok:true,id:uid,pendiente:!usuario});
 }catch{return reply(503,{error:'Operación no confirmada. Revisa Authentication y perfiles antes de reintentar.'});}
});
