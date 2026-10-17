-- 02_funcion_escalar.sql
-- La función calcula y devuelve un único NUMERIC; NO modifica tablas.

CREATE OR REPLACE FUNCTION public.calcular_precio_ajustado(
    p_precio_actual numeric,
    p_porcentaje numeric
)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
    v_precio_nuevo numeric;
BEGIN
    IF p_precio_actual IS NULL OR p_porcentaje IS NULL THEN
        RAISE EXCEPTION 'El precio y el porcentaje no pueden ser NULL';
    END IF;

    IF p_precio_actual <= 0 THEN
        RAISE EXCEPTION 'El precio inicial debe ser mayor que cero';
    END IF;

    IF p_porcentaje < -50 OR p_porcentaje > 100 THEN
        RAISE EXCEPTION 'El porcentaje debe estar entre -50 y 100';
    END IF;

    v_precio_nuevo := ROUND(p_precio_actual * (1 + p_porcentaje / 100), 2);

    IF v_precio_nuevo <= 0 THEN
        RAISE EXCEPTION 'El precio ajustado debe ser positivo después del redondeo';
    END IF;

    RETURN v_precio_nuevo;
END;
$$;
