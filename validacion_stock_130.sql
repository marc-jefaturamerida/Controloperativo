-- Consultar DESPUÉS de instalar, sin escribir datos.
BEGIN TRANSACTION READ ONLY;
SELECT jsonb_build_object(
 'tarjetas_duplicadas', (SELECT count(*) FROM (SELECT codigo_completo FROM public.tarjetas GROUP BY codigo_completo HAVING count(*)>1) q),
 'tablas', (SELECT jsonb_agg(jsonb_build_object('tabla',c.relname,'rls',c.relrowsecurity,'acl',c.relacl::text)) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN ('marc_stock_modules_130','marc_stock_imports_130')),
 'rpc', (SELECT jsonb_agg(jsonb_build_object('nombre',p.proname,'firma',pg_get_function_identity_arguments(p.oid),'definer',p.prosecdef,'acl',p.proacl::text)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('public','operativo_privado') AND p.proname IN ('marc_stock_guard_130','marc_stock_catalog_130','marc_stock_plan_130','marc_stock_preview_130','marc_stock_apply_130','marc_stock_history_130','alta_tarjetas_consecutivas')),
 'indice', (SELECT pg_get_indexdef(indexrelid) FROM pg_index WHERE indexrelid=to_regclass('public.marc_stock_import_codigo_130') AND indisunique AND indisvalid),
 'equivalencias', (SELECT count(*) FROM public.marc_stock_modules_130),
 'importaciones', (SELECT count(*) FROM public.marc_stock_imports_130)
) AS validacion_marc_130;
COMMIT;
