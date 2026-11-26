/* Inventario local: no escrituras al stock. */
window.openPhysical140=async function(){
 const owner=profile;if(!owner||!manager()||(offline7&&!offlineAllowed7()))return;
 const root=openDialog('Inventario físico · revisión rápida'); const key='physical140:'+owner.id;
 let stale=false;const valid=()=>!stale&&profile===owner&&note.isConnected&&!$('opDialog').hidden&&(!offline7||offlineAllowed7());
 const note=el('p');root.append(note);const tell=t=>note.textContent=t;
 const read=()=>tx7('settings','readonly',(s,done)=>{const q=s.get(key);q.onsuccess=()=>done(q.result)});
 let revision;
 const save=v=>tx7('settings','readwrite',(store,done,abort)=>{
   const request=store.get(key);
   request.onsuccess=()=>{
     if(stale||request.result?.revision!==revision){stale=true;abort(Error('Otra ventana cambió el conteo. Vuelve a abrirlo.'));return}
     const next=crypto.randomUUID();store.put({...v,revision:next},key);done(next);
   };
 }).then(next=>{revision=next});

 let data;try{data=await read();revision=data?.revision;}catch(e){tell(fail(e));return;}if(!valid())return;
 if(data&&(data.role!==owner.rol||data.scope!==owner.sucursal_id||data.generation!==localEpoch126(owner).records))data=null;
 const tools=el('div');tools.className='toolbar';root.append(tools);
 const button=(parent,label,fn)=>{const b=el('button',label);b.type='button';b.className='btn';b.onclick=async()=>{if(!valid())return;try{await fn()}catch(e){tell(fail(e))}};parent.append(b);return b};
 const file=el('input');file.type='file';file.accept='.xlsx,.xlsm';file.disabled=offline7;tools.append(file);
 const search=el('input');search.type='search';search.placeholder='Buscar código, terminación o texto';tools.append(search);
 const filter=el('select');opt(filter,[['','Todos'],['pendiente','Pendientes'],['si','Encontradas'],['no','No encontradas'],['incidencia','Incidencias']],'');filter.hidden=true;tools.append(filter);
 const size=el('select');opt(size,[['50','50'],['100','100'],['250','250'],['999999','Todas']],'50');tools.append(size);
 const stats=el('div'),list=el('div'),pager=el('div');pager.className='toolbar';const tabs=el('div');root.append(stats,tabs,list,pager);let page=0,chain=Promise.resolve();
 const persist=()=>{const snapshot=structuredClone(data);chain=chain.catch(()=>{}).then(()=>save(snapshot));return chain.catch(e=>{stale=true;if(note.isConnected)tell('No se guardó el último cambio. Vuelve a abrir el inventario. '+fail(e));throw e})};
 function draw(){if(!valid())return;closeButton.disabled=!data||data.closed;list.replaceChildren();pager.replaceChildren();if(!data){stats.textContent='Carga un Excel para comenzar.';return;}resumenFisico(stats,data.rows,r=>r.estado_revision);
 filtrosFisicos(tabs,filter.value,data.rows.some(r=>r.estado_revision==='pendiente'),key=>{filter.value=key;page=0;draw()});
 const q=search.value.trim().toLowerCase(),rows=data.rows.filter(r=>(!filter.value||r.estado_revision===filter.value)&&(!q||r.search.includes(q)||r.comentario.toLowerCase().includes(q)));const n=Number(size.value);page=Math.max(0,Math.min(page,Math.ceil(rows.length/n)-1));
 for(const r of rows.slice(page*n,(page+1)*n)){let panel;
 const line=tarjetaFisica(r,r.estado_revision,!!data.closed,async checked=>{
   if(!valid()||data.closed)return;
   r.estado_revision=checked?'si':data.inicioPresente?'no':'pendiente';
   draw();await persist().catch(()=>{});
 },()=>{
   if(panel){panel.remove();panel=null;return;}
   panel=el('div');panel.className='edit-card';
   panel.append(el('strong',r.codigo_barras),el('p',r.hoja_excel+' · Fila '+r.numero_fila));
   if(data.closed){panel.append(el('p',r.comentario||'Sin comentario'));}
   else{
     const st=el('select');opt(st,Object.entries(invStatus).filter(([k])=>!data.inicioPresente||k!=='pendiente'),r.estado_revision);
     st.setAttribute('aria-label','Estado de la tarjeta');const c=el('textarea');c.value=r.comentario;c.maxLength=32767;c.placeholder='Comentario';c.setAttribute('aria-label','Comentario');
     panel.append(st,c);button(panel,'Guardar detalle',async()=>{
       if(data.closed)return;
       if(st.value==='incidencia'&&!c.value.trim()){tell('Escribe un comentario para la incidencia.');return;}
       r.estado_revision=st.value;r.comentario=c.value;await persist();draw();
     });
   }
   line.after(panel);
 });
 list.append(line);
 }button(pager,'Anterior',()=>{page--;draw()});pager.append(el('span',`${rows.length} resultados · página ${page+1}`));button(pager,'Siguiente',()=>{page++;draw()});}
 file.onchange=async()=>{try{if(!valid()||offline7||!file.files[0])return;if(data&&!confirm('¿Sustituir el inventario local anterior?'))return;await verifyAction();const f=file.files[0],bytes=await f.arrayBuffer(),book=await Excel4.loadWorkbook(bytes),config=Object.create(null),rows=[],modules=new Set(),codes=new Set();for(const sh of book.sheets){const a=sh.autodetect;if(!a?.barcodeCol||!a.moduleCol)continue;if([a.barcodeCol,a.moduleCol,a.cardCol].includes('H'))throw Error('La columna H está ocupada por un identificador en '+sh.name);if(!confirm('¿Incluir hoja '+sh.name+' y utilizar H para comentarios?'))continue;config[sh.name]={...a,path:sh.path,hConfirmed:true};for(const row of sh.rows){if(row.n<=a.headerRow||!Excel4.getV(row,a.barcodeCol))continue;const code=Excel4.codeDisplay(Excel4.getV(row,a.barcodeCol)),module=String(Excel4.getV(row,a.moduleCol)).trim();if(!/^\d{21}$/.test(code)||!module||codes.has(code))throw Error('Código inválido, duplicado o módulo ausente: '+sh.name+' fila '+row.n);codes.add(code);modules.add(module);const comment=String(Excel4.getV(row,'H'));rows.push({hoja_excel:sh.name,numero_fila:row.n,codigo_barras:code,estado_revision:'si',comentario:comment,comentario_original:comment,search:Object.values(row.vals).join(' ').toLowerCase()})}}if(!rows.length||modules.size!==1)throw Error('Se requiere un módulo único y tarjetas válidas');const module=[...modules][0];const branch=take(await db.rpc('marc_physical_branch_140',{p_module:module}));if(!valid())return;const next={inicioPresente:true,role:owner.rol,scope:owner.sucursal_id,generation:localEpoch126(owner).records,module,branch,bytes,config,rows,ext:f.name.split('.').pop().toLowerCase()};await chain;await save(next);data=next;page=0;draw();tell('Inventario guardado localmente.');}catch(e){tell(fail(e))}finally{file.value=''}};
 const closeButton=button(tools,'Cerrar inventario',async()=>{
   if(!data||data.closed)return;
   const pending=data.rows.filter(r=>r.estado_revision==='pendiente').length;
   if(!confirm('Quedan '+pending+' tarjetas pendientes. Al cerrar pasarán a «No la tenemos». ¿Confirmas el cierre definitivo?'))return;
   const closed={...data,closed:true,rows:data.rows.map(r=>r.estado_revision==='pendiente'?{...r,estado_revision:'no'}:r)};
   data=closed;draw();
   try{await persist();tell('Inventario cerrado y guardado.')}
   catch(e){data=await read();revision=data?.revision;draw();throw e}
 });
 button(tools,'Exportar Excel',async()=>{if(!data)return;await chain;if(data.rows.some(r=>r.estado_revision==='pendiente'))throw Error('Hay tarjetas pendientes. Termina el conteo o confirma el cierre antes de exportar.');const rows=data.rows;const blob=await Excel4.exportBook(data.bytes,rows,data.config,data.ext);const check=await verifyExcluded61(data.bytes,blob,data.config);if(!check.ok)throw Error('No se verificó la conservación del libro');if(!valid())return;saveInv61(blob,`Inventario ${data.module} Semana ${invWeek(new Date().toISOString().slice(0,10))[1]}.${data.ext}`.replace(/[\\/:*?"<>|]/g,''))});
 for(const c of [search,filter,size])c.oninput=()=>{page=0;draw()};draw();
};
