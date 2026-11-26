/* Control operativo 1.3.1 integral: cache only the public application shell. Never cache API/auth/storage responses. */
'use strict';
const ROOT=new URL(self.registration.scope);
const PREFIX='co-pwa-'+ROOT.pathname+'-';
const CACHE=PREFIX+'v1-3-1-papelera-individual-1';
const INDEX=new URL('index.html',ROOT).href;
const SDK='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.49.4/dist/umd/supabase.js';
const LOCAL=['index.html','manifest.webmanifest','icon-192.png','icon-512.png','logo-marc.png','physical-local-140.js','stock-import-130.js','stock-import-ui-130.js'].map(x=>new URL(x,ROOT).href);
const STATIC=new Set([...LOCAL,SDK]);
async function fetchStatic(url){const r=await fetch(url,{cache:'reload',credentials:url===SDK?'omit':'same-origin',mode:url===SDK?'cors':'same-origin'});if(!r.ok||r.type==='opaque')throw new Error('No se pudo preparar '+url);return r;}
self.addEventListener('install',e=>e.waitUntil((async()=>{const c=await caches.open(CACHE);try{const files=await Promise.all([...STATIC].map(async url=>[url,await fetchStatic(url)]));for(const [url,res] of files)await c.put(url,res);await self.skipWaiting();}catch(err){await caches.delete(CACHE);throw err;}})()));
self.addEventListener('activate',e=>e.waitUntil((async()=>{for(const key of await caches.keys())if(key.startsWith(PREFIX)&&key!==CACHE)await caches.delete(key);await self.clients.claim();})()));
function shellPath(u){return u.origin===ROOT.origin&&(u.pathname===ROOT.pathname||u.pathname===new URL(INDEX).pathname);}
async function navigation(req){const c=await caches.open(CACHE);const ac=new AbortController();const timeout=setTimeout(()=>ac.abort(),4000);try{const res=await fetch(req,{signal:ac.signal,cache:'no-store'});if(res.ok&&!res.redirected&&res.headers.get('content-type')?.includes('text/html')){return res;}if(res.status!==503&&res.status!==502&&res.status!==504)return res;throw Error('Servidor no disponible');}catch{const saved=await c.match(INDEX);return saved||new Response('Control operativo no está preparado para abrir sin conexión. Conéctate a internet.',{status:503,headers:{'Content-Type':'text/plain; charset=utf-8'}});}finally{clearTimeout(timeout);}}
self.addEventListener('fetch',e=>{const req=e.request;if(req.method!=='GET')return;const u=new URL(req.url);if(req.mode==='navigate'&&shellPath(u)){e.respondWith(navigation(req));return;}if(!STATIC.has(u.href))return;e.respondWith((async()=>{const c=await caches.open(CACHE);return await c.match(u.href)||await fetch(req);})());});
