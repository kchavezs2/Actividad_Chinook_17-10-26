-- 03_procedimiento.sql
-- Valida la pista, delega el cálculo y actualiza una sola fila.
-- No escribe directamente en auditoria_precios: el trigger lo hace.

CREATE OR REPLACE PROCEDURE public.aplicar_ajuste_precio(
    p_track_id integer,
    p_porcentaje numeric
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_precio_actual numeric;
    v_precio_nuevo numeric;
BEGIN
    IF p_track_id IS NULL THEN
        RAISE EXCEPTION 'El identificador no puede ser NULL';
    END IF;

    SELECT t.unit_price
      INTO v_precio_actual
      FROM public.track AS t
     WHERE t.track_id = p_track_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La pista % no existe', p_track_id;
    END IF;

    v_precio_nuevo := public.calcular_precio_ajustado(
        v_precio_actual, p_porcentaje
    );

    UPDATE public.track
       SET unit_price = v_precio_nuevo
     WHERE track_id = p_track_id;
END;
$$;
