-- MARC 1.2.0-pre.1: instala exclusivamente una consulta administrativa.
-- No elimina, actualiza ni inserta filas de negocio. Ejecutar como propietario en SQL Editor.
BEGIN;
CREATE OR REPLACE FUNCTION public.marc_maintenance_status_120()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.perfiles p
    WHERE p.id = auth.uid() AND p.activo AND p.rol::text = 'administrador'
  ) THEN
    RAISE EXCEPTION 'Acceso exclusivo de administrador activo' USING ERRCODE = '42501';
  END IF;
  RETURN jsonb_build_object(
    'configuracion_global', (select count(*) from public.configuracion_global),
    'configuracion_sucursal', (select count(*) from public.configuracion_sucursal),
    'folios_reservados', (select count(*) from public.folios_reservados),
    'historial_cambios', (select count(*) from public.historial_cambios),
    'incidencias', (select count(*) from public.incidencias),
    'inventario_filas', (select count(*) from public.inventario_filas),
    'inventarios', (select count(*) from public.inventarios),
    'marc_tutorial_attempts', (select count(*) from public.marc_tutorial_attempts),
    'marc_tutorial_requests', (select count(*) from public.marc_tutorial_requests),
    'metas_semanales', (select count(*) from public.metas_semanales),
    'movimientos_tarjetas', (select count(*) from public.movimientos_tarjetas),
    'operaciones_sincronizadas', (select count(*) from public.operaciones_sincronizadas),
    'perfiles', (select count(*) from public.perfiles),
    'promotores', (select count(*) from public.promotores),
    'registros', (select count(*) from public.registros),
    'sucursales', (select count(*) from public.sucursales),
    'tarjetas', (select count(*) from public.tarjetas),
    'conflictos', (select count(*) from public.operaciones_sincronizadas where estado::text in ('conflicto','error'))
  );
END;
$$;
REVOKE ALL ON FUNCTION public.marc_maintenance_status_120() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.marc_maintenance_status_120() TO authenticated;
COMMIT;
