import { createClient } from 'npm:@supabase/supabase-js@2.49.4';
const origin = Deno.env.get('CO_ALLOWED_ORIGIN') || 'https://marc-jefaturamerida.github.io';
const cors = {'Access-Control-Allow-Origin':origin,'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Cache-Control':'no-store','Vary':'Origin'};
const reply = (status:number,body:object) => new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});
const denied = () => reply(401,{error:'Datos de acceso incorrectos o cuenta no disponible. Si persiste, contacta al administrador.'});
const opts = {auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}};
Deno.serve(async req => {
  if(req.method==='OPTIONS') return new Response(null,{status:204,headers:cors});
  if(req.method!=='POST') return reply(405,{error:'Método no permitido.'});
  if(req.headers.get('origin') && origin!=='*' && req.headers.get('origin')!==origin) return reply(403,{error:'Origen no autorizado.'});
  try {
    const length=Number(req.headers.get('content-length')||0);
    if(length>4096) return denied();
    const raw=await req.text(); if(raw.length>4096) return denied();
    const body=JSON.parse(raw);
    if(!body || typeof body.identificador!=='string' || typeof body.password!=='string' || !body.password || body.password.length>4096) return denied();
    const identifier=body.identificador.trim().toLowerCase();
    if(!identifier || identifier.length>254 || (!/^[a-z0-9._]{1,64}$/.test(identifier) && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(identifier))) return denied();
    const url=Deno.env.get('SUPABASE_URL'), secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), anon=Deno.env.get('SUPABASE_ANON_KEY');
    if(!url||!secret||!anon) return reply(503,{error:'Servicio de acceso no disponible.'});
    const admin=createClient(url,secret,opts);
    const {data:target,error:lookup}=await admin.rpc('marc_login_lookup_143',{p_identificador:identifier});
    if(lookup) return reply(503,{error:'Servicio de acceso no disponible.'});
    if(!target?.id || !target?.email) return denied();
    const client=createClient(url,anon,opts);
    const {data,error}=await client.auth.signInWithPassword({email:target.email,password:body.password});
    body.password='';
    if(error || !data.session || data.user?.id!==target.id) return denied();
    const {data:still,error:check}=await admin.rpc('marc_login_confirm_143',{p_identificador:identifier,p_id:target.id,p_email:target.email});
    if(check || still!==true){await client.auth.signOut({scope:'local'});return denied();}
    return reply(200,{access_token:data.session.access_token,refresh_token:data.session.refresh_token});
  } catch {return reply(503,{error:'Servicio de acceso no disponible.'});}
});
