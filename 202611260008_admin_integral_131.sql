-- MARC 1.3.1 integral: instalar DESPUES de 1.3.0 y de la reasignacion 1.3.1 corregida.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
SELECT pg_catalog.pg_advisory_xact_lock(12004,124);
DO $preflight$
BEGIN
 IF to_regclass('public.marc_admin_changes_131') IS NOT NULL THEN RAISE EXCEPTION 'MARC integral ya instalado o instalación previa distinta. No repetir sin diagnóstico.'; END IF;
 IF EXISTS(SELECT 1 FROM operativo_privado.marc_backup_window_124 WHERE singleton AND expires_at>clock_timestamp()) OR operativo_privado.marc_file_pending_1210() THEN RAISE EXCEPTION 'Finaliza mantenimiento antes de instalar.'; END IF;
 IF to_regclass('public.marc_supervisor_transfers_131') IS NULL OR to_regclass('public.marc_stock_modules_130') IS NULL OR to_regclass('public.marc_stock_imports_130') IS NULL THEN RAISE EXCEPTION 'Faltan migraciones 1.3.0/1.3.1 corregida.'; END IF;
 IF NOT (pg_catalog.has_table_privilege(current_user,'auth.users','SELECT') AND pg_catalog.has_table_privilege(current_user,'auth.users','UPDATE')) OR NOT (pg_catalog.has_table_privilege(current_user,'auth.identities','SELECT') AND pg_catalog.has_table_privilege(current_user,'auth.identities','UPDATE')) OR NOT (pg_catalog.has_table_privilege(current_user,'auth.sessions','SELECT') AND pg_catalog.has_table_privilege(current_user,'auth.sessions','DELETE')) OR NOT (pg_catalog.has_table_privilege(current_user,'auth.refresh_tokens','SELECT') AND pg_catalog.has_table_privilege(current_user,'auth.refresh_tokens','DELETE')) THEN RAISE EXCEPTION 'Permisos Auth insuficientes.'; END IF;
 IF to_regclass('auth.one_time_tokens') IS NULL OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_attribute WHERE attrelid='auth.one_time_tokens'::regclass AND attname='user_id' AND atttypid='uuid'::regtype AND NOT attisdropped) OR NOT (pg_catalog.has_table_privilege(current_user,'auth.one_time_tokens','SELECT') AND pg_catalog.has_table_privilege(current_user,'auth.one_time_tokens','DELETE')) THEN RAISE EXCEPTION 'No se puede cancelar tokens de correo/recuperación pendientes. No se instaló la actualización.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.perfiles WHERE rol='administrador' AND activo) THEN RAISE EXCEPTION 'No existe administrador activo.'; END IF;
END $preflight$;
DO $fingerprints$
DECLARE d text;
BEGIN
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='marc_backup_snapshot_120' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'9105239823ee3f9c4ffb5d3000a97b9a6e33e1c31c539ff279bdca80ff0dabf7' THEN RAISE EXCEPTION 'Definición distinta de public.marc_backup_snapshot_120. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='marc_restore_rehearsal_125' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_snapshot jsonb';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'305a5d531abfd01008bf4cdaa44ade994bbff0ccb28e06f96cb4b91cdff98f86' THEN RAISE EXCEPTION 'Definición distinta de public.marc_restore_rehearsal_125. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='operativo_privado' AND p.proname='marc_restore_rows_128' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_snapshot jsonb, p_manifest jsonb, p_confirmation text';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'5a3509a737aa9b10922fee151fafc6cc3b39bb73cc9bb60f7f85704a828a64df' THEN RAISE EXCEPTION 'Definición distinta de operativo_privado.marc_restore_rows_128. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='marc_restore_apply_127' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_snapshot jsonb, p_manifest jsonb, p_confirmation text';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'ef2e8bf308cffeead0dacd416113c8182dd3809483abea332ad21a2ec596c9c2' THEN RAISE EXCEPTION 'Definición distinta de public.marc_restore_apply_127. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='operativo_privado' AND p.proname='marc_session_valid_126' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'26a5e8280f2f82a8e768c70753e2dac85589358047b1514dc97a5e9675d4dc5a' THEN RAISE EXCEPTION 'Definición distinta de operativo_privado.marc_session_valid_126. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='marc_epoch_state_126' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'e1f28b348031b2c42b56157558bbdef3c2c32d5e4d6f941e78822481edd779e3' THEN RAISE EXCEPTION 'Definición distinta de public.marc_epoch_state_126. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='alta_tarjeta' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_sucursal uuid, p_prefijo text, p_terminacion text';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'1605033db21bc9d9a2269a67e847fe1e88057853c65aea71d3fb70203d8d5860' THEN RAISE EXCEPTION 'Definición distinta de public.alta_tarjeta. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='transferir_tarjeta' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_tarjeta uuid, p_destino uuid, p_comentario text';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'96bc69a617dbd2139d3f1d1acfac03230241402a4c10a44eb3eeaab565af3125' THEN RAISE EXCEPTION 'Definición distinta de public.transferir_tarjeta. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='asignar_tarjeta' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_tarjeta uuid, p_promotor uuid';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'b59c8808cc90495a36dde5917357dee886400150c01b1649a4ce142fe94174b1' THEN RAISE EXCEPTION 'Definición distinta de public.asignar_tarjeta. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='asignar_tarjetas_lote' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_tarjetas uuid[], p_promotor uuid';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'842d85e7d7df8a88903bcc43cb66ea6f65037176f5a2611af7e91636645d2b93' THEN RAISE EXCEPTION 'Definición distinta de public.asignar_tarjetas_lote. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='crear_registro' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_operacion uuid, p_dispositivo uuid, p_fecha_captura timestamp with time zone, p_datos jsonb';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'0ab6b8c024224143cca4a8b7905e234c1e3f3e1d4e121f8d790e277abdeb0696' THEN RAISE EXCEPTION 'Definición distinta de public.crear_registro. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='crear_inventario' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_id uuid, p_sucursal uuid, p_nombre text, p_ruta text, p_extension text, p_anio integer, p_semana integer, p_modulo text, p_config jsonb';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'fef12991d761e2bdc3aef6dfee2c4f1c3e10e66faeeca2030a652770526c6dba' THEN RAISE EXCEPTION 'Definición distinta de public.crear_inventario. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='aprovisionar_perfil' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_actor uuid, p_usuario uuid, p_nombre text, p_rol rol_operativo, p_sucursal uuid';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'27e76816b422a0f070f58b29e0a5d79df2206c79b55061d43d87a43490e0a95d' THEN RAISE EXCEPTION 'Definición distinta de public.aprovisionar_perfil. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='crear_sucursal' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_codigo text, p_nombre text, p_zona text';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'d5e0925dffd1f78f9ff5c25e23978f2596d8338a3f96cc66dc45ab0748c63ea4' THEN RAISE EXCEPTION 'Definición distinta de public.crear_sucursal. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='marc_stock_apply_130' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_id uuid, p_rows jsonb, p_map jsonb, p_expected jsonb, p_meta jsonb';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'1f7e29080de3ee1f7116cb4bbec60fd7509a9a2ed9ce671486cc75e15e69b25b' THEN RAISE EXCEPTION 'Definición distinta de public.marc_stock_apply_130. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='guardar_meta' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_sucursal uuid, p_promotor uuid, p_inicio date, p_ventas integer, p_objetivos jsonb, p_meta_individual_base integer';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'c6ded8613cea45e1effec2ee6761dd0fd88cae984c8078489fea81e393f118f5' THEN RAISE EXCEPTION 'Definición distinta de public.guardar_meta. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='editar_registro' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_registro uuid, p_version integer, p_datos jsonb, p_motivo_reversion text';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'445125d95573edeb0e5cd13897f0b97be8380c28bb30cb19c40f7961301e0c7a' THEN RAISE EXCEPTION 'Definición distinta de public.editar_registro. No se instaló nada.'; END IF;
 SELECT replace(pg_catalog.pg_get_functiondef(p.oid),chr(13)||chr(10),chr(10)) INTO STRICT d FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='operativo_privado' AND p.proname='revertir' AND pg_catalog.pg_get_function_identity_arguments(p.oid)='p_tarjeta uuid, p_registro uuid, p_motivo text';
 IF encode(pg_catalog.sha256(pg_catalog.convert_to(d,'UTF8')),'hex')<>'e9bd5d9f5809104e75c0d87bdc13f4b05ba873377fb510a2c910f1f4cdc1c902' THEN RAISE EXCEPTION 'Definición distinta de operativo_privado.revertir. No se instaló nada.'; END IF;
END $fingerprints$;

CREATE TABLE public.marc_admin_archived_users_131 (
 usuario_id uuid PRIMARY KEY REFERENCES public.perfiles(id) ON DELETE RESTRICT,
 eliminado_por uuid NOT NULL REFERENCES public.perfiles(id),
 eliminado_en timestamptz NOT NULL DEFAULT clock_timestamp(),
 nombre text NOT NULL CHECK(btrim(nombre)<>'')
);
CREATE TABLE public.marc_admin_archived_branches_131 (
 sucursal_id uuid PRIMARY KEY REFERENCES public.sucursales(id) ON DELETE RESTRICT,
 eliminado_por uuid NOT NULL REFERENCES public.perfiles(id),
 eliminado_en timestamptz NOT NULL DEFAULT clock_timestamp(),
 nombre text NOT NULL CHECK(btrim(nombre)<>'')
);
CREATE TABLE public.marc_admin_changes_131 (
 id uuid PRIMARY KEY,
 actor_id uuid NOT NULL REFERENCES public.perfiles(id),
 actor_nombre text NOT NULL,
 entidad text NOT NULL CHECK(entidad IN ('usuario','sucursal','equivalencia')),
 entidad_id text NOT NULL,
 accion text NOT NULL CHECK(accion IN ('editar','eliminar','restaurar')),
 anterior jsonb NOT NULL CHECK(jsonb_typeof(anterior)='object'),
 nuevo jsonb NOT NULL CHECK(jsonb_typeof(nuevo)='object'),
 solicitud jsonb NOT NULL CHECK(jsonb_typeof(solicitud)='object'),
 fecha timestamptz NOT NULL DEFAULT clock_timestamp(),
 sesiones_revocadas bigint NOT NULL DEFAULT 0 CHECK(sesiones_revocadas>=0),
 cambio_ambito boolean NOT NULL DEFAULT false
);
CREATE INDEX marc_admin_changes_scope_131 ON public.marc_admin_changes_131(entidad_id,fecha DESC) WHERE entidad='usuario' AND cambio_ambito;
CREATE INDEX marc_admin_changes_date_131 ON public.marc_admin_changes_131(fecha DESC,id);
DO $tables$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['marc_admin_archived_users_131','marc_admin_archived_branches_131','marc_admin_changes_131','marc_stock_imports_130','marc_stock_modules_130','marc_supervisor_transfers_131'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, anon, authenticated, service_role',t);
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_trigger WHERE tgrelid=to_regclass('public.'||t) AND tgname='marc_guard_write_124') THEN
   EXECUTE format('CREATE TRIGGER marc_guard_write_124 BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.%I FOR EACH STATEMENT EXECUTE FUNCTION operativo_privado.marc_guard_write_124()',t);
  END IF;
 END LOOP;
END $tables$;

CREATE FUNCTION operativo_privado.marc_scope_after_131(p_user uuid) RETURNS timestamptz
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT greatest((SELECT max(fecha) FROM public.marc_admin_changes_131 WHERE entidad='usuario' AND entidad_id=p_user::text AND cambio_ambito),
 (SELECT max(fecha) FROM public.marc_supervisor_transfers_131 WHERE supervisor_id=p_user));
$$;
CREATE FUNCTION operativo_privado.marc_admin_guard_131() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM operativo_privado.marc_admin_120();
 PERFORM pg_catalog.pg_advisory_xact_lock(12004,124);
 PERFORM operativo_privado.marc_admin_120();
 PERFORM operativo_privado.marc_write_allowed_124();
END $$;
CREATE FUNCTION operativo_privado.marc_admin_user_131(p_user uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('id',p.id,'nombre',p.nombre,'email',u.email,'rol',p.rol::text,'sucursal_id',p.sucursal_id,'activo',p.activo,'eliminado_en',a.eliminado_en)
 FROM public.perfiles p LEFT JOIN auth.users u ON u.id=p.id LEFT JOIN public.marc_admin_archived_users_131 a ON a.usuario_id=p.id WHERE p.id=p_user;
$$;
CREATE FUNCTION operativo_privado.marc_admin_branch_131(p_branch uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('id',s.id,'nombre',s.nombre,'codigo',s.codigo,'zona_horaria',s.zona_horaria,'activa',s.activa,'eliminado_en',a.eliminado_en)
 FROM public.sucursales s LEFT JOIN public.marc_admin_archived_branches_131 a ON a.sucursal_id=s.id WHERE s.id=p_branch;
$$;
CREATE FUNCTION operativo_privado.marc_admin_branch_dependencies_131(p_branch uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('usuarios_activos',(SELECT count(*) FROM public.perfiles WHERE sucursal_id=p_branch AND activo),
 'promotores_activos',(SELECT count(*) FROM public.promotores WHERE sucursal_id=p_branch AND activo),
 'stock_disponible',(SELECT count(*) FROM public.tarjetas WHERE sucursal_id=p_branch AND estado IN ('disponible','asignada')),
 'inventarios_abiertos',(SELECT count(*) FROM public.inventarios WHERE sucursal_id=p_branch AND estado='abierto'));
$$;
CREATE FUNCTION operativo_privado.marc_admin_revoke_131(p_user uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE n bigint;
BEGIN
 -- Mismo mecanismo validado de 1.3.1: no toca las sesiones de otras cuentas.
 LOCK TABLE auth.sessions,auth.refresh_tokens IN SHARE ROW EXCLUSIVE MODE;
 DELETE FROM auth.refresh_tokens WHERE user_id::text=p_user::text OR session_id IN(SELECT id FROM auth.sessions WHERE user_id=p_user);
 DELETE FROM auth.sessions WHERE user_id=p_user;
 GET DIAGNOSTICS n=ROW_COUNT;
 IF EXISTS(SELECT 1 FROM auth.sessions WHERE user_id=p_user) OR EXISTS(SELECT 1 FROM auth.refresh_tokens WHERE user_id::text=p_user::text) THEN RAISE EXCEPTION 'Revocación incompleta'; END IF;
 RETURN n;
END $$;
-- Protección incluso para rutas antiguas o cambios administrativos directos.
CREATE FUNCTION operativo_privado.marc_admin_archive_guard_131() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_TABLE_NAME='perfiles' THEN
  IF EXISTS(SELECT 1 FROM public.marc_admin_archived_users_131 WHERE usuario_id=NEW.id) AND (NEW.activo OR NEW.rol='administrador') THEN RAISE EXCEPTION 'Restaura la cuenta desde la papelera antes de modificar su estado.'; END IF;
  IF NEW.activo AND NEW.rol<>'administrador' AND EXISTS(SELECT 1 FROM public.marc_admin_archived_branches_131 WHERE sucursal_id=NEW.sucursal_id) THEN RAISE EXCEPTION 'Sucursal eliminada.'; END IF;
 ELSIF TG_TABLE_NAME='sucursales' THEN
  IF NEW.activa AND EXISTS(SELECT 1 FROM public.marc_admin_archived_branches_131 WHERE sucursal_id=NEW.id) THEN RAISE EXCEPTION 'Restaura la sucursal desde la papelera.'; END IF;
 ELSIF TG_TABLE_NAME='promotores' THEN
  IF NEW.activo AND (EXISTS(SELECT 1 FROM public.marc_admin_archived_users_131 WHERE usuario_id=NEW.perfil_id) OR EXISTS(SELECT 1 FROM public.marc_admin_archived_branches_131 WHERE sucursal_id=NEW.sucursal_id)) THEN RAISE EXCEPTION 'Promotor o sucursal eliminados.'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER marc_admin_archive_guard_131 BEFORE INSERT OR UPDATE ON public.perfiles FOR EACH ROW EXECUTE FUNCTION operativo_privado.marc_admin_archive_guard_131();
CREATE TRIGGER marc_admin_archive_guard_131 BEFORE INSERT OR UPDATE ON public.sucursales FOR EACH ROW EXECUTE FUNCTION operativo_privado.marc_admin_archive_guard_131();
CREATE TRIGGER marc_admin_archive_guard_131 BEFORE INSERT OR UPDATE ON public.promotores FOR EACH ROW EXECUTE FUNCTION operativo_privado.marc_admin_archive_guard_131();

CREATE FUNCTION public.marc_admin_catalog_131() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM operativo_privado.marc_admin_120();
 RETURN jsonb_build_object('users',coalesce((SELECT jsonb_agg(operativo_privado.marc_admin_user_131(p.id) ORDER BY p.nombre,p.id) FROM public.perfiles p),'[]'::jsonb),
 'branches',coalesce((SELECT jsonb_agg(operativo_privado.marc_admin_branch_131(s.id) ORDER BY s.nombre,s.id) FROM public.sucursales s),'[]'::jsonb),
 'modules',coalesce((SELECT jsonb_agg(jsonb_build_object('modulo',m.modulo,'sucursal_id',m.sucursal_id) ORDER BY m.modulo) FROM public.marc_stock_modules_130 m),'[]'::jsonb));
END $$;
CREATE FUNCTION public.marc_admin_history_131(p_offset integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE rows jsonb; total bigint;
BEGIN
 PERFORM operativo_privado.marc_admin_120();
 IF p_offset IS NULL OR p_offset<0 OR p_offset>1000000 THEN RAISE EXCEPTION 'Paginación inválida'; END IF;
 SELECT count(*) INTO total FROM (SELECT id FROM public.marc_admin_changes_131 UNION ALL SELECT id FROM public.marc_supervisor_transfers_131) r;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.fecha DESC,x.id),'[]'::jsonb) INTO rows FROM (
 SELECT id,fecha,actor_nombre,entidad,entidad_id,accion,anterior,nuevo,sesiones_revocadas FROM public.marc_admin_changes_131
 UNION ALL
 SELECT id,fecha,administrador_nombre,'usuario',supervisor_id::text,'reasignacion',jsonb_build_object('nombre',supervisor_nombre,'sucursal_id',sucursal_anterior_id,'sucursal',sucursal_anterior_nombre),jsonb_build_object('nombre',supervisor_nombre,'sucursal_id',sucursal_nueva_id,'sucursal',sucursal_nueva_nombre),sesiones_revocadas FROM public.marc_supervisor_transfers_131
 ORDER BY fecha DESC,id LIMIT 50 OFFSET p_offset) x;
 RETURN jsonb_build_object('rows',rows,'total',total);
END $$;

CREATE FUNCTION public.marc_admin_change_131(p_id uuid,p_entidad text,p_clave text,p_accion text,p_expected jsonb,p_data jsonb,p_confirm text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET lock_timeout='5s' AS $$
DECLARE aid uuid:=auth.uid(); actor public.perfiles; p public.perfiles; s public.sucursales; m public.promotores; u auth.users; v_id uuid;
 before_row jsonb; after_row jsonb; request jsonb; prior public.marc_admin_changes_131; deps jsonb;
 name_new text; email_new text; role_new public.rol_operativo; branch_new uuid; active_new boolean; code_new text; zone_new text;
 scope_changed boolean:=false; revocation boolean:=false; revoked bigint:=0; has_prom boolean:=false; detach_prom boolean:=false;
BEGIN
 PERFORM operativo_privado.marc_admin_guard_131();
 IF p_id IS NULL OR p_entidad IS NULL OR p_entidad NOT IN ('usuario','sucursal','equivalencia') OR p_accion IS NULL OR p_accion NOT IN ('editar','eliminar','restaurar') OR p_clave IS NULL OR length(p_clave)>200 OR jsonb_typeof(p_expected) IS DISTINCT FROM 'object' OR jsonb_typeof(p_data) IS DISTINCT FROM 'object' OR pg_column_size(p_expected)+pg_column_size(p_data)>20000 THEN RAISE EXCEPTION 'Solicitud inválida'; END IF;
 IF p_accion<>'eliminar' AND p_confirm IS NOT NULL THEN RAISE EXCEPTION 'Confirmación inesperada'; END IF;
 request:=jsonb_build_object('entidad',p_entidad,'clave',p_clave,'accion',p_accion,'expected',p_expected,'data',p_data,'confirm',p_confirm);
 SELECT * INTO actor FROM public.perfiles WHERE id=aid FOR SHARE;
 SELECT * INTO prior FROM public.marc_admin_changes_131 WHERE id=p_id;
 IF FOUND THEN
  IF prior.actor_id IS DISTINCT FROM aid OR prior.solicitud IS DISTINCT FROM request THEN RAISE EXCEPTION 'Identificador de operación reutilizado'; END IF;
  RETURN to_jsonb(prior)-'solicitud';
 END IF;
 -- Serializa comprobación de dependencias y cambios, incluidos procesos anteriores.
 LOCK TABLE public.perfiles,public.promotores,public.sucursales,public.tarjetas,public.inventarios,public.marc_stock_modules_130 IN SHARE ROW EXCLUSIVE MODE;
 IF p_entidad IN ('usuario','sucursal') THEN v_id:=p_clave::uuid; IF p_clave IS DISTINCT FROM v_id::text THEN RAISE EXCEPTION 'Identificador no canónico'; END IF; END IF;
 IF p_entidad='usuario' THEN
  SELECT * INTO p FROM public.perfiles WHERE id=v_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Usuario inexistente'; END IF;
  SELECT * INTO u FROM auth.users WHERE id=v_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Cuenta Auth inexistente'; END IF;
  before_row:=operativo_privado.marc_admin_user_131(v_id);
  IF before_row IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'El usuario cambió. Actualiza la lista.'; END IF;
  SELECT * INTO m FROM public.promotores WHERE perfil_id=v_id FOR UPDATE;
  has_prom:=FOUND;
  IF p_accion='editar' THEN
   IF before_row->>'eliminado_en' IS NOT NULL THEN RAISE EXCEPTION 'Restaura el usuario desde la papelera.'; END IF;
   IF (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(p_data) k) IS DISTINCT FROM ARRAY['activo','email','nombre','rol','sucursal_id']::text[] OR jsonb_typeof(p_data->'activo') IS DISTINCT FROM 'boolean' OR jsonb_typeof(p_data->'nombre') IS DISTINCT FROM 'string' OR jsonb_typeof(p_data->'email') IS DISTINCT FROM 'string' OR jsonb_typeof(p_data->'rol') IS DISTINCT FROM 'string' OR jsonb_typeof(p_data->'sucursal_id') NOT IN ('string','null') THEN RAISE EXCEPTION 'Campos de usuario inválidos'; END IF;
   name_new:=btrim(p_data->>'nombre'); email_new:=lower(btrim(p_data->>'email')); role_new:=(p_data->>'rol')::public.rol_operativo; branch_new:=(p_data->>'sucursal_id')::uuid; active_new:=(p_data->>'activo')::boolean;
   IF length(name_new) NOT BETWEEN 1 AND 150 OR length(email_new) NOT BETWEEN 3 AND 254 OR email_new !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN RAISE EXCEPTION 'Nombre o correo inválido'; END IF;
   IF role_new='administrador' AND p.rol<>'administrador' THEN branch_new:=NULL; END IF;
   IF role_new='administrador' AND p.rol='administrador' AND branch_new IS DISTINCT FROM p.sucursal_id THEN RAISE EXCEPTION 'La cuenta administrativa conserva su adscripción'; END IF;
   IF v_id=aid AND (role_new IS DISTINCT FROM p.rol OR active_new IS DISTINCT FROM p.activo OR email_new IS DISTINCT FROM lower(u.email)) THEN RAISE EXCEPTION 'No puedes cambiar tu propio correo, rol ni estado' USING ERRCODE='42501'; END IF;
   IF role_new<>'administrador' AND (branch_new IS NULL OR NOT EXISTS(SELECT 1 FROM public.sucursales b WHERE b.id=branch_new AND (b.activa OR (NOT active_new AND branch_new=p.sucursal_id)) AND (NOT EXISTS(SELECT 1 FROM public.marc_admin_archived_branches_131 WHERE sucursal_id=b.id) OR (NOT active_new AND branch_new=p.sucursal_id)))) THEN RAISE EXCEPTION 'Selecciona una sucursal de destino activa'; END IF;
   scope_changed:=role_new IS DISTINCT FROM p.rol OR branch_new IS DISTINCT FROM p.sucursal_id OR active_new IS DISTINCT FROM p.activo;
   detach_prom:=has_prom AND (role_new IS DISTINCT FROM p.rol OR branch_new IS DISTINCT FROM p.sucursal_id);
   IF detach_prom AND EXISTS(SELECT 1 FROM public.tarjetas WHERE promotor_id=m.id AND estado='asignada') THEN RAISE EXCEPTION 'Devuelve las tarjetas asignadas antes de cambiar el rol o sucursal.'; END IF;
   IF p.rol='administrador' AND p.activo AND (role_new<>'administrador' OR NOT active_new) AND NOT EXISTS(SELECT 1 FROM public.perfiles WHERE id<>v_id AND rol='administrador' AND activo) THEN RAISE EXCEPTION 'Debe permanecer un administrador activo'; END IF;
   IF p.rol='promotor' AND NOT has_prom THEN RAISE EXCEPTION 'Perfil promotor sin identidad operativa. Revisa sus datos antes de editar.'; END IF;
   -- Correo directo SOLO para cuentas locales de correo, sin modificar contraseñas.
   IF email_new IS DISTINCT FROM lower(u.email) THEN
    LOCK TABLE auth.users,auth.identities,auth.one_time_tokens IN SHARE ROW EXCLUSIVE MODE;
    IF u.is_sso_user OR u.is_anonymous OR u.deleted_at IS NOT NULL OR u.email_confirmed_at IS NULL OR u.email IS NULL OR (SELECT count(*) FROM auth.identities WHERE user_id=v_id)<>1 OR NOT EXISTS(SELECT 1 FROM auth.identities WHERE user_id=v_id AND provider='email' AND lower(identity_data->>'email')=lower(u.email)) THEN RAISE EXCEPTION 'Cambio de correo solo para cuentas locales confirmadas con identidad de correo única.'; END IF;
    IF EXISTS(SELECT 1 FROM auth.users WHERE id<>v_id AND lower(email)=email_new) OR EXISTS(SELECT 1 FROM auth.identities WHERE user_id<>v_id AND email=email_new) THEN RAISE EXCEPTION 'El correo ya está registrado.'; END IF;
    UPDATE auth.users SET email=email_new,email_confirmed_at=clock_timestamp(),email_change='',email_change_token_new='',email_change_token_current='',email_change_confirm_status=0,email_change_sent_at=NULL,confirmation_token='',confirmation_sent_at=NULL,recovery_token='',recovery_sent_at=NULL,reauthentication_token='',reauthentication_sent_at=NULL,raw_user_meta_data=CASE WHEN raw_user_meta_data ? 'email' THEN jsonb_set(raw_user_meta_data,'{email}',to_jsonb(email_new)) ELSE raw_user_meta_data END,updated_at=clock_timestamp() WHERE id=v_id;
    UPDATE auth.identities SET identity_data=jsonb_set(jsonb_set(identity_data,'{email}',to_jsonb(email_new)),'{email_verified}','true'::jsonb),updated_at=clock_timestamp() WHERE user_id=v_id AND provider='email';
    DELETE FROM auth.one_time_tokens WHERE user_id=v_id;
    IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=v_id AND email=email_new) OR NOT EXISTS(SELECT 1 FROM auth.identities WHERE user_id=v_id AND provider='email' AND email=email_new) THEN RAISE EXCEPTION 'Correo no confirmado en Auth'; END IF;
    revocation:=true;
   END IF;
   -- La antigua identidad operativa permanece en su sucursal para conservar reportes y FKs.
   IF detach_prom THEN UPDATE public.promotores SET perfil_id=NULL,activo=false,fecha_baja=coalesce(fecha_baja,greatest(current_date,fecha_alta)) WHERE id=m.id; END IF;
   UPDATE public.perfiles SET nombre=name_new,rol=role_new,sucursal_id=branch_new,activo=active_new,actualizado_en=now() WHERE id=v_id;
   IF role_new='promotor' AND (NOT has_prom OR detach_prom) THEN
    INSERT INTO public.promotores(perfil_id,sucursal_id,nombre,activo,fecha_baja) VALUES(v_id,branch_new,name_new,active_new,CASE WHEN active_new THEN NULL ELSE current_date END);
   ELSIF has_prom AND NOT detach_prom THEN
    UPDATE public.promotores SET nombre=name_new,activo=active_new,fecha_baja=CASE WHEN active_new THEN NULL ELSE coalesce(fecha_baja,greatest(current_date,fecha_alta)) END WHERE id=m.id;
   END IF;
   revocation:=revocation OR scope_changed;
  ELSIF p_accion='eliminar' THEN
   IF p.rol='administrador' OR v_id=aid OR before_row->>'eliminado_en' IS NOT NULL THEN RAISE EXCEPTION 'No se puede eliminar esta cuenta'; END IF;
   IF p_confirm IS DISTINCT FROM p.nombre OR p_data<>'{}'::jsonb THEN RAISE EXCEPTION 'Escribe exactamente el nombre del usuario'; END IF;
   IF has_prom AND EXISTS(SELECT 1 FROM public.tarjetas WHERE promotor_id=m.id AND estado='asignada') THEN RAISE EXCEPTION 'Devuelve las tarjetas asignadas antes de eliminar.'; END IF;
   UPDATE public.perfiles SET activo=false,actualizado_en=now() WHERE id=v_id;
   UPDATE public.promotores SET activo=false,fecha_baja=coalesce(fecha_baja,greatest(current_date,fecha_alta)) WHERE perfil_id=v_id;
   INSERT INTO public.marc_admin_archived_users_131(usuario_id,eliminado_por,nombre) VALUES(v_id,aid,p.nombre);
   scope_changed:=true; revocation:=true;
  ELSE
   IF p_data<>'{}'::jsonb OR before_row->>'eliminado_en' IS NULL OR p.activo OR p.rol='administrador' THEN RAISE EXCEPTION 'Usuario no recuperable desde papelera'; END IF;
   DELETE FROM public.marc_admin_archived_users_131 WHERE usuario_id=v_id;
   -- Permanece inactivo hasta una activación posterior y explícita.
   scope_changed:=true; revocation:=true;
  END IF;
  IF revocation THEN revoked:=operativo_privado.marc_admin_revoke_131(v_id); END IF;
  after_row:=operativo_privado.marc_admin_user_131(v_id);
 ELSIF p_entidad='sucursal' THEN
  SELECT * INTO s FROM public.sucursales WHERE id=v_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Sucursal inexistente'; END IF;
  before_row:=operativo_privado.marc_admin_branch_131(v_id);
  IF before_row IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'La sucursal cambió. Actualiza la lista.'; END IF;
  deps:=operativo_privado.marc_admin_branch_dependencies_131(v_id);
  IF p_accion='editar' THEN
   IF before_row->>'eliminado_en' IS NOT NULL THEN RAISE EXCEPTION 'Restaura la sucursal desde la papelera.'; END IF;
   IF (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(p_data) k) IS DISTINCT FROM ARRAY['activa','codigo','nombre','zona_horaria']::text[] OR jsonb_typeof(p_data->'activa') IS DISTINCT FROM 'boolean' OR jsonb_typeof(p_data->'codigo') IS DISTINCT FROM 'string' OR jsonb_typeof(p_data->'nombre') IS DISTINCT FROM 'string' OR jsonb_typeof(p_data->'zona_horaria') IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'Campos de sucursal inválidos'; END IF;
   name_new:=btrim(p_data->>'nombre');code_new:=btrim(p_data->>'codigo');zone_new:=btrim(p_data->>'zona_horaria');active_new:=(p_data->>'activa')::boolean;
   IF length(name_new) NOT BETWEEN 1 AND 150 OR length(code_new) NOT BETWEEN 1 AND 100 OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=zone_new) THEN RAISE EXCEPTION 'Nombre, código o zona horaria inválidos'; END IF;
   IF EXISTS(SELECT 1 FROM public.sucursales WHERE id<>v_id AND lower(codigo)=lower(code_new)) THEN RAISE EXCEPTION 'Código de sucursal duplicado'; END IF;
   IF s.activa AND NOT active_new AND ((deps->>'usuarios_activos')::bigint>0 OR (deps->>'promotores_activos')::bigint>0) THEN RAISE EXCEPTION 'Reasigna o desactiva primero los usuarios y promotores activos: %',deps; END IF;
   UPDATE public.sucursales SET nombre=name_new,codigo=code_new,zona_horaria=zone_new,activa=active_new WHERE id=v_id;
  ELSIF p_accion='eliminar' THEN
   IF before_row->>'eliminado_en' IS NOT NULL OR p_confirm IS DISTINCT FROM s.nombre OR p_data<>'{}'::jsonb THEN RAISE EXCEPTION 'Escribe exactamente el nombre de la sucursal'; END IF;
   IF EXISTS(SELECT 1 FROM jsonb_each_text(deps) d WHERE d.value::bigint>0) THEN RAISE EXCEPTION 'Resuelve las dependencias de la sucursal: %',deps; END IF;
   UPDATE public.sucursales SET activa=false WHERE id=v_id;
   INSERT INTO public.marc_admin_archived_branches_131(sucursal_id,eliminado_por,nombre) VALUES(v_id,aid,s.nombre);
   -- No borra equivalencias; el importador exige sucursal activa y deja de usarlas.
  ELSE
   IF before_row->>'eliminado_en' IS NULL OR s.activa OR p_data<>'{}'::jsonb THEN RAISE EXCEPTION 'Sucursal no recuperable desde papelera'; END IF;
   DELETE FROM public.marc_admin_archived_branches_131 WHERE sucursal_id=v_id;
  END IF;
  after_row:=operativo_privado.marc_admin_branch_131(v_id);
 ELSE
  IF p_accion<>'editar' OR (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(p_data) k) IS DISTINCT FROM ARRAY['sucursal_id']::text[] THEN RAISE EXCEPTION 'Solo se permite editar la equivalencia existente'; END IF;
  SELECT jsonb_build_object('modulo',modulo,'sucursal_id',sucursal_id) INTO before_row FROM public.marc_stock_modules_130 WHERE modulo=p_clave FOR UPDATE;
  IF before_row IS NULL OR before_row IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'La equivalencia cambió. Actualiza la lista.'; END IF;
  branch_new:=(p_data->>'sucursal_id')::uuid;
  IF NOT EXISTS(SELECT 1 FROM public.sucursales WHERE id=branch_new AND activa) THEN RAISE EXCEPTION 'Selecciona una sucursal activa'; END IF;
  UPDATE public.marc_stock_modules_130 SET sucursal_id=branch_new WHERE modulo=p_clave;
  after_row:=jsonb_build_object('modulo',p_clave,'sucursal_id',branch_new);
 END IF;
 IF before_row IS NOT DISTINCT FROM after_row THEN RAISE EXCEPTION 'No se detectaron cambios'; END IF;
 INSERT INTO public.marc_admin_changes_131(id,actor_id,actor_nombre,entidad,entidad_id,accion,anterior,nuevo,solicitud,sesiones_revocadas,cambio_ambito) VALUES(p_id,aid,actor.nombre,p_entidad,p_clave,p_accion,before_row,after_row,request,revoked,scope_changed) RETURNING * INTO prior;
 RETURN to_jsonb(prior)-'solicitud';
END $$;

-- Restringe las antiguas vías de edición que no aplican todas las reglas nuevas.
REVOKE EXECUTE ON FUNCTION public.gestionar_perfil(uuid,text,boolean) FROM PUBLIC,anon,authenticated,service_role;
REVOKE EXECUTE ON FUNCTION public.marc_transfer_supervisor_131(uuid,uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
-- Conserva las funciones y datos de la bitácora anterior, ahora accesibles desde la nueva.

REVOKE ALL ON FUNCTION operativo_privado.marc_scope_after_131(uuid),operativo_privado.marc_admin_guard_131(),operativo_privado.marc_admin_user_131(uuid),operativo_privado.marc_admin_branch_131(uuid),operativo_privado.marc_admin_branch_dependencies_131(uuid),operativo_privado.marc_admin_revoke_131(uuid),operativo_privado.marc_admin_archive_guard_131() FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.marc_admin_catalog_131(),public.marc_admin_history_131(integer),public.marc_admin_change_131(uuid,text,text,text,jsonb,jsonb,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.marc_admin_catalog_131(),public.marc_admin_history_131(integer),public.marc_admin_change_131(uuid,text,text,text,jsonb,jsonb,text) TO authenticated;

-- Lectura histórica de Excel: no abre permisos de carga en sucursales inactivas.
CREATE POLICY marc_admin_archived_excel_read_131 ON storage.objects FOR SELECT TO authenticated USING (bucket_id='inventarios' AND operativo_privado.es_admin() AND (SELECT operativo_privado.marc_session_valid_126()));
ALTER VIEW public.metas_efectivas SET (security_invoker=true);

-- Reemplazos derivados de las definiciones del diagnóstico real.
CREATE OR REPLACE FUNCTION public.marc_backup_snapshot_120()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE datos jsonb; archivos jsonb;
BEGIN
  PERFORM operativo_privado.marc_admin_120();
  SELECT jsonb_build_object(
    'registros', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.registros t),
    'folios_reservados', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.folios_reservados t),
    'incidencias', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.incidencias t),
    'tarjetas', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.tarjetas t),
    'movimientos_tarjetas', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.movimientos_tarjetas t),
    'inventarios', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.inventarios t),
    'inventario_filas', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.inventario_filas t),
    'historial_cambios', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.historial_cambios t),
    'operaciones_sincronizadas', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.operaciones_sincronizadas t),
    'marc_tutorial_attempts', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.marc_tutorial_attempts t),
    'marc_tutorial_requests', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.marc_tutorial_requests t),
    'marc_stock_modules_130', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.marc_stock_modules_130 t),
    'marc_stock_imports_130', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.marc_stock_imports_130 t),
    'marc_supervisor_transfers_131', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.marc_supervisor_transfers_131 t),
    'marc_admin_changes_131', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.marc_admin_changes_131 t),
    'marc_admin_archived_users_131', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.marc_admin_archived_users_131 t),
    'marc_admin_archived_branches_131', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.marc_admin_archived_branches_131 t)
  ) INTO datos;
  SELECT coalesce(jsonb_agg(jsonb_build_object('path',o.name,'object_id',o.id,'updated_at',o.updated_at,'size',o.metadata->>'size') ORDER BY o.name),'[]'::jsonb)
    INTO archivos FROM storage.objects o WHERE o.bucket_id='inventarios';
  IF EXISTS (SELECT 1 FROM public.inventarios i WHERE NOT EXISTS (SELECT 1 FROM storage.objects o WHERE o.bucket_id='inventarios' AND o.name=i.ruta_archivo)) THEN
    RAISE EXCEPTION 'Existe un inventario sin archivo original. Respaldo incompleto.';
  END IF;
  RETURN jsonb_build_object('format','marc-operativo-v1','tables',datos,'files',archivos);
END;
$function$;

CREATE OR REPLACE FUNCTION public.marc_restore_rehearsal_125(p_snapshot jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  targets text[] := ARRAY['registros','folios_reservados','incidencias','tarjetas','movimientos_tarjetas','inventarios','inventario_filas','historial_cambios','operaciones_sincronizadas','marc_tutorial_attempts','marc_tutorial_requests'];
  preserved constant text[] := ARRAY['perfiles','promotores','sucursales'];
  t text; ref text; cols text; source_cols text; sid uuid; actual jsonb; counts jsonb:='{}'::jsonb;
  fk record; child_cols text; parent_cols text; file_count integer; missing_count integer; orphan_count integer;
BEGIN
  PERFORM operativo_privado.marc_admin_120();
  sid:=nullif(auth.jwt()->>'session_id','')::uuid;
  IF sid IS NULL OR NOT EXISTS(SELECT 1 FROM auth.sessions WHERE id=sid AND user_id=auth.uid()) THEN
    RAISE EXCEPTION 'Sesión no vigente' USING ERRCODE='42501';
  END IF;
  IF p_snapshot IS NULL OR pg_catalog.pg_column_size(p_snapshot)>50*1024*1024 OR
     p_snapshot->>'format' IS DISTINCT FROM 'marc-operativo-v1' OR
     jsonb_typeof(p_snapshot->'tables') IS DISTINCT FROM 'object' OR
     jsonb_typeof(p_snapshot->'files') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Formato de respaldo no válido' USING ERRCODE='22023';
  END IF;
  IF p_snapshot->'tables' ? 'marc_admin_changes_131' THEN targets:=targets||ARRAY['marc_stock_modules_130','marc_stock_imports_130','marc_supervisor_transfers_131','marc_admin_changes_131','marc_admin_archived_users_131','marc_admin_archived_branches_131']; END IF;
  IF (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(p_snapshot->'tables') AS k)
     IS DISTINCT FROM (SELECT array_agg(k ORDER BY k) FROM unnest(targets) AS k) THEN
    RAISE EXCEPTION 'Conjunto de tablas incompatible';
  END IF;
  -- Serialize with operational writes while reading preserved entities. No maintenance window is opened.
  PERFORM pg_catalog.pg_advisory_xact_lock(12004,124);
  IF EXISTS(SELECT 1 FROM operativo_privado.marc_backup_window_124 WHERE singleton AND expires_at>clock_timestamp()) THEN
    RAISE EXCEPTION 'Hay un respaldo protegido en curso. Reintenta al finalizar.' USING ERRCODE='55000';
  END IF;
  -- Fail closed if a later schema adds an outbound FK that this rehearsal cannot model.
  IF EXISTS(SELECT 1 FROM pg_constraint c JOIN pg_class a ON a.oid=c.conrelid JOIN pg_namespace n ON n.oid=a.relnamespace
    JOIN pg_class b ON b.oid=c.confrelid JOIN pg_namespace bn ON bn.oid=b.relnamespace
    WHERE c.contype='f' AND n.nspname='public' AND a.relname=ANY(targets)
      AND (bn.nspname<>'public' OR NOT(b.relname=ANY(targets||preserved)))) THEN
    RAISE EXCEPTION 'El esquema tiene referencias externas no contempladas. Actualiza el motor de restauración.';
  END IF;
  -- Do not reuse caller-created temporary objects. CREATE fails on collision.
  FOREACH t IN ARRAY targets||preserved LOOP
    EXECUTE format('CREATE TEMP TABLE %I (LIKE public.%I INCLUDING DEFAULTS INCLUDING GENERATED INCLUDING CONSTRAINTS INCLUDING INDEXES) ON COMMIT DROP','marc125_'||t,t);
    SELECT string_agg(format('%I',a.attname),',' ORDER BY a.attnum),string_agg(format('r.%I',a.attname),',' ORDER BY a.attnum)
      INTO cols,source_cols FROM pg_attribute a WHERE a.attrelid=to_regclass(format('public.%I',t)) AND a.attnum>0 AND NOT a.attisdropped AND a.attgenerated='';
    IF t=ANY(preserved) THEN
      EXECUTE format('INSERT INTO pg_temp.%I (%s) SELECT %s FROM public.%I r','marc125_'||t,cols,source_cols,t);
    ELSE
      IF jsonb_typeof(p_snapshot->'tables'->t) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Tabla inválida: %',t; END IF;
      EXECUTE format('INSERT INTO pg_temp.%I (%s) SELECT %s FROM jsonb_populate_recordset(NULL::public.%I,$1) r','marc125_'||t,cols,source_cols,t) USING p_snapshot->'tables'->t;
      EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),''[]''::jsonb) FROM pg_temp.%I r','marc125_'||t) INTO actual;
      IF actual IS DISTINCT FROM (SELECT coalesce(jsonb_agg(v ORDER BY v::text),'[]'::jsonb) FROM jsonb_array_elements(p_snapshot->'tables'->t) v) THEN
        RAISE EXCEPTION 'Las filas reconstruidas no coinciden con el respaldo: %',t;
      END IF;
      counts:=counts||jsonb_build_object(t,jsonb_array_length(actual));
    END IF;
  END LOOP;
  -- Los perfiles y las sucursales no se sobrescriben. Una papelera sólo puede recuperarse sobre entidades ya inactivas.
  IF EXISTS(SELECT 1 FROM public.marc_admin_archived_users_131 a JOIN public.promotores m ON m.perfil_id=a.usuario_id JOIN pg_temp.marc125_tarjetas t ON t.promotor_id=m.id WHERE t.estado='asignada') OR
     EXISTS(SELECT 1 FROM public.marc_admin_archived_branches_131 a JOIN pg_temp.marc125_tarjetas t ON t.sucursal_id=a.sucursal_id WHERE t.estado IN ('disponible','asignada')) OR
     EXISTS(SELECT 1 FROM public.marc_admin_archived_branches_131 a JOIN pg_temp.marc125_inventarios i ON i.sucursal_id=a.sucursal_id WHERE i.estado='abierto') THEN RAISE EXCEPTION 'El respaldo reintroduciría operaciones abiertas en entidades eliminadas'; END IF;
  IF p_snapshot->'tables' ? 'marc_admin_changes_131' THEN
   IF EXISTS(SELECT 1 FROM pg_temp.marc125_marc_admin_archived_users_131 a LEFT JOIN public.perfiles p ON p.id=a.usuario_id WHERE p.id IS NULL OR p.activo OR p.rol='administrador') OR
      EXISTS(SELECT 1 FROM pg_temp.marc125_marc_admin_archived_users_131 a JOIN public.promotores m ON m.perfil_id=a.usuario_id WHERE m.activo OR EXISTS(SELECT 1 FROM pg_temp.marc125_tarjetas t WHERE t.promotor_id=m.id AND t.estado='asignada')) OR
      EXISTS(SELECT 1 FROM pg_temp.marc125_marc_admin_archived_branches_131 a LEFT JOIN public.sucursales s ON s.id=a.sucursal_id WHERE s.id IS NULL OR s.activa OR EXISTS(SELECT 1 FROM public.perfiles p WHERE p.sucursal_id=a.sucursal_id AND p.activo) OR EXISTS(SELECT 1 FROM public.promotores m WHERE m.sucursal_id=a.sucursal_id AND m.activo) OR EXISTS(SELECT 1 FROM pg_temp.marc125_tarjetas t WHERE t.sucursal_id=a.sucursal_id AND t.estado IN ('disponible','asignada')) OR EXISTS(SELECT 1 FROM pg_temp.marc125_inventarios i WHERE i.sucursal_id=a.sucursal_id AND i.estado='abierto')) THEN
    RAISE EXCEPTION 'La papelera del respaldo contradice el estado operativo vigente. No se sobrescriben perfiles ni sucursales.';
   END IF;
  END IF;
  -- LIKE does not copy foreign keys. Add them after loading to cover cycles without changing live constraints.
  FOR fk IN SELECT c.oid,c.conname,c.conrelid,c.confrelid,c.conkey,c.confkey,c.confmatchtype,a.relname AS child,b.relname AS parent
    FROM pg_constraint c JOIN pg_class a ON a.oid=c.conrelid JOIN pg_namespace n ON n.oid=a.relnamespace
    JOIN pg_class b ON b.oid=c.confrelid WHERE c.contype='f' AND n.nspname='public' AND a.relname=ANY(targets)
  LOOP
    SELECT string_agg(format('%I',a.attname),',' ORDER BY u.ord) INTO child_cols FROM unnest(fk.conkey) WITH ORDINALITY u(attnum,ord) JOIN pg_attribute a ON a.attrelid=fk.conrelid AND a.attnum=u.attnum;
    SELECT string_agg(format('%I',a.attname),',' ORDER BY u.ord) INTO parent_cols FROM unnest(fk.confkey) WITH ORDINALITY u(attnum,ord) JOIN pg_attribute a ON a.attrelid=fk.confrelid AND a.attnum=u.attnum;
    EXECUTE format('ALTER TABLE pg_temp.%I ADD CONSTRAINT %I FOREIGN KEY (%s) REFERENCES pg_temp.%I (%s) %s', 'marc125_'||fk.child,fk.conname,child_cols,'marc125_'||fk.parent,parent_cols,CASE WHEN fk.confmatchtype='f' THEN 'MATCH FULL' ELSE 'MATCH SIMPLE' END);
  END LOOP;
  -- Each Excel path must be unique and match the original inventoried path; orphan files are reported, not ignored.
  file_count:=jsonb_array_length(p_snapshot->'files');
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_snapshot->'files') f WHERE jsonb_typeof(f) IS DISTINCT FROM 'object' OR coalesce(f->>'path','')='' OR f->>'path' LIKE '/%' OR f->>'path' ~ '(^|/)\.\.?(/|$)') OR
    (SELECT count(DISTINCT f->>'path') FROM jsonb_array_elements(p_snapshot->'files') f)<>file_count THEN RAISE EXCEPTION 'Rutas de archivos inválidas o duplicadas'; END IF;
  IF EXISTS(SELECT 1 FROM pg_temp.marc125_inventarios i WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_snapshot->'files') f WHERE f->>'path'=i.ruta_archivo)) THEN RAISE EXCEPTION 'Inventario sin archivo en el manifiesto'; END IF;
  SELECT count(*) INTO orphan_count FROM jsonb_array_elements(p_snapshot->'files') f WHERE NOT EXISTS(SELECT 1 FROM pg_temp.marc125_inventarios i WHERE i.ruta_archivo=f->>'path');
  SELECT count(*) INTO missing_count FROM jsonb_array_elements(p_snapshot->'files') f WHERE NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='inventarios' AND o.name=f->>'path');
  RETURN jsonb_build_object('rehearsal_version',5,'compatible',true,'applied',false,'counts',counts,'files',file_count,'missing_current_files',missing_count,'orphan_files',orphan_count);
END; $function$;

CREATE OR REPLACE FUNCTION operativo_privado.marc_restore_rows_128(p_snapshot jsonb, p_manifest jsonb, p_confirmation text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET lock_timeout TO '5s'
AS $function$
DECLARE
 targets text[]:=ARRAY['tarjetas','registros','folios_reservados','incidencias','movimientos_tarjetas','inventarios','inventario_filas','operaciones_sincronizadas','marc_tutorial_attempts','marc_tutorial_requests','historial_cambios'];
 audited constant text[]:=ARRAY['tarjetas','registros','folios_reservados','incidencias','movimientos_tarjetas','inventarios','inventario_filas','operaciones_sincronizadas'];
 t text; tr text; cols text; src text; n bigint; mismatch boolean; counts jsonb:='{}'; rehearsal jsonb; current_snapshot jsonb; wid uuid; aid uuid:=auth.uid(); audit_id uuid;
BEGIN
 PERFORM operativo_privado.marc_admin_120();
 IF p_confirmation IS DISTINCT FROM 'RESTAURAR MARC' THEN RAISE EXCEPTION 'Confirmación incorrecta'; END IF;
 IF p_snapshot IS NULL OR p_manifest IS NULL OR pg_column_size(p_snapshot)>50*1024*1024 OR pg_column_size(p_manifest)>1024*1024 THEN RAISE EXCEPTION 'Respaldo inválido'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(12004,124);
 PERFORM operativo_privado.marc_admin_120();
 -- Require fresh sign-in, not merely refresh of an old token.
 IF NOT EXISTS(SELECT 1 FROM auth.sessions s WHERE s.id::text=auth.jwt()->>'session_id' AND s.user_id=aid AND s.created_at>clock_timestamp()-interval '10 minutes') THEN
  RAISE EXCEPTION 'Vuelve a iniciar sesión como administrador (máximo 10 minutos antes de restaurar).' USING ERRCODE='42501'; END IF;
 IF EXISTS(SELECT 1 FROM operativo_privado.marc_backup_window_124 WHERE singleton AND expires_at>clock_timestamp()) THEN RAISE EXCEPTION 'Hay un respaldo protegido en curso'; END IF;
 wid:=nullif(p_manifest->>'maintenance_window','')::uuid;
 IF NOT EXISTS(SELECT 1 FROM operativo_privado.marc_seals_127 s WHERE s.window_id=wid
  AND s.snapshot_hash=pg_catalog.sha256(pg_catalog.convert_to(p_snapshot::text,'UTF8'))
  AND s.manifest_hash=pg_catalog.sha256(pg_catalog.convert_to(p_manifest::text,'UTF8'))
  AND EXISTS(SELECT 1 FROM operativo_privado.marc_maintenance_audit_124 a WHERE a.window_id=wid AND a.event='finalizado' AND a.actor_id=s.actor_id))
 THEN RAISE EXCEPTION 'Respaldo sin sello válido de servidor. Utiliza un respaldo protegido de pre.7 o posterior.'; END IF;
 -- Prevent uncoordinated mutations during relational reconstruction. Short lock timeout avoids long disruption.
 LOCK TABLE public.perfiles,public.promotores,public.sucursales,public.configuracion_global,public.configuracion_sucursal,public.metas_semanales IN SHARE MODE;
 LOCK TABLE public.tarjetas,public.registros,public.folios_reservados,public.incidencias,public.movimientos_tarjetas,public.inventarios,public.inventario_filas,public.operaciones_sincronizadas,public.marc_tutorial_attempts,public.marc_tutorial_requests,public.historial_cambios IN SHARE ROW EXCLUSIVE MODE;
 IF p_snapshot->'tables' ? 'marc_admin_changes_131' THEN targets:=targets||ARRAY['marc_stock_modules_130','marc_stock_imports_130','marc_supervisor_transfers_131','marc_admin_changes_131','marc_admin_archived_users_131','marc_admin_archived_branches_131']; END IF;
 LOCK TABLE public.marc_stock_modules_130,public.marc_stock_imports_130,public.marc_supervisor_transfers_131,public.marc_admin_changes_131,public.marc_admin_archived_users_131,public.marc_admin_archived_branches_131 IN SHARE ROW EXCLUSIVE MODE;
 current_snapshot:=public.marc_backup_snapshot_120();
 PERFORM operativo_privado.marc_restore_check_files_128(p_manifest,true);
 rehearsal:=public.marc_restore_rehearsal_125(p_snapshot);
 IF rehearsal->>'compatible' IS DISTINCT FROM 'true' OR rehearsal->>'orphan_files' IS DISTINCT FROM '0' THEN RAISE EXCEPTION 'Respaldo incompatible o contiene archivos huérfanos'; END IF;
 -- Current rows must be an exact subset of the backup. Existing data are never replaced.
 FOREACH t IN ARRAY targets LOOP
  EXECUTE format('SELECT EXISTS(SELECT to_jsonb(r) FROM public.%I r EXCEPT SELECT to_jsonb(r) FROM pg_temp.%I r)',t,'marc125_'||t) INTO mismatch;
  IF mismatch THEN RAISE EXCEPTION 'Hay datos actuales nuevos o distintos en %. No se sobrescribió nada.',t; END IF;
  counts:=counts||jsonb_build_object(t,jsonb_array_length(p_snapshot->'tables'->t)-jsonb_array_length(current_snapshot->'tables'->t));
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM jsonb_each_text(counts) x WHERE x.value::bigint>0) THEN
  INSERT INTO operativo_privado.marc_restore_audit_127(actor_id,window_id,inserted) VALUES(aid,wid,counts) RETURNING id INTO audit_id;
  RETURN jsonb_build_object('applied',true,'inserted',counts,'audit_id',audit_id,'unchanged',true);
 END IF;
 -- All FKs still enforced. Only the known derived-row and audit triggers are paused transactionally.
 -- Abort on unexpected disabled or new user triggers rather than silently bypassing them.
 IF EXISTS(SELECT 1 FROM pg_trigger g JOIN pg_class c ON c.oid=g.tgrelid JOIN pg_namespace nsp ON nsp.oid=c.relnamespace
  WHERE nsp.nspname='public' AND c.relname=ANY(targets) AND NOT g.tgisinternal AND
  (g.tgenabled<>'O' OR NOT(g.tgname='marc_guard_write_124' OR (c.relname=ANY(audited) AND g.tgname='auditoria') OR (c.relname='registros' AND g.tgname IN ('reserva_folio','expediente_registro')))))
 THEN RAISE EXCEPTION 'Triggers no contemplados; actualiza el motor de restauración'; END IF;
 FOREACH t IN ARRAY audited LOOP
  EXECUTE format('ALTER TABLE public.%I DISABLE TRIGGER auditoria',t);
 END LOOP;
 ALTER TABLE public.registros DISABLE TRIGGER reserva_folio;
 ALTER TABLE public.registros DISABLE TRIGGER expediente_registro;
 -- Track new cards only. Temporarily stage consumed cards without the cyclic registro reference.
 CREATE TEMP TABLE marc127_new_cards ON COMMIT DROP AS SELECT r.id FROM pg_temp.marc125_tarjetas r WHERE NOT EXISTS(SELECT 1 FROM public.tarjetas l WHERE l.id=r.id);
 FOREACH t IN ARRAY targets LOOP
  SELECT string_agg(format('%I',a.attname),',' ORDER BY a.attnum),string_agg(
   CASE WHEN t='tarjetas' AND a.attname='estado' THEN 'CASE WHEN r.estado=''consumida'' THEN CASE WHEN r.promotor_id IS NULL THEN ''disponible''::public.estado_tarjeta ELSE ''asignada''::public.estado_tarjeta END ELSE r.estado END'
    WHEN t='tarjetas' AND a.attname IN ('consumida_por_registro_id','fecha_consumo') THEN 'CASE WHEN r.estado=''consumida'' THEN NULL ELSE r.'||quote_ident(a.attname)||' END'
    ELSE format('r.%I',a.attname) END,',' ORDER BY a.attnum)
  INTO cols,src FROM pg_attribute a WHERE a.attrelid=to_regclass(format('public.%I',t)) AND a.attnum>0 AND NOT a.attisdropped AND a.attgenerated='';
  EXECUTE format('INSERT INTO public.%I (%s) SELECT %s FROM pg_temp.%I r WHERE NOT EXISTS(SELECT 1 FROM public.%I l WHERE to_jsonb(l)=to_jsonb(r))',t,cols,src,'marc125_'||t,t);
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n IS DISTINCT FROM (counts->>t)::bigint THEN RAISE EXCEPTION 'Cantidad recuperada inesperada en %',t; END IF;
  IF t='registros' THEN
   UPDATE public.tarjetas l SET estado=r.estado,consumida_por_registro_id=r.consumida_por_registro_id,fecha_consumo=r.fecha_consumo
    FROM pg_temp.marc125_tarjetas r JOIN pg_temp.marc127_new_cards z ON z.id=r.id WHERE l.id=r.id AND r.estado='consumida';
  END IF;
 END LOOP;
 ALTER TABLE public.registros ENABLE TRIGGER reserva_folio;
 ALTER TABLE public.registros ENABLE TRIGGER expediente_registro;
 FOREACH t IN ARRAY audited LOOP EXECUTE format('ALTER TABLE public.%I ENABLE TRIGGER auditoria',t); END LOOP;
 IF (SELECT jsonb_object_agg(key,value) FROM jsonb_each(public.marc_backup_snapshot_120()->'tables') WHERE key=ANY(targets)) IS DISTINCT FROM (p_snapshot->'tables') THEN RAISE EXCEPTION 'Comprobación final no coincide; restauración revertida'; END IF;
 INSERT INTO operativo_privado.marc_restore_audit_127(actor_id,window_id,inserted) VALUES(aid,wid,counts) RETURNING id INTO audit_id;
 RETURN jsonb_build_object('applied',true,'inserted',counts,'audit_id',audit_id,'unchanged',false);
END $function$;

CREATE OR REPLACE FUNCTION public.marc_restore_apply_127(p_snapshot jsonb, p_manifest jsonb, p_confirmation text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET lock_timeout TO '5s'
AS $function$
BEGIN
 RETURN operativo_privado.marc_restore_rows_128(p_snapshot,p_manifest,p_confirmation);
END $function$;

CREATE OR REPLACE FUNCTION operativo_privado.marc_session_valid_126()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT coalesce(EXISTS(SELECT 1 FROM auth.sessions s CROSS JOIN operativo_privado.marc_epoch_126 e
 WHERE e.singleton AND s.id::text=auth.jwt()->>'session_id' AND s.user_id=auth.uid()
 AND EXISTS(SELECT 1 FROM public.perfiles p WHERE p.id=auth.uid() AND p.activo AND (p.rol='administrador' OR EXISTS(SELECT 1 FROM public.sucursales b WHERE b.id=p.sucursal_id AND b.activa)))
 AND s.created_at>e.sessions_after AND (s.not_after IS NULL OR s.not_after>statement_timestamp())),false)
$function$;

CREATE OR REPLACE FUNCTION public.marc_epoch_state_126()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE e operativo_privado.marc_epoch_126;
BEGIN
 PERFORM operativo_privado.marc_require_session_126();
 PERFORM operativo_privado.actor();
 SELECT * INTO STRICT e FROM operativo_privado.marc_epoch_126 WHERE singleton;
 RETURN jsonb_build_object('records',e.records_generation,'tutorials',e.tutorials_generation,'scope_after',operativo_privado.marc_scope_after_131(auth.uid()));
END $function$;

CREATE OR REPLACE FUNCTION public.alta_tarjeta(p_sucursal uuid, p_prefijo text, p_terminacion text)
 RETURNS tarjetas
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.perfiles; t public.tarjetas;
begin
 PERFORM operativo_privado.marc_write_allowed_124();
 a=operativo_privado.actor();
 if not operativo_privado.gestiona(p_sucursal) or not exists(select 1 from public.sucursales where id=p_sucursal and activa) then raise exception 'Acceso no autorizado' using errcode='42501'; end if;
 insert into public.tarjetas(sucursal_id,prefijo,terminacion) values(p_sucursal,p_prefijo,p_terminacion) returning * into t;
 insert into public.movimientos_tarjetas(tarjeta_id,tipo_movimiento,sucursal_destino_id,realizado_por) values(t.id,'alta',p_sucursal,a.id);
 return t;
end $function$;

CREATE OR REPLACE FUNCTION public.transferir_tarjeta(p_tarjeta uuid, p_destino uuid, p_comentario text DEFAULT ''::text)
 RETURNS tarjetas
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.perfiles; t public.tarjetas; origen uuid;
begin
 PERFORM operativo_privado.marc_write_allowed_124();
 a=operativo_privado.actor(); if a.rol<>'administrador' then raise exception 'Acceso no autorizado' using errcode='42501'; end if;
 select * into t from public.tarjetas where id=p_tarjeta for update;
 if not found or t.estado<>'disponible' or t.sucursal_id=p_destino or not exists(select 1 from public.sucursales where id=p_destino and activa) then raise exception 'Transferencia no válida'; end if;
 origen=t.sucursal_id;
 update public.tarjetas set sucursal_id=p_destino where id=t.id returning * into t;
 insert into public.movimientos_tarjetas(tarjeta_id,tipo_movimiento,sucursal_origen_id,sucursal_destino_id,realizado_por,comentario) values(t.id,'transferencia',origen,p_destino,a.id,coalesce(p_comentario,''));
 return t;
end $function$;

CREATE OR REPLACE FUNCTION public.asignar_tarjeta(p_tarjeta uuid, p_promotor uuid)
 RETURNS tarjetas
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.perfiles; t public.tarjetas; m public.promotores;
begin
 PERFORM operativo_privado.marc_write_allowed_124();
 a=operativo_privado.actor();
 select * into t from public.tarjetas where id=p_tarjeta for update;
 if not found or not operativo_privado.gestiona(t.sucursal_id) or not exists(select 1 from public.sucursales where id=t.sucursal_id and activa) then raise exception 'Acceso no autorizado' using errcode='42501'; end if;
 select * into m from public.promotores where id=p_promotor and activo for share;
 if not found or m.sucursal_id<>t.sucursal_id or t.estado<>'disponible' then raise exception 'Tarjeta o promotor no disponible'; end if;
 update public.tarjetas set estado='asignada',promotor_id=m.id,fecha_asignacion=now() where id=t.id returning * into t;
 insert into public.movimientos_tarjetas(tarjeta_id,tipo_movimiento,sucursal_origen_id,sucursal_destino_id,promotor_destino_id,realizado_por) values(t.id,'asignacion',t.sucursal_id,t.sucursal_id,m.id,a.id);
 return t;
end $function$;

CREATE OR REPLACE FUNCTION public.asignar_tarjetas_lote(p_tarjetas uuid[], p_promotor uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.perfiles; m public.promotores; t_id uuid; n integer;
begin
 PERFORM operativo_privado.marc_write_allowed_124();
 a:=operativo_privado.actor();
 n:=coalesce(cardinality(p_tarjetas),0);
 if n<1 or n>500 or array_ndims(p_tarjetas)<>1 or array_position(p_tarjetas,null::uuid) is not null then raise exception 'Selecciona entre 1 y 500 tarjetas válidas'; end if;
 if (select count(distinct x) from unnest(p_tarjetas) as u(x))<>n then raise exception 'Tarjetas repetidas en la selección'; end if;
 select * into m from public.promotores where id=p_promotor and activo;
 if not found or not operativo_privado.gestiona(m.sucursal_id) or not exists(select 1 from public.sucursales where id=m.sucursal_id and activa) then raise exception 'Promotor o sucursal no autorizado' using errcode='42501'; end if;
 for t_id in select x from unnest(p_tarjetas) as u(x) order by x loop
  perform public.asignar_tarjeta(t_id,p_promotor);
 end loop;
 return n;
end $function$;

CREATE OR REPLACE FUNCTION public.crear_registro(p_operacion uuid, p_dispositivo uuid, p_fecha_captura timestamp with time zone, p_datos jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.perfiles; s uuid; m public.promotores; r public.registros; t public.tarjetas; o public.operaciones_sincronizadas;
 tipo public.tipo_registro; origen public.origen_registro; f text; tid uuid; rid uuid; mensaje text; codigo text; resultado_estado public.estado_sync; fecha date;
begin
 PERFORM operativo_privado.marc_write_allowed_124();
 PERFORM operativo_privado.marc_require_generation_126('records',p_datos->>'_marc_generation');
 p_datos:=p_datos-'_marc_generation';
 a=operativo_privado.actor();
 IF p_fecha_captura<=operativo_privado.marc_scope_after_131(a.id) THEN RAISE EXCEPTION 'MARC_CAPTURA_AMBITO_ANTERIOR: conserva la captura y solicita revisión al administrador' USING ERRCODE='42501'; END IF;
 if p_operacion is null or p_dispositivo is null or p_fecha_captura is null or jsonb_typeof(p_datos) is distinct from 'object' then raise exception 'Solicitud inválida'; end if;
 if exists(select 1 from jsonb_object_keys(p_datos) k where k not in ('promotor_id','sucursal_id','fecha','tipo','folio','tarjeta_id','origen_captura','plan_dental','plan_cero','activacion_app','dinamica','incidencia','comentario')) then raise exception 'Campos no autorizados'; end if;
 if exists(select 1 from jsonb_each(p_datos) e where jsonb_typeof(e.value) in ('object','array')) then raise exception 'Solo se permiten valores escalares'; end if;
 s=(p_datos->>'sucursal_id')::uuid;
 if s is null or not operativo_privado.en_sucursal(s) or not exists(select 1 from public.sucursales where id=s and activa) then raise exception 'Acceso no autorizado' using errcode='42501'; end if;
 select * into m from public.promotores where id=(p_datos->>'promotor_id')::uuid and activo and sucursal_id=s for share;
 if not found or not operativo_privado.puede_registro(s,m.id) then raise exception 'Acceso no autorizado' using errcode='42501'; end if;
 insert into public.operaciones_sincronizadas(id,usuario_id,sucursal_id,dispositivo_id,datos_operacion,fecha_captura)
 values(p_operacion,a.id,s,p_dispositivo,p_datos,p_fecha_captura) on conflict(id) do nothing;
 select * into o from public.operaciones_sincronizadas where id=p_operacion for update;
 if o.usuario_id<>a.id or o.sucursal_id<>s or o.dispositivo_id<>p_dispositivo or o.datos_operacion<>p_datos or o.fecha_captura<>p_fecha_captura then raise exception 'Identificador de operación ya utilizado' using errcode='42501'; end if;
 if o.estado<>'procesando' then return jsonb_build_object('estado',o.estado,'registro_id',o.registro_id,'motivo',o.motivo_conflicto); end if;
 begin
  tipo=(p_datos->>'tipo')::public.tipo_registro; origen=coalesce((p_datos->>'origen_captura')::public.origen_registro,'normal');
  f=nullif(btrim(p_datos->>'folio'),''); tid=nullif(p_datos->>'tarjeta_id','')::uuid; fecha=(p_datos->>'fecha')::date; rid=gen_random_uuid();
  if tipo is null or fecha is null then raise exception 'DATOS_INVALIDOS'; end if;
  if (origen='rapido_promotor' and (a.rol<>'promotor' or tipo not in ('Garantizada','Rechazada','Blacklist') or tid is not null)) or (origen='rapido_supervisor' and (a.rol='promotor' or tipo<>'Pendiente')) then raise exception 'CAPTURA_INVALIDA'; end if;
  if tipo='Pendiente' and (origen<>'rapido_supervisor' or f is not null) then raise exception 'CAPTURA_INVALIDA'; end if;
  if tipo<>'Pendiente' and (f is null or f !~ '^[0-9]{8}$') then raise exception 'DATOS_INVALIDOS'; end if;
  if a.rol='promotor' and origen='normal' and (tipo not in ('Regular','Garantizada') or tid is null) then raise exception 'TARJETA_REQUERIDA'; end if;
  if tid is not null then
   if tipo not in ('Regular','Garantizada') then raise exception 'CAPTURA_INVALIDA'; end if;
   t=operativo_privado.validar_tarjeta(tid,s,m.id);
  end if;
  insert into public.registros(id,fecha,tipo,folio,folio_temporal,sucursal_id,promotor_id,tarjeta_id,codigo_corto,codigo_completo,plan_dental,plan_cero,activacion_app,dinamica,incidencia,comentario,origen_captura,creado_por,actualizado_por)
  values(rid,fecha,tipo,f,case when tipo='Pendiente' then 'TMP-'||upper(replace(rid::text,'-','')) end,s,m.id,tid,t.terminacion,t.codigo_completo,
   tipo in ('Regular','Garantizada') and coalesce((p_datos->>'plan_dental')::boolean,false) and origen<>'rapido_promotor',
   tipo in ('Regular','Garantizada') and coalesce((p_datos->>'plan_cero')::boolean,false) and origen<>'rapido_promotor',tid is not null,false,false,
   coalesce(p_datos->>'comentario',''),origen,a.id,a.id) returning * into r;
  if tid is not null then perform operativo_privado.consumir(tid,r.id,s,m.id); end if;
  update public.operaciones_sincronizadas set estado='confirmada',registro_id=r.id where id=p_operacion;
  return jsonb_build_object('estado','confirmada','registro_id',r.id);
 exception when unique_violation or check_violation or not_null_violation or invalid_text_representation or invalid_datetime_format or datetime_field_overflow or raise_exception then
  get stacked diagnostics codigo=returned_sqlstate,mensaje=message_text;
  if codigo='23505' or mensaje in ('FOLIO_RESERVADO','TARJETA_NO_DISPONIBLE') then
   resultado_estado='conflicto'; mensaje=case when mensaje='TARJETA_NO_DISPONIBLE' then 'TARJETA_NO_DISPONIBLE' else 'FOLIO_O_IDENTIFICADOR_RESERVADO' end;
  else resultado_estado='error'; mensaje='DATOS_O_REGLAS_INVALIDOS'; end if;
  update public.operaciones_sincronizadas set estado=resultado_estado,motivo_conflicto=mensaje where id=p_operacion;
  return jsonb_build_object('estado',resultado_estado,'motivo',mensaje);
 end;
end $function$;

CREATE OR REPLACE FUNCTION public.crear_inventario(p_id uuid, p_sucursal uuid, p_nombre text, p_ruta text, p_extension text, p_anio integer, p_semana integer, p_modulo text, p_config jsonb DEFAULT '{}'::jsonb)
 RETURNS inventarios
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.perfiles; i public.inventarios;
begin
 PERFORM operativo_privado.marc_write_allowed_124();
 a=operativo_privado.actor(); if not operativo_privado.gestiona(p_sucursal) or not exists(select 1 from public.sucursales where id=p_sucursal and activa) then raise exception 'Acceso no autorizado' using errcode='42501'; end if;
 if split_part(p_ruta,'/',1)<>p_sucursal::text or split_part(p_ruta,'/',2)<>p_id::text or not exists(select 1 from storage.objects where bucket_id='inventarios' and name=p_ruta) then raise exception 'Archivo original no disponible'; end if;
 insert into public.inventarios(id,sucursal_id,nombre_archivo,ruta_archivo,extension,anio,semana,nombre_modulo,configuracion_hojas,cargado_por) values(p_id,p_sucursal,p_nombre,p_ruta,p_extension,p_anio,p_semana,p_modulo,p_config,a.id) returning * into i;
 return i;
end $function$;

CREATE OR REPLACE FUNCTION public.aprovisionar_perfil(p_actor uuid, p_usuario uuid, p_nombre text, p_rol rol_operativo, p_sucursal uuid)
 RETURNS perfiles
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.perfiles; p public.perfiles;
begin
 PERFORM operativo_privado.marc_write_allowed_124();
 select * into a from public.perfiles where id=p_actor and activo for share;
 if not found then raise exception 'Acceso no autorizado' using errcode='42501'; end if;
 if a.rol='promotor' or (a.rol='supervisor' and (p_rol is distinct from 'promotor'::public.rol_operativo or p_sucursal is distinct from a.sucursal_id or not exists(select 1 from public.sucursales where id=a.sucursal_id and activa))) then raise exception 'Acceso no autorizado' using errcode='42501'; end if;
 if p_sucursal is not null and not exists(select 1 from public.sucursales where id=p_sucursal and activa) then raise exception 'Sucursal no activa'; end if;
 insert into public.perfiles(id,nombre,rol,sucursal_id,creado_por) values(p_usuario,p_nombre,p_rol,p_sucursal,a.id) returning * into p;
 if p_rol='promotor' then insert into public.promotores(perfil_id,sucursal_id,nombre) values(p.id,p.sucursal_id,p.nombre); end if;
 return p;
end $function$;

CREATE OR REPLACE FUNCTION public.crear_sucursal(p_codigo text, p_nombre text, p_zona text DEFAULT 'America/Mexico_City'::text)
 RETURNS sucursales
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.perfiles; s public.sucursales;
begin
 PERFORM operativo_privado.marc_write_allowed_124();
 a=operativo_privado.actor(); if a.rol<>'administrador' then raise exception 'Acceso no autorizado' using errcode='42501'; end if;
 if not exists(select 1 from pg_catalog.pg_timezone_names where name=p_zona) then raise exception 'Zona horaria inválida'; end if;
 insert into public.sucursales(codigo,nombre,zona_horaria) values(p_codigo,p_nombre,p_zona) returning * into s;
 insert into public.configuracion_sucursal(sucursal_id,actualizado_por) values(s.id,a.id); return s;
end $function$;

CREATE OR REPLACE FUNCTION public.marc_stock_apply_130(p_id uuid, p_rows jsonb, p_map jsonb, p_expected jsonb, p_meta jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE plan jsonb; r jsonb; added integer:=0; n integer; req jsonb; result jsonb; prev record; ep jsonb;
BEGIN
 PERFORM operativo_privado.marc_write_allowed_124();
 PERFORM operativo_privado.marc_stock_guard_130(true);
 IF p_id IS NULL OR jsonb_typeof(p_meta) IS DISTINCT FROM 'object' OR octet_length(p_meta::text)>500000 THEN RAISE EXCEPTION 'Metadatos inválidos'; END IF;
 req:=jsonb_build_object('rows',p_rows,'map',p_map,'expected',p_expected,'meta',p_meta);
 -- Serializa las importaciones; no modifica tarjetas existentes.
 LOCK TABLE public.marc_stock_modules_130 IN SHARE ROW EXCLUSIVE MODE;
 SELECT * INTO prev FROM public.marc_stock_imports_130 WHERE id=p_id;
 IF FOUND THEN
   IF prev.realizado_por<>auth.uid() OR prev.solicitud<>req THEN RAISE EXCEPTION 'Identificador de importación reutilizado'; END IF;
   RETURN prev.resultado;
 END IF;
 -- Bloquea altas/transferencias concurrentes durante la nueva comprobación.
 LOCK TABLE public.tarjetas IN SHARE ROW EXCLUSIVE MODE;
 PERFORM operativo_privado.marc_stock_guard_130(true);
 ep:=to_jsonb(public.marc_epoch_state_126());
 IF p_meta->'epoch'->>'records' IS DISTINCT FROM ep->>'records' OR p_meta->'epoch'->>'tutorials' IS DISTINCT FROM ep->>'tutorials' THEN RAISE EXCEPTION 'La generación cambió. Analiza de nuevo'; END IF;
 plan:=operativo_privado.marc_stock_plan_130(p_rows,p_map);
 IF plan IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'El stock cambió desde el análisis. Analiza nuevamente'; END IF;
 -- No guardar equivalencias hasta que se confirme la importación.
 INSERT INTO public.marc_stock_modules_130(modulo,sucursal_id,creado_por)
 SELECT DISTINCT x->>'module',(x->>'target')::uuid,auth.uid() FROM jsonb_array_elements(plan) x
 ON CONFLICT (modulo) DO NOTHING;
 FOR r IN SELECT value FROM jsonb_array_elements(plan) WHERE value->>'action'='agregar' LOOP
   -- Reutiliza la RPC existente, con su bitácora de movimientos y controles.
   n:=public.alta_tarjetas_consecutivas((r->>'target')::uuid,left(r->>'code',16),right(r->>'code',5),1);
   IF n IS DISTINCT FROM 1 OR NOT EXISTS(SELECT 1 FROM public.tarjetas t WHERE t.codigo_completo=r->>'code' AND t.sucursal_id=(r->>'target')::uuid AND t.estado::text='disponible' AND t.promotor_id IS NULL) THEN RAISE EXCEPTION 'Alta no confirmada: %',r->>'code'; END IF;
   added:=added+1;
 END LOOP;
 result:=jsonb_build_object('id',p_id,'added',added,'existing',jsonb_array_length(plan)-added,'discrepancies',(SELECT count(*) FROM jsonb_array_elements(plan) x WHERE x->>'action'='discrepancia'),'plan',plan);
 INSERT INTO public.marc_stock_imports_130(id,realizado_por,solicitud,resultado) VALUES(p_id,auth.uid(),req,result);
 RETURN result;
END $function$;

CREATE OR REPLACE FUNCTION public.guardar_meta(p_sucursal uuid, p_promotor uuid, p_inicio date, p_ventas integer, p_objetivos jsonb DEFAULT '{}'::jsonb, p_meta_individual_base integer DEFAULT NULL::integer)
 RETURNS metas_semanales
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.perfiles; g public.metas_semanales; existente uuid;
begin
 PERFORM operativo_privado.marc_write_allowed_124();
 a=operativo_privado.actor(); if not operativo_privado.gestiona(p_sucursal) then raise exception 'Acceso no autorizado' using errcode='42501'; end if;
 if p_promotor is not null and not exists(select 1 from public.promotores where id=p_promotor and sucursal_id=p_sucursal and activo) then raise exception 'Promotor inválido'; end if;
 perform 1 from public.sucursales where id=p_sucursal and activa for update;
 if not found then raise exception 'Sucursal inválida'; end if;
 select id into existente from public.metas_semanales where sucursal_id=p_sucursal and promotor_id is not distinct from p_promotor and inicio_semana=p_inicio;
 if existente is null then
  insert into public.metas_semanales(sucursal_id,promotor_id,inicio_semana,meta_ventas,meta_individual_base,objetivo_dental,objetivo_cero,objetivo_primera_compra,objetivo_app,objetivo_calidad,objetivo_global,actualizado_por)
  values(p_sucursal,p_promotor,p_inicio,p_ventas,p_meta_individual_base,coalesce((p_objetivos->>'dental')::numeric,90),coalesce((p_objetivos->>'cero')::numeric,30),coalesce((p_objetivos->>'first')::numeric,90),coalesce((p_objetivos->>'app')::numeric,90),coalesce((p_objetivos->>'quality')::numeric,90),coalesce((p_objetivos->>'global')::numeric,95),a.id) returning * into g;
 else
  update public.metas_semanales set meta_ventas=p_ventas,meta_individual_base=p_meta_individual_base,objetivo_dental=coalesce((p_objetivos->>'dental')::numeric,objetivo_dental),objetivo_cero=coalesce((p_objetivos->>'cero')::numeric,objetivo_cero),objetivo_primera_compra=coalesce((p_objetivos->>'first')::numeric,objetivo_primera_compra),objetivo_app=coalesce((p_objetivos->>'app')::numeric,objetivo_app),objetivo_calidad=coalesce((p_objetivos->>'quality')::numeric,objetivo_calidad),objetivo_global=coalesce((p_objetivos->>'global')::numeric,objetivo_global),actualizado_por=a.id,actualizado_en=now() where id=existente returning * into g;
 end if;
 return g;
end $function$;

CREATE OR REPLACE FUNCTION public.editar_registro(p_registro uuid, p_version integer, p_datos jsonb, p_motivo_reversion text DEFAULT NULL::text)
 RETURNS registros
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.perfiles; r public.registros; m public.promotores; t public.tarjetas; tid uuid; f text; v_tipo public.tipo_registro; v_fecha date; c text;
begin
 PERFORM operativo_privado.marc_write_allowed_124();
 a=operativo_privado.actor(); select * into r from public.registros where id=p_registro for update;
 if not found or not operativo_privado.puede_registro(r.sucursal_id,r.promotor_id) then raise exception 'Acceso no autorizado' using errcode='42501'; end if;
 if r.eliminado_en is not null or p_version is distinct from r.version then raise exception 'REGISTRO_MODIFICADO_O_ELIMINADO'; end if;
 if jsonb_typeof(p_datos) is distinct from 'object' or exists(select 1 from jsonb_object_keys(p_datos) k where k not in ('promotor_id','fecha','tipo','folio','tarjeta_id','plan_dental','plan_cero','activacion_app','dinamica','incidencia','comentario')) then raise exception 'Campos no autorizados'; end if;
 select * into m from public.promotores where id=coalesce((p_datos->>'promotor_id')::uuid,r.promotor_id) and activo and sucursal_id=r.sucursal_id for share;
 if not found or not operativo_privado.puede_registro(r.sucursal_id,m.id) then raise exception 'Acceso no autorizado' using errcode='42501'; end if;
 v_tipo=coalesce((p_datos->>'tipo')::public.tipo_registro,r.tipo);
 f=case when p_datos ? 'folio' then nullif(btrim(p_datos->>'folio'),'') else r.folio end;
 v_fecha=coalesce((p_datos->>'fecha')::date,r.fecha);
 c=coalesce(p_datos->>'comentario',r.comentario);
 tid=case when p_datos ? 'tarjeta_id' then nullif(p_datos->>'tarjeta_id','')::uuid else r.tarjeta_id end;
 if v_tipo='Pendiente' and (r.tipo<>'Pendiente' or f is not null) then raise exception 'No se puede convertir un folio real en temporal'; end if;
 if v_tipo<>'Pendiente' and (f is null or f !~ '^[0-9]{8}$') then raise exception 'Folio inválido'; end if;
 if v_tipo not in ('Regular','Garantizada') and tid is not null then raise exception 'Este tipo no admite tarjeta'; end if;
 if v_tipo in ('Regular','Garantizada') and tid is null and (r.tipo='Pendiente' or r.tipo in ('Rechazada','Blacklist') or (r.tipo='Garantizada' and r.tarjeta_id is null and v_tipo='Regular')) then raise exception 'TARJETA_REQUERIDA'; end if;
 if r.tarjeta_id is not null and (tid is distinct from r.tarjeta_id or m.id<>r.promotor_id) then
  if not operativo_privado.gestiona(r.sucursal_id) then raise exception 'Un supervisor debe autorizar la reversión' using errcode='42501'; end if;
  perform operativo_privado.revertir(r.tarjeta_id,r.id,p_motivo_reversion);
 end if;
 if tid is not null then t=operativo_privado.validar_tarjeta(tid,r.sucursal_id,m.id,r.id); end if;
 update public.registros set fecha=v_fecha,tipo=v_tipo,folio=f,promotor_id=m.id,tarjeta_id=tid,codigo_corto=t.terminacion,codigo_completo=t.codigo_completo,
 plan_dental=v_tipo in ('Regular','Garantizada') and coalesce((p_datos->>'plan_dental')::boolean,r.plan_dental),
 plan_cero=v_tipo in ('Regular','Garantizada') and coalesce((p_datos->>'plan_cero')::boolean,r.plan_cero),
 activacion_app=v_tipo in ('Regular','Garantizada') and case when r.tarjeta_id is null and tid is not null then true else coalesce((p_datos->>'activacion_app')::boolean,r.activacion_app) end,
 dinamica=v_tipo in ('Regular','Garantizada') and coalesce((p_datos->>'dinamica')::boolean,r.dinamica),
 incidencia=coalesce((p_datos->>'incidencia')::boolean,r.incidencia),comentario=c,
 solicitud_actualizacion=true,fecha_solicitud=now(),actualizado_por=a.id,actualizado_en=now(),version=r.version+1
 where id=r.id returning * into r;
 if tid is not null then perform operativo_privado.consumir(tid,r.id,r.sucursal_id,r.promotor_id); end if;
 return r;
end $function$;

CREATE OR REPLACE FUNCTION operativo_privado.revertir(p_tarjeta uuid, p_registro uuid, p_motivo text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.perfiles; t public.tarjetas; asignar uuid;
begin
 PERFORM operativo_privado.marc_write_allowed_124();
 a=operativo_privado.actor(); select * into t from public.tarjetas where id=p_tarjeta for update;
 if not found or not operativo_privado.gestiona(t.sucursal_id) then raise exception 'Acceso no autorizado' using errcode='42501'; end if;
 if exists(select 1 from public.marc_admin_archived_branches_131 where sucursal_id=t.sucursal_id) then raise exception 'Recupera la sucursal antes de revertir una tarjeta histórica'; end if;
 if t.estado<>'consumida' or t.consumida_por_registro_id<>p_registro or btrim(coalesce(p_motivo,''))='' then raise exception 'Reversión no válida o sin motivo'; end if;
 if exists(select 1 from public.promotores where id=t.promotor_id and activo and sucursal_id=t.sucursal_id) then asignar=t.promotor_id; end if;
 update public.tarjetas set estado=case when asignar is null then 'disponible'::public.estado_tarjeta else 'asignada'::public.estado_tarjeta end,promotor_id=asignar,fecha_consumo=null,consumida_por_registro_id=null,fecha_asignacion=case when asignar is null then null else now() end where id=t.id;
 insert into public.movimientos_tarjetas(tarjeta_id,tipo_movimiento,sucursal_origen_id,sucursal_destino_id,promotor_origen_id,promotor_destino_id,registro_id,realizado_por,comentario) values(t.id,'reversion',t.sucursal_id,t.sucursal_id,t.promotor_id,asignar,p_registro,a.id,p_motivo);
end $function$;

CREATE FUNCTION operativo_privado.marc_profile_not_archived_131(p_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT NOT EXISTS(SELECT 1 FROM public.marc_admin_archived_users_131 WHERE usuario_id=p_id);
$$;
REVOKE ALL ON FUNCTION operativo_privado.marc_profile_not_archived_131(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION operativo_privado.marc_profile_not_archived_131(uuid) TO authenticated;
ALTER POLICY perfil_lectura ON public.perfiles USING (operativo_privado.es_admin() OR (operativo_privado.marc_profile_not_archived_131(id) AND ((id=auth.uid() AND activo AND operativo_privado.en_sucursal(sucursal_id)) OR (rol='promotor' AND operativo_privado.gestiona(sucursal_id)))));
COMMIT;
