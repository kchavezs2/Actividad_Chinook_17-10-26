-- 01_preparacion.sql
-- Propósito: identificar la instalación y crear la tabla de auditoría.
-- No recrea Chinook ni cambia sus datos de catálogo o facturas.

SELECT current_database() AS base_datos,
       current_user AS usuario_bd,
       current_setting('server_version') AS version_postgresql;

-- Revisa cuál variante está instalada: track/track_id/unit_price
-- o "Track"/"TrackId"/"UnitPrice".
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND lower(table_name) = 'track'
ORDER BY table_name, ordinal_position;

CREATE TABLE IF NOT EXISTS public.auditoria_precios (
    auditoria_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    track_id integer NOT NULL,
    precio_anterior numeric(12,2) NOT NULL,
    precio_nuevo numeric(12,2) NOT NULL,
    fecha_hora timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_bd text NOT NULL DEFAULT CURRENT_USER
);

-- Confirma la estructura de auditoría (no es evidencia de las pruebas).
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='public' AND table_name='auditoria_precios'
ORDER BY ordinal_position;
