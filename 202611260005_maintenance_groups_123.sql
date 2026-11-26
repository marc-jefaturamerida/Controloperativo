-- MARC 1.2.0-pre.3: simulación de dependencias. Sin DML de negocio.
BEGIN;
CREATE OR REPLACE FUNCTION public.marc_maintenance_plan_123(p_groups text[])
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  blockers jsonb := '[]'::jsonb;
  counts jsonb; selected jsonb; deps jsonb;
  required text[] := ARRAY[]::text[]; closure text[];
  edge jsonb; changed boolean; source_group text; target_group text;
BEGIN
  PERFORM operativo_privado.marc_admin_120();
  IF p_groups IS NULL OR cardinality(p_groups) NOT BETWEEN 1 AND 6 OR array_ndims(p_groups)<>1 OR array_position(p_groups,NULL::text) IS NOT NULL OR EXISTS (SELECT 1 FROM unnest(p_groups) AS g(k) WHERE k NOT IN ('registros','stock','inventarios','historial','sincronizacion','tutoriales')) OR (SELECT count(DISTINCT k) FROM unnest(p_groups) AS g(k))<>cardinality(p_groups) THEN
    RAISE EXCEPTION 'Selecciona grupos válidos sin repetir.' USING ERRCODE='22023';
  END IF;
  SELECT jsonb_build_array(
    jsonb_build_object('source','registros','target','stock','references',(SELECT count(*) FROM public.tarjetas WHERE consumida_por_registro_id IS NOT NULL)+(SELECT count(*) FROM public.movimientos_tarjetas WHERE registro_id IS NOT NULL),'message','Tarjetas o movimientos conservados hacen referencia a registros.'),
    jsonb_build_object('source','registros','target','sincronizacion','references',(SELECT count(*) FROM public.operaciones_sincronizadas WHERE registro_id IS NOT NULL),'message','Operaciones sincronizadas conservadas hacen referencia a registros.'),
    jsonb_build_object('source','stock','target','registros','references',(SELECT count(*) FROM public.registros WHERE tarjeta_id IS NOT NULL),'message','Registros conservados hacen referencia a tarjetas.'),
    jsonb_build_object('source','stock','target','inventarios','references',(SELECT count(*) FROM public.inventario_filas WHERE tarjeta_id IS NOT NULL),'message','Filas de inventario conservadas hacen referencia a tarjetas.')
  ) INTO deps;
  closure:=p_groups;
  LOOP
    changed:=false;
    FOR edge IN SELECT value FROM jsonb_array_elements(deps) LOOP
      source_group:=edge->>'source'; target_group:=edge->>'target';
      IF (edge->>'references')::bigint>0 AND source_group=ANY(closure) AND NOT (target_group=ANY(closure)) THEN
        closure:=array_append(closure,target_group); required:=array_append(required,target_group);
        blockers:=blockers||jsonb_build_array(edge); changed:=true;
      END IF;
    END LOOP;
    EXIT WHEN NOT changed;
  END LOOP;
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
  RETURN jsonb_build_object('plan_version',3,'groups',to_jsonb(p_groups),'counts',selected,'blockers',blockers,'required_groups',to_jsonb(required),'compatible',cardinality(required)=0,'execution_enabled',false);
END;
$$;
REVOKE ALL ON FUNCTION public.marc_maintenance_plan_123(text[]) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.marc_maintenance_plan_123(text[]) TO authenticated;
COMMIT;
