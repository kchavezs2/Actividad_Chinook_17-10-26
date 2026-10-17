-- 04_trigger_y_funcion.sql
-- Función de soporte: ejecutada automáticamente por el trigger.
-- Se auditan exclusivamente cambios efectivos en el precio actual.

CREATE OR REPLACE FUNCTION public.auditar_cambio_precio()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.unit_price IS DISTINCT FROM NEW.unit_price THEN
        INSERT INTO public.auditoria_precios (
            track_id, precio_anterior, precio_nuevo,
            fecha_hora, usuario_bd
        )
        VALUES (
            NEW.track_id, OLD.unit_price, NEW.unit_price,
            CURRENT_TIMESTAMP, CURRENT_USER
        );
    END IF;

    RETURN NEW;
END;
$$;

-- Idempotencia del trigger: puede volverse a ejecutar este archivo.
DROP TRIGGER IF EXISTS trg_auditar_precio ON public.track;

CREATE TRIGGER trg_auditar_precio
AFTER UPDATE OF unit_price ON public.track
FOR EACH ROW
EXECUTE FUNCTION public.auditar_cambio_precio();
