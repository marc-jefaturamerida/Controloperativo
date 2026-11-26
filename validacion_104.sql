-- Run AFTER the migration, in Supabase SQL Editor as postgres.
-- All trial writes are rolled back. No operational tables are modified.
begin;
do $$
declare
  promoter uuid; branch uuid; supervisor_same uuid; supervisor_other uuid; admin_id uuid; other_promoter uuid;
  trial uuid := gen_random_uuid(); omitted uuid := gen_random_uuid(); r public.marc_tutorial_attempts;
  n integer; before_count bigint; denied boolean;
begin
  select p.id,p.sucursal_id into promoter,branch from public.perfiles p join public.sucursales s on s.id=p.sucursal_id where p.activo and p.rol='promotor' and s.activa order by p.id limit 1;
  if promoter is null then raise exception 'Se necesita al menos un promotor activo en sucursal activa para validar.'; end if;
  select p.id into admin_id from public.perfiles p where p.activo and p.rol='administrador' limit 1;
  select p.id into supervisor_same from public.perfiles p where p.activo and p.rol='supervisor' and p.sucursal_id=branch limit 1;
  select p.id into supervisor_other from public.perfiles p join public.sucursales s on s.id=p.sucursal_id where p.activo and p.rol='supervisor' and s.activa and p.sucursal_id<>branch limit 1;
  select p.id into other_promoter from public.perfiles p join public.sucursales s on s.id=p.sucursal_id where p.activo and p.rol='promotor' and s.activa and p.id<>promoter limit 1;
  if not exists(select 1 from pg_class c join pg_namespace s on s.oid=c.relnamespace where s.nspname='public' and c.relname='marc_tutorial_attempts' and c.relrowsecurity) then raise exception 'RLS no está activo'; end if;
  if has_table_privilege('anon','public.marc_tutorial_attempts','SELECT') or has_function_privilege('anon','public.marc_tutorial_save_104(uuid,integer,text,timestamptz)','EXECUTE') then raise exception 'Anon tiene privilegios indebidos'; end if;
  if has_table_privilege('authenticated','public.marc_tutorial_attempts','INSERT') or has_table_privilege('authenticated','public.marc_tutorial_attempts','UPDATE') or has_table_privilege('authenticated','public.marc_tutorial_attempts','DELETE') then raise exception 'Authenticated tiene escritura directa indebida'; end if;
  raise notice 'Correcto: RLS, privilegios anon y escritura directa';
  perform set_config('request.jwt.claim.sub',promoter::text,true);
  perform set_config('request.jwt.claims',json_build_object('sub',promoter::text,'role','authenticated')::text,true);
  execute 'set local role authenticated';
  select count(*) into before_count from public.marc_tutorial_attempts where user_id=promoter;
  select * into r from public.marc_tutorial_save_104(trial,5,'en_progreso',now());
  if r.user_id<>promoter or r.completed_steps<>5 then raise exception 'Guardado inicial incorrecto'; end if;
  select * into r from public.marc_tutorial_save_104(trial,3,'en_progreso',now());
  if r.completed_steps<>5 then raise exception 'El progreso retrocedió'; end if;
  select * into r from public.marc_tutorial_save_104(trial,22,'completado',now());
  if r.completed_steps<>22 or r.status<>'completado' or r.completed_at is null then raise exception 'Finalización incorrecta'; end if;
  select * into r from public.marc_tutorial_save_104(trial,4,'en_progreso',now());
  if r.status<>'completado' or r.completed_steps<>22 then raise exception 'Finalización sobrescrita'; end if;
  select * into r from public.marc_tutorial_save_104(omitted,0,'omitido',now());
  if r.status<>'omitido' then raise exception 'Omisión incorrecta'; end if;
  select * into r from public.marc_tutorial_save_104(omitted,22,'completado',now());
  if r.status<>'omitido' then raise exception 'Omisión sobrescrita'; end if;
  if (select count(*) from public.marc_tutorial_attempts where user_id=promoter)<>before_count+2 then raise exception 'Los intentos no se conservaron por separado'; end if;
  if exists(select 1 from public.marc_tutorial_attempts where user_id<>promoter) then raise exception 'Promotor puede leer datos ajenos'; end if;
  denied:=false; begin perform public.marc_tutorial_save_104(gen_random_uuid(),23,'completado',now()); exception when invalid_parameter_value then denied:=true; end;
  if not denied then raise exception 'Se admitió progreso inválido'; end if;
  execute 'reset role';
  raise notice 'Correcto: promotor, avance monotónico, finalización, omisión, historial y validación de pasos';
  if other_promoter is not null then
    perform set_config('request.jwt.claim.sub',other_promoter::text,true);
    perform set_config('request.jwt.claims',json_build_object('sub',other_promoter::text,'role','authenticated')::text,true);
    execute 'set local role authenticated';
    select count(*) into n from public.marc_tutorial_attempts where user_id=promoter and attempt_id=trial;
    if n<>0 then raise exception 'Otro promotor puede consultar el intento'; end if;
    execute 'reset role'; raise notice 'Correcto: aislamiento entre promotores';
  else raise notice 'Pendiente: no existe segundo promotor activo'; end if;
  if supervisor_same is not null then
    perform set_config('request.jwt.claim.sub',supervisor_same::text,true);
    perform set_config('request.jwt.claims',json_build_object('sub',supervisor_same::text,'role','authenticated')::text,true);
    execute 'set local role authenticated';
    select count(*) into n from public.marc_tutorial_attempts where user_id=promoter and attempt_id=trial;
    if n<>1 then raise exception 'Supervisor no puede consultar su sucursal'; end if;
    denied:=false; begin perform public.marc_tutorial_save_104(gen_random_uuid(),0,'en_progreso',now()); exception when insufficient_privilege then denied:=true; end;
    if not denied then raise exception 'Supervisor puede escribir capacitación'; end if;
    execute 'reset role'; raise notice 'Correcto: supervisor de la sucursal, solo lectura';
  else raise notice 'Pendiente: no hay supervisor activo en la sucursal elegida'; end if;
  if supervisor_other is not null then
    perform set_config('request.jwt.claim.sub',supervisor_other::text,true);
    perform set_config('request.jwt.claims',json_build_object('sub',supervisor_other::text,'role','authenticated')::text,true);
    execute 'set local role authenticated';
    select count(*) into n from public.marc_tutorial_attempts where user_id=promoter and attempt_id=trial;
    if n<>0 then raise exception 'Supervisor puede consultar otra sucursal'; end if;
    execute 'reset role'; raise notice 'Correcto: aislamiento entre sucursales';
  else raise notice 'Pendiente: no hay supervisor activo en otra sucursal'; end if;
  if admin_id is not null then
    perform set_config('request.jwt.claim.sub',admin_id::text,true);
    perform set_config('request.jwt.claims',json_build_object('sub',admin_id::text,'role','authenticated')::text,true);
    execute 'set local role authenticated';
    select count(*) into n from public.marc_tutorial_attempts where user_id=promoter and attempt_id=trial;
    if n<>1 then raise exception 'Administrador no puede consultar el intento'; end if;
    denied:=false; begin perform public.marc_tutorial_save_104(gen_random_uuid(),0,'en_progreso',now()); exception when insufficient_privilege then denied:=true; end;
    if not denied then raise exception 'Administrador puede escribir directamente el progreso'; end if;
    execute 'reset role'; raise notice 'Correcto: administrador, solo lectura';
  else raise notice 'Pendiente: no existe administrador activo'; end if;
end $$;
rollback;
