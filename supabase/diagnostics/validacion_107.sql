-- MARC 1.1.0 RC1 / Int. 10.7: auditoría de solo lectura.
-- Ejecutar como postgres en SQL Editor después de las integraciones 10.4 y 10.6.
-- No crea, cambia ni elimina registros. No sustituye pruebas funcionales por rol.
with tables(t) as (values ('marc_tutorial_attempts'), ('marc_tutorial_requests')),
functions(f) as (values ('marc_tutorial_can_read_104(uuid)'), ('marc_tutorial_save_104(uuid,integer,text,timestamptz)'), ('marc_tutorial_request_106(uuid)')),
checks as (
 select t||' · RLS activo' as control, coalesce((select c.relrowsecurity from pg_class c where c.oid=to_regclass('public.'||t)),false) as ok from tables
 union all select t||' · anon sin privilegios de datos', coalesce(not has_table_privilege('anon',to_regclass('public.'||t),'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'),false) from tables
 union all select t||' · authenticated solo lectura', coalesce(has_table_privilege('authenticated',to_regclass('public.'||t),'SELECT') and not has_table_privilege('authenticated',to_regclass('public.'||t),'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'),false) from tables
 union all select t||' · política única de consulta', (select count(*)=1 and bool_and(cmd='SELECT' and roles=array['authenticated']::name[] and replace(qual,'public.','') in ('marc_tutorial_can_read_104(user_id)','(marc_tutorial_can_read_104(user_id))')) from pg_policies where schemaname='public' and tablename=t) from tables
 union all select f||' · anon sin EXECUTE',coalesce(not has_function_privilege('anon',to_regprocedure('public.'||f),'EXECUTE'),false) from functions
 union all select f||' · authenticated con EXECUTE',coalesce(has_function_privilege('authenticated',to_regprocedure('public.'||f),'EXECUTE'),false) from functions
 union all select f||' · SECURITY DEFINER y search_path vacío',coalesce((select p.prosecdef and ('search_path=""'=any(p.proconfig) or 'search_path='=any(p.proconfig)) from pg_proc p where p.oid=to_regprocedure('public.'||f)),false) from functions
 union all select 'Intentos · estados y pasos coherentes', not exists(select 1 from public.marc_tutorial_attempts where tutorial_version<>1 or completed_steps not between 0 and 22 or status not in ('en_progreso','completado','omitido') or (status='completado') is distinct from (completed_steps=22) or (status='completado') is distinct from (completed_at is not null) or (status='omitido' and completed_steps<>0))
 union all select 'Solicitudes · máximo una pendiente por promotor', not exists(select 1 from public.marc_tutorial_requests q where not exists(select 1 from public.marc_tutorial_attempts a where a.user_id=q.user_id and a.attempt_id=q.request_id) group by q.user_id,q.tutorial_version having count(*)>1)
)
select control,case when ok is true then 'Correcto' else 'Revisar' end as resultado from checks order by control;
