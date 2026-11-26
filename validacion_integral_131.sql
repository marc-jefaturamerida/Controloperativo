-- MARC 1.3.1 integral — diagnóstico final de solo lectura. No ejecuta RPC operativas.
WITH required_tables(name) AS (VALUES
 ('marc_admin_changes_131'),('marc_admin_archived_users_131'),('marc_admin_archived_branches_131'),
 ('marc_stock_imports_130'),('marc_stock_modules_130'),('marc_supervisor_transfers_131')
), required_rpc(signature) AS (VALUES
 ('public.marc_admin_catalog_131()'),('public.marc_admin_history_131(integer)'),
 ('public.marc_admin_change_131(uuid,text,text,text,jsonb,jsonb,text)')
), old_rpc(signature) AS (VALUES
 ('public.gestionar_perfil(uuid,text,boolean)'),('public.marc_transfer_supervisor_131(uuid,uuid,uuid,uuid)')
), table_checks AS (
 SELECT r.name, c.oid IS NOT NULL AS existe, coalesce(c.relrowsecurity,false) AS rls,
  CASE WHEN c.oid IS NULL THEN false ELSE NOT (has_table_privilege('anon',c.oid,'SELECT') OR has_table_privilege('authenticated',c.oid,'SELECT') OR has_table_privilege('authenticated',c.oid,'INSERT') OR has_table_privilege('authenticated',c.oid,'UPDATE') OR has_table_privilege('authenticated',c.oid,'DELETE') OR has_table_privilege('service_role',c.oid,'INSERT') OR has_table_privilege('service_role',c.oid,'UPDATE') OR has_table_privilege('service_role',c.oid,'DELETE')) END AS sin_acceso_directo,
  EXISTS(SELECT 1 FROM pg_trigger g WHERE g.tgrelid=c.oid AND g.tgname='marc_guard_write_124' AND g.tgenabled='O') AS protegido_mantenimiento
 FROM required_tables r LEFT JOIN pg_class c ON c.oid=to_regclass('public.'||r.name)
), rpc_checks AS (
 SELECT r.signature,p.oid IS NOT NULL AS existe,coalesce(p.prosecdef,false) AS security_definer,
  CASE WHEN p.oid IS NULL THEN false ELSE has_function_privilege('authenticated',p.oid,'EXECUTE') AND NOT has_function_privilege('anon',p.oid,'EXECUTE') AND NOT has_function_privilege('service_role',p.oid,'EXECUTE') END AS permisos
 FROM required_rpc r LEFT JOIN pg_proc p ON p.oid=to_regprocedure(r.signature)
), legacy_checks AS (
 SELECT r.signature, CASE WHEN p.oid IS NULL THEN false ELSE NOT has_function_privilege('authenticated',p.oid,'EXECUTE') AND NOT has_function_privilege('anon',p.oid,'EXECUTE') AND NOT has_function_privilege('service_role',p.oid,'EXECUTE') END AS bloqueada
 FROM old_rpc r LEFT JOIN pg_proc p ON p.oid=to_regprocedure(r.signature)
), source_checks AS (
 SELECT bool_and(coalesce(strpos(pg_get_functiondef(to_regprocedure('public.marc_backup_snapshot_120()')),r.name)>0,false)) AS respaldo_6_tablas,
 bool_and(coalesce(strpos(pg_get_functiondef(to_regprocedure('public.marc_restore_rehearsal_125(jsonb)')),r.name)>0,false)) AS ensayo_6_tablas,
 bool_and(coalesce(strpos(pg_get_functiondef(to_regprocedure('operativo_privado.marc_restore_rows_128(jsonb,jsonb,text)')),r.name)>0,false)) AS restauracion_6_tablas
 FROM required_tables r
), other_checks AS (
 SELECT
  coalesce(strpos(pg_get_functiondef(to_regprocedure('operativo_privado.marc_session_valid_126()')),'auth.sessions')>0 AND strpos(pg_get_functiondef(to_regprocedure('operativo_privado.marc_session_valid_126()')),'p.activo')>0,false) AS sesion_activa,
  coalesce(strpos(pg_get_functiondef(to_regprocedure('public.marc_epoch_state_126()')),'scope_after')>0,false) AS ambito_offline,
  coalesce(strpos(pg_get_functiondef(to_regprocedure('public.crear_registro(uuid,uuid,timestamp with time zone,jsonb)')),'MARC_CAPTURA_AMBITO_ANTERIOR')>0,false) AS captura_anterior,
  (SELECT count(*)=3 FROM pg_trigger g WHERE g.tgname='marc_admin_archive_guard_131' AND g.tgenabled='O' AND g.tgrelid IN ('public.perfiles'::regclass,'public.promotores'::regclass,'public.sucursales'::regclass)) AS guardias_papelera,
  EXISTS(SELECT 1 FROM public.perfiles WHERE rol='administrador' AND activo) AS administrador_activo,
  EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='marc_admin_archived_excel_read_131') AS archivos_historicos,
  EXISTS(SELECT 1 FROM pg_class WHERE oid='public.metas_efectivas'::regclass AND 'security_invoker=true'=ANY(reloptions)) AS vista_metas_protegida
)
SELECT jsonb_build_object('version','MARC 1.3.1 integral',
 'estructura_correcta', (SELECT bool_and(existe AND rls AND sin_acceso_directo AND protegido_mantenimiento) FROM table_checks)
 AND (SELECT bool_and(existe AND security_definer AND permisos) FROM rpc_checks)
 AND (SELECT bool_and(bloqueada) FROM legacy_checks)
 AND (SELECT respaldo_6_tablas AND ensayo_6_tablas AND restauracion_6_tablas FROM source_checks)
 AND (SELECT sesion_activa AND ambito_offline AND captura_anterior AND guardias_papelera AND administrador_activo AND archivos_historicos AND vista_metas_protegida FROM other_checks),
 'tablas',(SELECT jsonb_agg(to_jsonb(t) ORDER BY name) FROM table_checks t),
 'rpc',(SELECT jsonb_agg(to_jsonb(t) ORDER BY signature) FROM rpc_checks t),
 'rutas_anteriores',(SELECT jsonb_agg(to_jsonb(t) ORDER BY signature) FROM legacy_checks t),
 'respaldo',(SELECT to_jsonb(t) FROM source_checks t),
 'protecciones',(SELECT to_jsonb(t) FROM other_checks t)) AS diagnostico;
