-- MARC 1.3.1: reasignación atómica de supervisores. SQL Editor, propietario.
BEGIN;
DO $$
DECLARE helper text; validator text;
BEGIN
 IF to_regprocedure('operativo_privado.marc_require_session_126()') IS NULL OR
    to_regprocedure('operativo_privado.marc_session_valid_126()') IS NULL OR
    to_regprocedure('operativo_privado.marc_stock_guard_130(boolean)') IS NULL OR
    to_regprocedure('public.marc_epoch_state_126()') IS NULL OR
    to_regclass('auth.sessions') IS NULL OR to_regclass('auth.refresh_tokens') IS NULL THEN
   RAISE EXCEPTION 'Dependencias de MARC 1.3.0 ausentes. No instalar.';
 END IF;
 -- Reconoce la cadena real: require_session -> session_valid -> auth.sessions.
 SELECT lower(regexp_replace(replace(pg_get_functiondef(to_regprocedure('operativo_privado.marc_require_session_126()')), '"', ''), '[[:space:]]+', '', 'g')) INTO helper;
 SELECT lower(regexp_replace(replace(pg_get_functiondef(to_regprocedure('operativo_privado.marc_session_valid_126()')), '"', ''), '[[:space:]]+', '', 'g')) INTO validator;
 IF NOT coalesce((
    strpos(helper, 'ifnotoperativo_privado.marc_session_valid_126()then') > 0
    AND strpos(helper, 'raiseexception''marc_sesion_no_vigente:') > 0
    AND strpos(validator, 'fromauth.sessionss') > 0
    AND strpos(validator, 's.id::text=auth.jwt()->>''session_id''') > 0
    AND strpos(validator, 's.user_id=auth.uid()') > 0
    AND strpos(validator, 'crossjoinoperativo_privado.marc_epoch_126e') > 0
    AND strpos(validator, 'e.singleton') > 0
    AND strpos(validator, 's.created_at>e.sessions_after') > 0
    AND strpos(validator, '(s.not_afterisnullors.not_after>statement_timestamp())') > 0
    AND strpos(validator, 'selectcoalesce(exists(') > 0
 ), false) THEN
   RAISE EXCEPTION 'No se reconoce la cadena de validación de sesiones de MARC. Ejecutar diagnóstico previo.';
 END IF;
 IF NOT has_table_privilege(current_user,'auth.users','SELECT') OR NOT has_table_privilege(current_user,'auth.users','UPDATE') OR NOT has_table_privilege(current_user,'auth.sessions','SELECT') OR NOT has_table_privilege(current_user,'auth.sessions','DELETE') OR NOT has_table_privilege(current_user,'auth.refresh_tokens','SELECT') OR NOT has_table_privilege(current_user,'auth.refresh_tokens','DELETE') THEN
   RAISE EXCEPTION 'El propietario no puede revocar sesiones Auth.';
 END IF;
 -- Validar las columnas sin modificar filas.
 PERFORM id FROM auth.users LIMIT 0;
 PERFORM id,user_id FROM auth.sessions LIMIT 0;
 PERFORM user_id,session_id FROM auth.refresh_tokens LIMIT 0;
 PERFORM id,nombre,rol,activo,sucursal_id FROM public.perfiles LIMIT 0;
 PERFORM id,nombre,activa FROM public.sucursales LIMIT 0;
END $$;
CREATE TABLE IF NOT EXISTS public.marc_supervisor_transfers_131 (
 id uuid PRIMARY KEY,
 supervisor_id uuid NOT NULL, supervisor_nombre text NOT NULL,
 sucursal_anterior_id uuid NOT NULL, sucursal_anterior_nombre text NOT NULL,
 sucursal_nueva_id uuid NOT NULL, sucursal_nueva_nombre text NOT NULL,
 administrador_id uuid NOT NULL, administrador_nombre text NOT NULL,
 fecha timestamptz NOT NULL DEFAULT clock_timestamp(),
 sesiones_revocadas bigint NOT NULL CHECK (sesiones_revocadas>=0),
 CHECK(sucursal_anterior_id<>sucursal_nueva_id)
);
ALTER TABLE public.marc_supervisor_transfers_131 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.marc_supervisor_transfers_131 FROM PUBLIC,anon,authenticated,service_role;
CREATE INDEX IF NOT EXISTS marc_supervisor_transfers_131_fecha ON public.marc_supervisor_transfers_131(fecha DESC,id DESC);

CREATE OR REPLACE FUNCTION public.marc_transfer_supervisor_131(p_id uuid,p_supervisor uuid,p_anterior uuid,p_nueva uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET lock_timeout='5s' AS $$
DECLARE actor public.perfiles%ROWTYPE; target public.perfiles%ROWTYPE;
 old_branch public.sucursales%ROWTYPE; new_branch public.sucursales%ROWTYPE;
 audit public.marc_supervisor_transfers_131%ROWTYPE; revoked_count bigint;
BEGIN
 PERFORM operativo_privado.marc_stock_guard_130(true);
 PERFORM operativo_privado.marc_require_session_126();
 IF p_id IS NULL OR p_supervisor IS NULL OR p_anterior IS NULL OR p_nueva IS NULL OR p_anterior=p_nueva OR p_supervisor=auth.uid() THEN
   RAISE EXCEPTION 'Solicitud de cambio inválida' USING ERRCODE='22023';
 END IF;
 -- Serializa cambios de una misma cuenta y evita confirmaciones sobre una vista antigua.
 SELECT * INTO target FROM public.perfiles WHERE id=p_supervisor FOR UPDATE;
 SELECT * INTO actor FROM public.perfiles WHERE id=auth.uid() FOR SHARE;
 IF actor.id IS NULL OR actor.activo IS NOT TRUE OR actor.rol::text IS DISTINCT FROM 'administrador' THEN RAISE EXCEPTION 'Acceso exclusivo de administrador activo' USING ERRCODE='42501'; END IF;
 PERFORM operativo_privado.marc_stock_guard_130(true);
 SELECT * INTO audit FROM public.marc_supervisor_transfers_131 WHERE id=p_id;
 IF FOUND THEN
   IF audit.administrador_id<>actor.id OR audit.supervisor_id<>p_supervisor OR audit.sucursal_anterior_id<>p_anterior OR audit.sucursal_nueva_id<>p_nueva THEN RAISE EXCEPTION 'Identificador de operación reutilizado'; END IF;
   RETURN to_jsonb(audit);
 END IF;
 IF target.id IS NULL OR target.rol::text IS DISTINCT FROM 'supervisor' THEN RAISE EXCEPTION 'Solo se permite cambiar supervisores' USING ERRCODE='42501'; END IF;
 IF target.sucursal_id IS DISTINCT FROM p_anterior THEN RAISE EXCEPTION 'La sucursal anterior cambió. Actualiza la lista antes de confirmar.'; END IF;
 SELECT * INTO old_branch FROM public.sucursales WHERE id=p_anterior FOR SHARE;
 SELECT * INTO new_branch FROM public.sucursales WHERE id=p_nueva FOR SHARE;
 IF old_branch.id IS NULL OR new_branch.id IS NULL OR new_branch.activa IS NOT TRUE THEN RAISE EXCEPTION 'Selecciona una sucursal de destino activa y válida.'; END IF;
 -- Comprueba que la cuenta Auth todavía existe; no cambia contraseña ni datos de Auth.
 PERFORM 1 FROM auth.users WHERE id=p_supervisor FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'La cuenta de autenticación del supervisor no existe.'; END IF;
 -- Bloqueo breve de escrituras Auth durante la revocación para evitar sesiones concurrentes.
 -- No afecta otras cuentas; las escrituras concurrentes esperan a que termine esta transacción.
 LOCK TABLE auth.sessions,auth.refresh_tokens IN SHARE ROW EXCLUSIVE MODE;
 PERFORM operativo_privado.marc_stock_guard_130(true);
 UPDATE public.perfiles SET sucursal_id=p_nueva WHERE id=p_supervisor;
 IF NOT FOUND THEN RAISE EXCEPTION 'No se confirmó el cambio de perfil'; END IF;
 DELETE FROM auth.refresh_tokens WHERE user_id::text=p_supervisor::text OR session_id IN (SELECT id FROM auth.sessions WHERE user_id=p_supervisor);
 DELETE FROM auth.sessions WHERE user_id=p_supervisor;
 GET DIAGNOSTICS revoked_count=ROW_COUNT;
 IF EXISTS(SELECT 1 FROM auth.sessions WHERE user_id=p_supervisor) OR EXISTS(SELECT 1 FROM auth.refresh_tokens WHERE user_id::text=p_supervisor::text) THEN RAISE EXCEPTION 'No se pudo completar la revocación'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.perfiles WHERE id=p_supervisor AND sucursal_id=p_nueva AND rol::text='supervisor' AND activo IS NOT DISTINCT FROM target.activo) THEN RAISE EXCEPTION 'No se confirmó la adscripción'; END IF;
 INSERT INTO public.marc_supervisor_transfers_131(id,supervisor_id,supervisor_nombre,sucursal_anterior_id,sucursal_anterior_nombre,sucursal_nueva_id,sucursal_nueva_nombre,administrador_id,administrador_nombre,sesiones_revocadas)
 VALUES(p_id,target.id,target.nombre,old_branch.id,old_branch.nombre,new_branch.id,new_branch.nombre,actor.id,actor.nombre,revoked_count) RETURNING * INTO audit;
 RETURN to_jsonb(audit);
END $$;

CREATE OR REPLACE FUNCTION public.marc_supervisor_history_131(p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM operativo_privado.marc_stock_guard_130(false);
 PERFORM operativo_privado.marc_require_session_126();
 IF p_offset IS NULL OR p_offset<0 THEN RAISE EXCEPTION 'Página inválida'; END IF;
 RETURN jsonb_build_object('total',(SELECT count(*) FROM public.marc_supervisor_transfers_131),
 'rows',coalesce((SELECT jsonb_agg(to_jsonb(q) ORDER BY q.fecha DESC,q.id DESC) FROM (SELECT * FROM public.marc_supervisor_transfers_131 ORDER BY fecha DESC,id DESC LIMIT 50 OFFSET p_offset) q),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.marc_transfer_supervisor_131(uuid,uuid,uuid,uuid),public.marc_supervisor_history_131(integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.marc_transfer_supervisor_131(uuid,uuid,uuid,uuid),public.marc_supervisor_history_131(integer) TO authenticated;
COMMIT;
