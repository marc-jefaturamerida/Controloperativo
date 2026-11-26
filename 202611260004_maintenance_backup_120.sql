-- MARC 1.2.0-pre.2: respaldo y evaluación de dependencias. No borra datos.
BEGIN;
CREATE OR REPLACE FUNCTION operativo_privado.marc_admin_120()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id=auth.uid() AND p.activo AND p.rol='administrador') THEN
    RAISE EXCEPTION 'Acceso exclusivo de administrador activo' USING ERRCODE='42501';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION operativo_privado.marc_admin_120() FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.marc_backup_snapshot_120()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
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
    'marc_tutorial_requests', (select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text), '[]'::jsonb) from public.marc_tutorial_requests t)
  ) INTO datos;
  SELECT coalesce(jsonb_agg(jsonb_build_object('path',o.name,'object_id',o.id,'updated_at',o.updated_at,'size',o.metadata->>'size') ORDER BY o.name),'[]'::jsonb)
    INTO archivos FROM storage.objects o WHERE o.bucket_id='inventarios';
  IF EXISTS (SELECT 1 FROM public.inventarios i WHERE NOT EXISTS (SELECT 1 FROM storage.objects o WHERE o.bucket_id='inventarios' AND o.name=i.ruta_archivo)) THEN
    RAISE EXCEPTION 'Existe un inventario sin archivo original. Respaldo incompleto.';
  END IF;
  RETURN jsonb_build_object('format','marc-operativo-v1','tables',datos,'files',archivos);
END;
$$;
REVOKE ALL ON FUNCTION public.marc_backup_snapshot_120() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.marc_backup_snapshot_120() TO authenticated;

CREATE OR REPLACE FUNCTION public.marc_maintenance_plan_120(p_groups text[])
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE blockers jsonb := '[]'::jsonb; counts jsonb; selected jsonb; n bigint;
BEGIN
  PERFORM operativo_privado.marc_admin_120();
  IF p_groups IS NULL OR cardinality(p_groups) NOT BETWEEN 1 AND 6 OR array_ndims(p_groups)<>1 OR array_position(p_groups,NULL::text) IS NOT NULL OR EXISTS (SELECT 1 FROM unnest(p_groups) g WHERE g NOT IN ('registros','stock','inventarios','historial','sincronizacion','tutoriales')) OR (SELECT count(DISTINCT g) FROM unnest(p_groups) g)<>cardinality(p_groups) THEN
    RAISE EXCEPTION 'Selecciona grupos válidos sin repetir.' USING ERRCODE='22023';
  END IF;
  IF 'registros'=ANY(p_groups) AND NOT ('stock'=ANY(p_groups)) THEN
    SELECT (SELECT count(*) FROM public.tarjetas WHERE consumida_por_registro_id IS NOT NULL)+(SELECT count(*) FROM public.movimientos_tarjetas WHERE registro_id IS NOT NULL) INTO n;
    IF n>0 THEN blockers:=blockers||jsonb_build_array(jsonb_build_object('message','El stock o sus movimientos conservados hacen referencia a registros. Incluye stock o cambia la selección.','references',n)); END IF;
  END IF;
  IF 'registros'=ANY(p_groups) AND NOT ('sincronizacion'=ANY(p_groups)) THEN
    SELECT count(*) INTO n FROM public.operaciones_sincronizadas WHERE registro_id IS NOT NULL;
    IF n>0 THEN blockers:=blockers||jsonb_build_array(jsonb_build_object('message','Hay operaciones de sincronización relacionadas con registros. Incluye sincronización o cambia la selección.','references',n)); END IF;
  END IF;
  IF 'stock'=ANY(p_groups) AND NOT ('registros'=ANY(p_groups)) THEN
    SELECT count(*) INTO n FROM public.registros WHERE tarjeta_id IS NOT NULL;
    IF n>0 THEN blockers:=blockers||jsonb_build_array(jsonb_build_object('message','Hay registros conservados vinculados a tarjetas. Incluye registros o cambia la selección.','references',n)); END IF;
  END IF;
  IF 'stock'=ANY(p_groups) AND NOT ('inventarios'=ANY(p_groups)) THEN
    SELECT count(*) INTO n FROM public.inventario_filas WHERE tarjeta_id IS NOT NULL;
    IF n>0 THEN blockers:=blockers||jsonb_build_array(jsonb_build_object('message','Hay revisiones de inventario vinculadas a tarjetas. Incluye inventarios o cambia la selección.','references',n)); END IF;
  END IF;
  SELECT jsonb_build_object(
    'registros', (select count(*) from public.registros),
    'folios_reservados', (select count(*) from public.folios_reservados),
    'incidencias', (select count(*) from public.incidencias),
    'tarjetas', (select count(*) from public.tarjetas),
    'movimientos_tarjetas', (select count(*) from public.movimientos_tarjetas),
    'inventarios', (select count(*) from public.inventarios),
    'inventario_filas', (select count(*) from public.inventario_filas),
    'historial_cambios', (select count(*) from public.historial_cambios),
    'operaciones_sincronizadas', (select count(*) from public.operaciones_sincronizadas),
    'marc_tutorial_attempts', (select count(*) from public.marc_tutorial_attempts),
    'marc_tutorial_requests', (select count(*) from public.marc_tutorial_requests),
    'archivos_excel', (select count(*) from storage.objects where bucket_id='inventarios')
  ) INTO counts;
  SELECT coalesce(jsonb_object_agg(k,counts->k),'{}'::jsonb) INTO selected FROM (
    SELECT unnest(CASE g
      WHEN 'registros' THEN ARRAY['registros','folios_reservados','incidencias']
      WHEN 'stock' THEN ARRAY['tarjetas','movimientos_tarjetas']
      WHEN 'inventarios' THEN ARRAY['inventarios','inventario_filas','archivos_excel']
      WHEN 'historial' THEN ARRAY['historial_cambios']
      WHEN 'sincronizacion' THEN ARRAY['operaciones_sincronizadas']
      WHEN 'tutoriales' THEN ARRAY['marc_tutorial_attempts','marc_tutorial_requests']
    END) k FROM unnest(p_groups) g
  ) q;
  RETURN jsonb_build_object('groups',to_jsonb(p_groups),'counts',selected,'blockers',blockers,'compatible',jsonb_array_length(blockers)=0,'execution_enabled',false);
END;
$$;
REVOKE ALL ON FUNCTION public.marc_maintenance_plan_120(text[]) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.marc_maintenance_plan_120(text[]) TO authenticated;
COMMIT;
