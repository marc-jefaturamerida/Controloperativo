/* MARC v2.1.13 — publicación controlada R1. Operaciones autorizadas por RPC. */
(function () {
 'use strict';
 const states=new Map();
 const types={recordList:'registro',incList:'incidencia',stockList:'tarjeta',invList:'inventario',invRows:'fila',userList:'usuario',branchList:'sucursal',adminTrashusuario131:'usuario',adminTrashsucursal131:'sucursal',adminModulesList131:'equivalencia'};
 const adminOnly=new Set(['usuario','sucursal','equivalencia','alias','enlace','taller','pregunta']);
 const catalogTypes=new Set(['usuario','sucursal','aviso','taller','enlace','pregunta','equivalencia','alias','meta']);
 const keyOf=(x,type)=>String(type==='equivalencia'?(x.modulo??x.id??''):(x.id??x.modulo??''));
 function eligible(type,x,p){return !!p&&['administrador','supervisor'].includes(p.rol)&&(!adminOnly.has(type)||p.rol==='administrador')&&!(type==='usuario'&&x.rol==='administrador')&&!(type==='aviso'&&x.manage===false)&&keyOf(x,type)!=='';}
 function create(tag,text,cls){const e=document.createElement(tag);if(text!=null)e.textContent=text;if(cls)e.className=cls;return e;}
 function button(label,fn,cls='btn'){const b=create('button',label,cls);b.type='button';b.onclick=fn;return b;}
 function makeSelection(items,selected=new Set()){
  const allowed=new Set(items.map(x=>x.id));
  return {selected:new Set([...selected].filter(id=>allowed.has(id))),allowed};
 }
 function stateFor(key,items,owner,filter){const signature=JSON.stringify(items.map(x=>[x.id,x.revision,x.accion]).sort((a,b)=>a[0].localeCompare(b[0])));let s=states.get(key);if(!s||s.owner!==owner||s.filter!==filter||s.signature!==signature){s={owner,filter,signature,mode:false,...makeSelection(items)};states.set(key,s);}return s;}
 async function rpc(name,args,owner){await verifyAction();if(profile!==owner)throw Error('La sesión cambió.');const v=take(await db.rpc(name,args));if(profile!==owner)throw Error('La sesión cambió.');return v;}
 function validPreview(v,items){
  if(!v||typeof v.token!=='string'||!v.token||!Array.isArray(v.permitidos)||!Array.isArray(v.bloqueados)||!Array.isArray(v.dependencias))throw Error('Vista previa no válida. No se ejecutó ninguna eliminación.');
  const expected=new Set(items.map(x=>x.id));const seen=new Set();for(const x of [...v.permitidos,...v.bloqueados]){if(!x||typeof x.id!=='string'||!expected.has(x.id)||seen.has(x.id)||typeof x.etiqueta!=='string')throw Error('La vista previa no corresponde a la selección.');seen.add(x.id);}if(seen.size!==expected.size)throw Error('Vista previa incompleta.');
  for(const d of v.dependencias)if(!d||typeof d.tipo!=='string'||typeof d.etiqueta!=='string'||typeof d.accion!=='string')throw Error('Dependencias no reconocidas.');
  return v;
 }
 let pending=false, operationGeneration=0;
 async function confirmDelete(type,items,refresh){
  if(pending||busy||offline7||!navigator.onLine||!profile||!items.length)return;
  if(!['administrador','supervisor'].includes(profile.rol)||(adminOnly.has(type)&&profile.rol!=='administrador')){msg('appMsg','Acceso no autorizado.',true);return;}
  if(items.some(x=>!x.id)||new Set(items.map(x=>x.id)).size!==items.length){msg('appMsg','Selección inválida.',true);return;}
  if(items.length>2000){msg('appMsg','Selecciona como máximo 2000 elementos por operación.',true);return;}
  const owner=profile;const actions=new Set(items.map(x=>x.accion));if(actions.size!==1){msg('appMsg','Selecciona únicamente elementos activos o únicamente elementos de Papelera.',true);return;}
  const action=items[0].accion;if(!['papelera','definitiva'].includes(action)){msg('appMsg','Acción inválida.',true);return;}pending=true;const generation=++operationGeneration;
  let d;
  try{
   const preview=validPreview(await rpc(catalogTypes.has(type)?'marc_catalogo_eliminacion_previa_2113':'marc_eliminacion_previa_2113',{p_tipo:type,p_accion:action,p_items:items.map(({id,revision})=>({id,revision}))},owner),items);
   if(profile!==owner||generation!==operationGeneration)return;
   d=create('dialog',null,'marc-del-dialog');const title=create('h2',action==='definitiva'?'Eliminación definitiva':'Enviar a Papelera');const info=create('p',`${items.length} seleccionados · ${preview.permitidos.length} permitidos · ${preview.bloqueados.length} bloqueados`);d.append(title,info);
   for(const [heading,entries] of [['Se eliminarán',preview.permitidos],['Bloqueados',preview.bloqueados],['Dependencias y otros efectos',preview.dependencias]]){if(!entries.length)continue;d.append(create('h3',heading));const ul=create('ul');for(const r of entries)ul.append(create('li',[r.tipo,r.etiqueta,r.accion,r.motivo].filter(Boolean).join(' · ')));d.append(ul);}
   const form=create('form');const motive=create('textarea');motive.maxLength=2000;motive.placeholder='Motivo opcional';motive.setAttribute('aria-label','Motivo opcional');form.append(motive);
   const typed=items.length>1;const phrase=create('input');phrase.autocomplete='off';phrase.setAttribute('aria-label','Escribe ELIMINAR');if(typed){form.append(create('p','Escribe ELIMINAR para confirmar.'),phrase);}
   const error=create('p');error.setAttribute('role','alert');const controls=create('div',null,'toolbar');const cancel=button('Cancelar',()=>d.close());const apply=button(action==='definitiva'?'Eliminar definitivamente':'Enviar a Papelera',()=>{},'btn marc-del-danger');apply.type='submit';
   let used=false;const update=()=>apply.disabled=used||!preview.permitidos.length||(typed&&phrase.value!=='ELIMINAR');phrase.oninput=update;update();controls.append(cancel,apply);form.append(error,controls);d.append(form);document.body.append(d);d.addEventListener('close',()=>{d.remove();if(generation===operationGeneration)pending=false;},{once:true});d.showModal(); cancel.focus();
   let sending=false;d.addEventListener('cancel',e=>{if(sending)e.preventDefault();});
   form.onsubmit=async e=>{e.preventDefault();if(sending||used||apply.disabled||profile!==owner||generation!==operationGeneration||busy||offline7||!navigator.onLine)return;used=true;sending=true;apply.disabled=cancel.disabled=true;busy=true;try{const res=await rpc(catalogTypes.has(type)?'marc_catalogo_eliminacion_aplicar_2113':'marc_eliminacion_aplicar_2113',{p_token:preview.token,p_motivo:motive.value.trim()||null,p_confirmacion:typed?phrase.value:null},owner);const expected=new Set(preview.permitidos.map(x=>x.id));if(res?.ok!==true||!Array.isArray(res.afectados)||res.afectados.length!==expected.size||new Set(res.afectados).size!==expected.size||res.afectados.some(id=>!expected.has(id)))throw Error('Resultado no confirmado. Revisa la bitácora antes de reintentar.');d.close();if(profile===owner){busy=false;await refresh();toast('Operación confirmada: '+res.afectados.length+' elementos.');}}catch(e){if(d.isConnected)error.textContent=fail(e)+' · Consulta nuevamente la lista antes de reintentar.';else if(profile===owner)msg('appMsg',fail(e),true);}finally{busy=false;sending=false;cancel.disabled=false;/* no reintentar un token de resultado incierto */}};
  }catch(e){if(d?.isConnected)d.remove();if(generation===operationGeneration)pending=false;if(profile===owner&&generation===operationGeneration)msg('appMsg','Eliminación no disponible: '+fail(e),true);}
 }
 function descriptor(type,data,label,forced){return {id:(forced==='definitiva'&&type==='equivalencia'?String(data.id??''):keyOf(data,type)),revision:catalogTypes.has(type)?(data.version??data.revision??data.actualizado_en??data.updated_at??data.creado_en??null):(data.version??data.actualizado_en??null),etiqueta:String(label||keyOf(data,type)),accion:forced||(data.eliminado_en||data.retirado_en||data.state==='papelera'||data.config?.deleted_at?'definitiva':'papelera')};}
 function mount({key,type,root,all,visible,nodes,filter='',refresh,forced,table=false,filteredAvailable=true,revisionOverride=false}){
  const p=profile;if(!p||offline7||!navigator.onLine||!root||!types[key]&&!type)return;
  type=type||types[key];if(nodes.length!==visible.length)return;const toItem=x=>{const item=descriptor(type,x.data,x.label??x.cells?.filter(Boolean).slice(0,3).join(' · '),forced);if(revisionOverride)item.revision=null;return item;};
  const items=all.filter(x=>eligible(type,x.data,p)).map(toItem),display=visible.map(x=>eligible(type,x.data,p)?toItem(x):null);if(!items.length)return;
  if(new Set(items.map(x=>x.id)).size!==items.length)return;
  const s=stateFor(key,items,p,filter);const bar=create('div',null,'toolbar marc-del-toolbar');const toggle=button('Seleccionar',()=>{s.mode=!s.mode;if(!s.mode)s.selected.clear();draw();});const count=create('span');count.setAttribute('aria-live','polite');const page=button('Seleccionar página',()=>{for(const x of display)if(x)s.selected.add(x.id);draw();});const allButton=button('Seleccionar filtrados',()=>{s.selected=new Set(items.map(x=>x.id));draw();});const clear=button('Limpiar',()=>{s.selected.clear();draw();});const apply=button('Eliminar seleccionados',()=>confirmDelete(type,items.filter(x=>s.selected.has(x.id)),refresh),'btn marc-del-danger');bar.append(toggle,count,page,allButton,clear,apply);
  root.prepend(bar);const selectors=[];let head=null;if(table){head=root.querySelector('thead tr');if(head)head.append(create('th','Selección','marc-del-cell'));}
  nodes.forEach((node,i)=>{const item=display[i];const area=create(table?'td':'div',null,'marc-del-cell');if(table)area.dataset.label144='Selección';if(item){const ck=create('input');ck.type='checkbox';ck.onclick=e=>e.stopPropagation();ck.setAttribute('aria-label','Seleccionar '+item.etiqueta);ck.onchange=()=>{ck.checked?s.selected.add(item.id):s.selected.delete(item.id);draw();};const individual=button('🗑',()=>confirmDelete(type,[item],refresh),'btn marc-del-danger');individual.addEventListener('click',e=>e.stopPropagation());individual.setAttribute('aria-label','Eliminar '+item.etiqueta);individual.title=(item.accion==='definitiva'?'Eliminar definitivamente: ':'Enviar a Papelera: ')+item.etiqueta;area.append(ck,individual);selectors.push({ck,item});}node.append(area);});
  function draw(){toggle.textContent=s.mode?'Cancelar selección':'Seleccionar';toggle.setAttribute('aria-pressed',String(s.mode));count.textContent=`${s.selected.size} de ${items.length} seleccionados`;for(const e of [count,page,allButton,clear,apply])e.hidden=!s.mode;allButton.hidden=!s.mode||!filteredAvailable;apply.disabled=!s.selected.size;clear.disabled=!s.selected.size;for(const {ck,item} of selectors){ck.hidden=!s.mode;ck.checked=s.selected.has(item.id);}}
  draw();
 }
 function mountTable(id,all,visible){const root=$(id);if(!root||!types[id])return;const owner=profile,view=active;mount({key:id,root,all,visible,nodes:[...root.querySelectorAll('tbody tr')],filter:pageKey944(id),table:true,forced:id.startsWith('adminTrash')?'definitiva':undefined,refresh:async()=>{if(profile!==owner)return;closeRow945();closeOp(true);await go(view);if(id.startsWith('adminTrash'))adminPaper131();else if(id==='adminModulesList131')adminModules131();}});}
 function mountPhysical(all,visible){const root=$('invRows'),owner=profile,id=invSelected?.id;if(!root||!id)return;mount({key:'invRows',root,all:all.map(data=>({data,label:data.codigo_barras})),visible:visible.map(data=>({data,label:data.codigo_barras})),nodes:[...root.children].slice(0,visible.length),filter:JSON.stringify([id,$('invSearch').value,$('invSheet').value,$('invFilter').value]),refresh:async()=>{if(profile!==owner)return;await go('physical');if(profile===owner&&invList.some(x=>x.id===id))await selectInv4(id);}});}
 async function openTrash(){
  if(busy||offline7||!navigator.onLine||!manager())return;
  const owner=profile;if(!owner)return;const root=openDialog('Papelera operativa');
  root.append(button('Papelera de catálogos',()=>openCatalog('aviso',true)),create('p','Los folios y las tarjetas consumidas se liberan únicamente al eliminar definitivamente la venta. El servidor verifica dependencias y permisos.'));
  const section=create('div');root.append(section);
  try{
   await verifyAction();const rows=await leerPapelera('marc_papelera_operativa_2113',{},'tipo');
   if(profile!==owner||!section.isConnected)return;
   if(!rows.length)section.append(create('p','Sin elementos retirados.'));
   for(const type of ['registro','incidencia','tarjeta','inventario','fila']){
    const data=rows.filter(r=>r.tipo===type);if(!data.length)continue;
    const panel=create('section');section.append(create('h3',type),panel);
    const nodes=data.map(r=>{const line=create('div',r.etiqueta+' · '+new Date(r.fecha).toLocaleString('es-MX'),'toolbar');panel.append(line);return line;});
    const all=data.map(r=>({data:r,label:r.etiqueta}));
    mount({key:'trash2113-'+type,type,root:panel,all,visible:all,nodes,forced:'definitiva',filter:'papelera',refresh:async()=>{if(profile===owner){await go(active);if(profile===owner)await openTrash();}}});
   }
  }catch(e){if(section.isConnected)section.textContent=fail(e);}
 }
 const catalogNames={usuario:'Usuarios',sucursal:'Sucursales',aviso:'Avisos y comunicados',taller:'Talleres',enlace:'Enlaces rápidos',pregunta:'Banco de preguntas',equivalencia:'Equivalencias de módulos',alias:'Equivalencias de importación',meta:'Metas registradas'};
 async function openCatalog(initial='aviso',trash=false){
  if(busy||offline7||!navigator.onLine||!manager())return;
  const owner=profile;if(!owner)return;const root=openDialog('Gestión de eliminaciones · catálogos');const controls=create('div',null,'toolbar'),type=create('select'),state=create('select'),search=create('input');search.type='search';search.placeholder='Buscar registro';search.setAttribute('aria-label','Buscar registro');type.setAttribute('aria-label','Sección');state.setAttribute('aria-label','Estado');
  for(const [k,label] of Object.entries(catalogNames)){if(owner.rol!=='administrador'&&!['aviso','meta'].includes(k))continue;const o=create('option',label);o.value=k;type.append(o);}type.value=initial;if(!type.value)type.selectedIndex=0;
  for(const [k,label] of [['activos','Registros del catálogo'],['papelera','Papelera']]){const o=create('option',label);o.value=k;state.append(o);}state.value=trash?'papelera':'activos';
  const list=create('div'),status=create('p'),pager=create('div',null,'toolbar');root.append(create('p','Se excluyen estadísticas y bitácoras. Las dependencias y permisos se validan antes de aplicar cualquier eliminación.'),controls,status,list,pager);controls.append(type,state,search);let rows=[],seq=0,page=0,loading=false;
  async function load(){const n=++seq,requestedType=type.value,requestedState=state.value;loading=true;rows=[];list.replaceChildren();pager.replaceChildren();status.textContent='Consultando…';try{await verifyAction();const result=await leerPapelera('marc_catalogo_eliminacion_listar_2113',{p_tipo:requestedType,p_papelera:requestedState==='papelera'},'id');if(profile!==owner||n!==seq||!list.isConnected||type.value!==requestedType||state.value!==requestedState)return;rows=result;page=0;loading=false;status.textContent='';draw();}catch(e){if(profile===owner&&n===seq&&list.isConnected){loading=false;status.textContent=fail(e);}}}
  function draw(){if(loading)return;list.replaceChildren();pager.replaceChildren();const q=search.value.trim().toLocaleLowerCase('es-MX');const filtered=rows.filter(r=>String(r.etiqueta??'').toLocaleLowerCase('es-MX').includes(q));const max=Math.max(0,Math.ceil(filtered.length/50)-1);page=Math.min(max,Math.max(0,page));const visible=filtered.slice(page*50,page*50+50);if(!visible.length){list.append(create('p','Sin registros con estos filtros.'));return;}const nodes=visible.map(r=>{const node=create('div',null,'toolbar');node.append(create('span',r.etiqueta??r.id));list.append(node);return node;});const wrap=data=>({data,label:data.etiqueta});mount({key:'catalog2113-'+type.value,type:type.value,root:list,all:filtered.map(wrap),visible:visible.map(wrap),nodes,filter:JSON.stringify([type.value,state.value,q]),forced:state.value==='papelera'?'definitiva':'papelera',refresh:load});const prev=button('Anterior',()=>{page--;draw();}),next=button('Siguiente',()=>{page++;draw();});prev.disabled=page===0;next.disabled=page>=max;pager.append(create('span',`${filtered.length} resultados · Página ${page+1} de ${max+1}`),prev,next);}
  type.onchange=state.onchange=()=>{search.value='';load();};search.oninput=()=>{page=0;draw();};await load();
 }
 function openFiltered({key,type,rows,refresh,filter='',revisionOverride=false,labelOf=x=>x.etiqueta??x.folio??x.codigo_completo??x.nombre_archivo??x.id}){
  if(busy||offline7||!navigator.onLine||!manager())return;
  if(rows.length>2000){msg('appMsg','Reduce los filtros a un máximo de 2000 registros por operación.',true);return;}
  const owner=profile,root=openDialog('Eliminar resultados filtrados');
  root.append(create('p',`${rows.length} resultados obtenidos con los filtros actuales. Selecciona activos o elementos de Papelera por separado.`));
  const state=create('select');state.setAttribute('aria-label','Estado de eliminación');
  for(const [v,t] of [['papelera','Activos · enviar a Papelera'],['definitiva','Papelera · eliminar definitivamente']]){const o=create('option',t);o.value=v;state.append(o);}
  const list=create('div'),pager=create('div',null,'toolbar');root.append(state,list,pager);let page=0;
  const wrapped=rows.map(data=>({data,label:labelOf(data)}));
  const groups={papelera:wrapped.filter(x=>descriptor(type,x.data).accion==='papelera'),definitiva:wrapped.filter(x=>descriptor(type,x.data).accion==='definitiva')};if(!groups.papelera.length&&groups.definitiva.length)state.value='definitiva';
  function draw(){if(profile!==owner||!list.isConnected)return;list.replaceChildren();pager.replaceChildren();const group=groups[state.value];const pages=Math.max(1,Math.ceil(group.length/50));page=Math.min(Math.max(page,0),pages-1);const visible=group.slice(page*50,page*50+50);if(!visible.length){list.append(create('p','Sin elementos en este estado.'));return;}const nodes=visible.map(x=>{const row=create('div',null,'toolbar');row.append(create('span',x.label));list.append(row);return row;});mount({key:'filtered-'+key,type,root:list,all:group,visible,nodes,filter:filter+'|'+state.value,forced:state.value,revisionOverride,refresh:async()=>{closeOp(true);await refresh();}});const prev=button('Anterior',()=>{page--;draw();}),next=button('Siguiente',()=>{page++;draw();});prev.disabled=page===0;next.disabled=page>=pages-1;pager.append(create('span',`${group.length} resultados · Página ${page+1} de ${pages}`),prev,next);}
  state.onchange=()=>{page=0;draw();};draw();
 }
 async function batch(type,rows,action,refresh){return confirmDelete(type,rows.map(x=>descriptor(type,x,x.etiqueta??x.nombre??x.texto??x.config?.title??x.config?.name??x.question?.text,action)),refresh);}
 async function single(type,data,label,refresh=null,forced){const owner=profile,view=active;return confirmDelete(type,[descriptor(type,data,label,forced)],refresh|| (async()=>{if(profile===owner){closeRow945();closeOp(true);await go(view);}}));}
 window.MarcEliminacion2113={single,batch,openCatalog,mountTable,mountPhysical,mount,confirmDelete,openTrash,openFiltered,reset:()=>{operationGeneration++;states.clear();document.querySelectorAll('.marc-del-dialog').forEach(d=>{try{d.close()}catch{}d.remove();});pending=false;}};
})();
