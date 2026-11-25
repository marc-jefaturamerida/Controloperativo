-- Control operativo 09.4.1. No altera tablas, datos ni políticas RLS existentes.
BEGIN;
CREATE OR REPLACE FUNCTION public.leer_tema_operativo()
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v text;
BEGIN
  PERFORM operativo_privado.actor();
  SELECT c.valor #>> '{}' INTO v FROM public.configuracion_global c WHERE c.clave = 'tema_operativo';
  IF v IN ('azul','verde','grafito','violeta') THEN RETURN v; END IF;
  RETURN 'azul';
END;
$$;
REVOKE ALL ON FUNCTION public.leer_tema_operativo() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.leer_tema_operativo() TO authenticated;
COMMIT;
