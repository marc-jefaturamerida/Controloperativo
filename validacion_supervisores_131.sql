-- Solo lectura. Puede ejecutarse antes o después de instalar. No incluye datos de usuarios ni tokens.
BEGIN TRANSACTION READ ONLY;
SELECT jsonb_build_object(
 'version','MARC 1.3.1',
 'dependencias',jsonb_build_object(
  'require_session',to_regprocedure('operativo_privado.marc_require_session_126()') IS NOT NULL,
  'session_valid',to_regprocedure('operativo_privado.marc_session_valid_126()') IS NOT NULL,
  'stock_guard',to_regprocedure('operativo_privado.marc_stock_guard_130(boolean)') IS NOT NULL,
  'epoch_state',to_regprocedure('public.marc_epoch_state_126()') IS NOT NULL),
 'helper_revocacion',coalesce((SELECT (
    strpos(f.helper, 'ifnotoperativo_privado.marc_session_valid_126()then') > 0
    AND strpos(f.helper, 'raiseexception''marc_sesion_no_vigente:') > 0
    AND strpos(f.validator, 'fromauth.sessionss') > 0
    AND strpos(f.validator, 's.id::text=auth.jwt()->>''session_id''') > 0
    AND strpos(f.validator, 's.user_id=auth.uid()') > 0
    AND strpos(f.validator, 'crossjoinoperativo_privado.marc_epoch_126e') > 0
    AND strpos(f.validator, 'e.singleton') > 0
    AND strpos(f.validator, 's.created_at>e.sessions_after') > 0
    AND strpos(f.validator, '(s.not_afterisnullors.not_after>statement_timestamp())') > 0
    AND strpos(f.validator, 'selectcoalesce(exists(') > 0
  ) FROM (SELECT
    lower(regexp_replace(replace(pg_get_functiondef(to_regprocedure('operativo_privado.marc_require_session_126()')), '"', ''), '[[:space:]]+', '', 'g')) AS helper,
    lower(regexp_replace(replace(pg_get_functiondef(to_regprocedure('operativo_privado.marc_session_valid_126()')), '"', ''), '[[:space:]]+', '', 'g')) AS validator
  ) f),false),
 'privilegios_auth',jsonb_build_object('users_select',has_table_privilege(current_user,'auth.users','SELECT'),'users_update',has_table_privilege(current_user,'auth.users','UPDATE'),'sessions_select',has_table_privilege(current_user,'auth.sessions','SELECT'),'sessions_delete',has_table_privilege(current_user,'auth.sessions','DELETE'),'refresh_select',has_table_privilege(current_user,'auth.refresh_tokens','SELECT'),'refresh_delete',has_table_privilege(current_user,'auth.refresh_tokens','DELETE')),
 'columnas_auth',(SELECT jsonb_agg(jsonb_build_object('tabla',table_name,'columna',column_name,'tipo',data_type) ORDER BY table_name,column_name) FROM information_schema.columns WHERE table_schema='auth' AND table_name IN ('sessions','refresh_tokens') AND column_name IN ('id','user_id','session_id')),
 'relaciones_auth',(SELECT jsonb_agg(jsonb_build_object('tabla',conrelid::regclass::text,'definicion',pg_get_constraintdef(oid)) ORDER BY conname) FROM pg_constraint WHERE confrelid IN (to_regclass('auth.sessions'),to_regclass('auth.refresh_tokens'))),
 'bitacora',(SELECT jsonb_build_object('rls',c.relrowsecurity,'acl',c.relacl::text,'anon_select',has_table_privilege('anon',c.oid,'SELECT'),'authenticated_select',has_table_privilege('authenticated',c.oid,'SELECT'),'authenticated_insert',has_table_privilege('authenticated',c.oid,'INSERT'),'authenticated_update',has_table_privilege('authenticated',c.oid,'UPDATE'),'authenticated_delete',has_table_privilege('authenticated',c.oid,'DELETE')) FROM pg_class c WHERE c.oid=to_regclass('public.marc_supervisor_transfers_131')),
 'rpc',(SELECT coalesce(jsonb_agg(jsonb_build_object('nombre',p.proname,'definer',p.prosecdef,'anon_execute',has_function_privilege('anon',p.oid,'EXECUTE'),'authenticated_execute',has_function_privilege('authenticated',p.oid,'EXECUTE'),'service_role_execute',has_function_privilege('service_role',p.oid,'EXECUTE')) ORDER BY p.proname),'[]'::jsonb) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('marc_transfer_supervisor_131','marc_supervisor_history_131')),
 'triggers_perfiles',(SELECT coalesce(jsonb_agg(jsonb_build_object('nombre',tgname,'definicion',pg_get_triggerdef(oid),'habilitado',tgenabled)),'[]'::jsonb) FROM pg_trigger WHERE tgrelid='public.perfiles'::regclass AND NOT tgisinternal)
) AS validacion_marc_131;
COMMIT;
