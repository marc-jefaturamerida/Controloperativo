-- MARC 1.2.0: diagnóstico complementario de solo lectura.
-- No devuelve filas de clientes, credenciales, JWT, contenidos de Excel ni nombres de objetos.
-- Las definiciones de funciones/políticas pueden contener secretos si alguien los incrustó;
-- revisa el resultado y censura cualquier secreto antes de compartirlo.
BEGIN TRANSACTION READ ONLY;
SELECT jsonb_build_object(
  'diagnostico', 'MARC 1.2.0 - dependencias y controles',
  'funciones', (SELECT coalesce(jsonb_agg(jsonb_build_object(
    'esquema', n.nspname, 'nombre', p.proname,
    'firma', pg_get_function_identity_arguments(p.oid),
    'definicion', pg_get_functiondef(p.oid),
    'propietario', pg_get_userbyid(p.proowner), 'acl', p.proacl::text
  ) ORDER BY n.nspname, p.proname), '[]'::jsonb)
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE p.prokind='f' AND (n.nspname='operativo_privado' OR
    (n.nspname='public' AND p.proname IN ('alta_tarjeta', 'alta_tarjetas_consecutivas', 'aprovisionar_perfil', 'asignar_tarjeta', 'asignar_tarjetas_lote', 'autorizar_restablecimiento', 'cerrar_inventario', 'crear_inventario', 'crear_registro', 'crear_sucursal', 'descartar_conflicto', 'devolver_tarjeta', 'editar_registro', 'eliminar_registro', 'gestionar_perfil', 'guardar_config_global', 'guardar_config_sucursal', 'guardar_fila_inventario', 'guardar_meta', 'guardar_seguimiento', 'importar_inventario', 'leer_tema_operativo', 'marc_tutorial_can_read_104', 'marc_tutorial_request_106', 'marc_tutorial_save_104', 'restaurar_registro', 'revertir_consumo_eliminado', 'transferir_tarjeta')))),
  'triggers', (SELECT coalesce(jsonb_agg(jsonb_build_object('esquema',n.nspname,'tabla',c.relname,'definicion',pg_get_triggerdef(t.oid),'estado',t.tgenabled::text)), '[]'::jsonb)
    FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE NOT t.tgisinternal AND n.nspname IN ('public','auth','storage')),
  'politicas', (SELECT coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) FROM pg_policies p WHERE schemaname IN ('public','storage') AND (schemaname='public' OR tablename IN ('objects','buckets'))),
  'auth_columnas', (SELECT coalesce(jsonb_agg(jsonb_build_object('tabla',table_name,'columna',column_name,'tipo',data_type,'nullable',is_nullable)), '[]'::jsonb)
    FROM information_schema.columns WHERE table_schema='auth' AND table_name IN ('sessions','refresh_tokens')),
  'auth_relaciones', (SELECT coalesce(jsonb_agg(jsonb_build_object('tabla',c.conrelid::regclass::text,'definicion',pg_get_constraintdef(c.oid),'nombre',c.conname)), '[]'::jsonb)
    FROM pg_constraint c WHERE c.conrelid IN (to_regclass('auth.sessions'),to_regclass('auth.refresh_tokens')) OR c.confrelid IN (to_regclass('auth.sessions'),to_regclass('auth.refresh_tokens'))),
  'grants_tablas', (SELECT coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) FROM information_schema.role_table_grants t WHERE table_schema='public' AND grantee IN ('anon','authenticated','service_role')),
  'grants_funciones', (SELECT coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) FROM information_schema.role_routine_grants r WHERE routine_schema IN ('public','operativo_privado') AND grantee IN ('PUBLIC','anon','authenticated','service_role')),
  'inventario_archivos', (SELECT jsonb_build_object('archivos_bucket',count(*),'bytes_declarados',coalesce(sum(CASE WHEN metadata->>'size' ~ '^[0-9]+$' THEN (metadata->>'size')::numeric ELSE 0 END),0),'archivos_sin_inventario',count(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM public.inventarios i WHERE i.ruta_archivo=o.name))) FROM storage.objects o WHERE o.bucket_id='inventarios'),
  'inventarios_sin_archivo', (SELECT count(*) FROM public.inventarios i WHERE NOT EXISTS (SELECT 1 FROM storage.objects o WHERE o.bucket_id='inventarios' AND o.name=i.ruta_archivo)),
  'conteos', jsonb_build_object(
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
  )
) AS diagnostico_marc_120;
COMMIT;
