-- MARC 1.3.0: importación aditiva. Ejecutar en SQL Editor como propietario.
BEGIN;
-- Fallar antes de instalar si la base no coincide con las RPC de MARC 1.2.1.
DO $$ BEGIN
 IF to_regprocedure('public.alta_tarjetas_consecutivas(uuid,text,text,integer)') IS NULL OR
    to_regprocedure('public.marc_epoch_state_126()') IS NULL OR
    to_regprocedure('public.marc_backup_window_status_124()') IS NULL OR
    to_regprocedure('public.marc_file_cleanup_status_1210()') IS NULL THEN
   RAISE EXCEPTION 'Dependencias de MARC 1.2.1 no encontradas; no instalar todavía.';
 END IF;
 IF EXISTS (SELECT 1 FROM public.tarjetas GROUP BY codigo_completo HAVING count(*)>1) THEN
   RAISE EXCEPTION 'Existen códigos completos duplicados en stock. Revisar antes de instalar.';
 END IF;
END $$;
-- Garantía de unicidad global incluso frente a altas concurrentes.
CREATE UNIQUE INDEX IF NOT EXISTS marc_stock_import_codigo_130 ON public.tarjetas(codigo_completo);
CREATE TABLE IF NOT EXISTS public.marc_stock_modules_130 (
 modulo text PRIMARY KEY CHECK (length(modulo) BETWEEN 1 AND 200),
 sucursal_id uuid NOT NULL REFERENCES public.sucursales(id) ON DELETE RESTRICT,
 creado_por uuid NOT NULL, creado_en timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.marc_stock_imports_130 (
 id uuid PRIMARY KEY, realizado_por uuid NOT NULL, fecha timestamptz NOT NULL DEFAULT now(),
 solicitud jsonb NOT NULL, resultado jsonb NOT NULL
);
ALTER TABLE public.marc_stock_modules_130 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marc_stock_imports_130 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.marc_stock_modules_130, public.marc_stock_imports_130 FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION operativo_privado.marc_stock_guard_130(p_write boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE w jsonb; c jsonb; e jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.perfiles p WHERE p.id=auth.uid() AND p.activo AND p.rol::text='administrador') THEN
   RAISE EXCEPTION 'Acceso exclusivo de administrador activo' USING ERRCODE='42501';
 END IF;
 e:=to_jsonb(public.marc_epoch_state_126());
 IF e->>'records' IS NULL OR e->>'tutorials' IS NULL THEN RAISE EXCEPTION 'Sesión no verificada'; END IF;
 IF p_write THEN
   w:=to_jsonb(public.marc_backup_window_status_124()); c:=to_jsonb(public.marc_file_cleanup_status_1210());
   IF w->'active' IS DISTINCT FROM 'false'::jsonb OR c->'pending' IS DISTINCT FROM 'false'::jsonb THEN
     RAISE EXCEPTION 'Escrituras no habilitadas: mantenimiento o limpieza pendiente';
   END IF;
 END IF;
END $$;
REVOKE ALL ON FUNCTION operativo_privado.marc_stock_guard_130(boolean) FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.marc_stock_catalog_130()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM operativo_privado.marc_stock_guard_130(false);
 RETURN jsonb_build_object('modules',coalesce((SELECT jsonb_object_agg(modulo,sucursal_id) FROM public.marc_stock_modules_130),'{}'::jsonb),
 'branches',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'nombre',nombre,'activa',activa) ORDER BY nombre) FROM public.sucursales),'[]'::jsonb));
END $$;

CREATE OR REPLACE FUNCTION operativo_privado.marc_stock_plan_130(p_rows jsonb,p_map jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r jsonb; m text; code text; target uuid; saved uuid; card record; result jsonb:='[]'::jsonb;
BEGIN
 IF jsonb_typeof(p_rows) IS DISTINCT FROM 'array' OR jsonb_array_length(p_rows) NOT BETWEEN 1 AND 2000 OR jsonb_typeof(p_map) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Solicitud inválida: máximo 2000 códigos únicos'; END IF;
 IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_rows) x GROUP BY x->>'code' HAVING count(*)>1) THEN RAISE EXCEPTION 'Códigos repetidos en solicitud'; END IF;
 IF EXISTS (SELECT 1 FROM jsonb_object_keys(p_map) k WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_rows) x WHERE x->>'module'=k)) THEN RAISE EXCEPTION 'Equivalencia ajena a los datos'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_rows) ORDER BY value->>'code' LOOP
   code:=r->>'code'; m:=r->>'module';
   IF jsonb_typeof(r->'code') IS DISTINCT FROM 'string' OR jsonb_typeof(r->'module') IS DISTINCT FROM 'string' OR code IS NULL OR code !~ '^[0-9]{21}$' OR m IS NULL OR length(m) NOT BETWEEN 1 AND 200 OR m<>btrim(m) THEN RAISE EXCEPTION 'Código o módulo inválido'; END IF;
   SELECT sucursal_id INTO saved FROM public.marc_stock_modules_130 WHERE modulo=m;
   target:=coalesce(saved,(p_map->>m)::uuid);
   IF saved IS NOT NULL AND p_map ? m AND (p_map->>m)::uuid IS DISTINCT FROM saved THEN RAISE EXCEPTION 'Equivalencia modificada: analiza nuevamente'; END IF;
   IF target IS NULL OR NOT EXISTS(SELECT 1 FROM public.sucursales WHERE id=target AND activa) THEN RAISE EXCEPTION 'Módulo sin sucursal activa: %',m; END IF;
   SELECT id,sucursal_id,estado::text AS estado INTO card FROM public.tarjetas WHERE codigo_completo=code;
   result:=result||jsonb_build_array(jsonb_build_object('code',code,'module',m,'target',target,'current',card.sucursal_id,'state',card.estado,'action',CASE WHEN card.id IS NULL THEN 'agregar' WHEN card.sucursal_id IS DISTINCT FROM target THEN 'discrepancia' ELSE 'conservar' END));
 END LOOP;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION operativo_privado.marc_stock_plan_130(jsonb,jsonb) FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.marc_stock_preview_130(p_rows jsonb,p_map jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM operativo_privado.marc_stock_guard_130(false);
 RETURN operativo_privado.marc_stock_plan_130(p_rows,p_map);
END $$;

CREATE OR REPLACE FUNCTION public.marc_stock_apply_130(p_id uuid,p_rows jsonb,p_map jsonb,p_expected jsonb,p_meta jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE plan jsonb; r jsonb; added integer:=0; n integer; req jsonb; result jsonb; prev record; ep jsonb;
BEGIN
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
END $$;

CREATE OR REPLACE FUNCTION public.marc_stock_history_130()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM operativo_privado.marc_stock_guard_130(false);
 RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'actor',realizado_por,'date',fecha,'result',resultado-'plan','meta',solicitud->'meta') ORDER BY fecha DESC) FROM (SELECT * FROM public.marc_stock_imports_130 ORDER BY fecha DESC LIMIT 50) q),'[]'::jsonb);
END $$;
REVOKE ALL ON FUNCTION public.marc_stock_catalog_130(),public.marc_stock_preview_130(jsonb,jsonb),public.marc_stock_apply_130(uuid,jsonb,jsonb,jsonb,jsonb),public.marc_stock_history_130() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.marc_stock_catalog_130(),public.marc_stock_preview_130(jsonb,jsonb),public.marc_stock_apply_130(uuid,jsonb,jsonb,jsonb,jsonb),public.marc_stock_history_130() TO authenticated;
COMMIT;
