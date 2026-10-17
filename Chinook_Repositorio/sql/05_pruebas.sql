-- 05_pruebas.sql | PostgreSQL 18.3 | DataGrip | Chinook en postgres.public
-- Ejecutar por casos en consola conectada a la base postgres.
-- Comentarios detallan propósito, datos y resultado esperado.
-- En cambios, capturar antes de ROLLBACK. No ejecutar todo de una sola vez.

-- CASO 1 | Aumento 10% y reducción 50% de precio 10.
-- Esperado: aumento 11.00, reducción 5.00. La función no escribe datos.
SELECT current_database() AS base_datos,
       current_setting('server_version') AS version_postgresql,
       public.calcular_precio_ajustado(10,10) AS aumento,
       public.calcular_precio_ajustado(10,-50) AS reduccion;

-- CASO 2 | Valores inválidos; cada invocación aislada captura su error.
-- Se comprueban: NULL (2), cero, negativo, +101%, -51%, redondeo a 0.
-- Esperado: siete errores explícitos, sin abortar la ejecución global.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('Precio NULL',NULL::numeric,10::numeric),
      ('Porcentaje NULL',10,NULL),
      ('Precio cero',0,10),
      ('Precio negativo',-10,10),
      ('Porcentaje 101',10,101),
      ('Porcentaje -51',10,-51),
      ('Redondeo a cero',0.001,0)
    ) AS t(caso, precio, porcentaje)
  LOOP
    BEGIN
      PERFORM public.calcular_precio_ajustado(r.precio,r.porcentaje);
      RAISE NOTICE '%: SIN ERROR',r.caso;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE '%: ERROR: %',r.caso,SQLERRM;
    END;
  END LOOP;
END;
$$;
-- Si el docente requiere SELECT independientes en vez de DO, ejecutar cada
-- una por separado. Se esperan errores intencionales:
-- SELECT public.calcular_precio_ajustado(NULL,10);
-- SELECT public.calcular_precio_ajustado(10,NULL);
-- SELECT public.calcular_precio_ajustado(0,10);
-- SELECT public.calcular_precio_ajustado(-10,10);
-- SELECT public.calcular_precio_ajustado(10,101);
-- SELECT public.calcular_precio_ajustado(10,-51);
-- SELECT public.calcular_precio_ajustado(0.001,0);

-- CASO 3 | CALL válido 10% pista 1; pista 2 control.
-- Esperado: pista 1 de 0.99 a 1.09, pista 2 en 0.99; auditoría 0.99 -> 1.09.
BEGIN;
CREATE TEMP TABLE caso3_antes ON COMMIT DROP AS
SELECT track_id,name,unit_price AS precio_antes FROM public.track
WHERE track_id IN (1,2);
CALL public.aplicar_ajuste_precio(1,10);
SELECT b.track_id,b.name,b.precio_antes,t.unit_price AS precio_despues,
       a.precio_anterior AS auditoria_anterior,a.precio_nuevo AS auditoria_nuevo
FROM caso3_antes b
JOIN public.track t ON t.track_id=b.track_id
LEFT JOIN LATERAL (
 SELECT precio_anterior,precio_nuevo FROM public.auditoria_precios
 WHERE track_id=b.track_id ORDER BY auditoria_id DESC LIMIT 1
) a ON b.track_id=1 ORDER BY b.track_id;
-- Capturar aquí antes de revertir.
ROLLBACK;

-- CASO 4 | Identificador -1 inexistente y NULL; no modificar datos.
-- Esperado: dos errores, precio pista 1 = 0.99, auditorías sin cambio.
DO $$
DECLARE v_precio_antes NUMERIC; v_precio_despues NUMERIC;
        v_auditorias_antes BIGINT; v_auditorias_despues BIGINT;
BEGIN
 SELECT unit_price INTO v_precio_antes FROM public.track WHERE track_id=1;
 SELECT COUNT(*) INTO v_auditorias_antes FROM public.auditoria_precios;
 BEGIN
  CALL public.aplicar_ajuste_precio(-1,10);
 EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ID inexistente: %',SQLERRM;
 END;
 BEGIN
  CALL public.aplicar_ajuste_precio(NULL,10);
 EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ID NULL: %',SQLERRM;
 END;
 SELECT unit_price INTO v_precio_despues FROM public.track WHERE track_id=1;
 SELECT COUNT(*) INTO v_auditorias_despues FROM public.auditoria_precios;
 RAISE NOTICE 'Precio antes: % | despues: %',v_precio_antes,v_precio_despues;
 RAISE NOTICE 'Auditorias antes: % | despues: %',v_auditorias_antes,v_auditorias_despues;
 IF v_precio_antes IS DISTINCT FROM v_precio_despues OR
    v_auditorias_antes<>v_auditorias_despues THEN
  RAISE EXCEPTION 'Se detectaron cambios inesperados';
 END IF;
END;
$$;

-- CASO 5 | Porcentaje 150% inválido; sin cambios parciales.
-- Esperado: error de rango; pista 1 = 0.99, auditorías intactas.
DO $$
DECLARE precio_antes NUMERIC; precio_despues NUMERIC;
        auditorias_antes INTEGER; auditorias_despues INTEGER;
BEGIN
 SELECT unit_price INTO precio_antes FROM public.track WHERE track_id=1;
 SELECT COUNT(*) INTO auditorias_antes FROM public.auditoria_precios;
 BEGIN
   CALL public.aplicar_ajuste_precio(1,150);
 EXCEPTION WHEN OTHERS THEN
   RAISE NOTICE 'ERROR ESPERADO: %',SQLERRM;
 END;
 SELECT unit_price INTO precio_despues FROM public.track WHERE track_id=1;
 SELECT COUNT(*) INTO auditorias_despues FROM public.auditoria_precios;
 RAISE NOTICE 'Precio antes: % | despues: %',precio_antes,precio_despues;
 RAISE NOTICE 'Auditorias antes: % | despues: %',auditorias_antes,auditorias_despues;
 IF precio_antes IS DISTINCT FROM precio_despues OR
    auditorias_antes<>auditorias_despues THEN
   RAISE EXCEPTION 'Se detectaron cambios inesperados';
 END IF;
END;
$$;

-- CASO 6 | UPDATE sin CALL activa trigger de auditoría.
-- Esperado: pista 1 0.99 -> 1.09, auditoría anterior/nueva y current_user.
BEGIN;
CREATE TEMP TABLE caso6_antes ON COMMIT DROP AS
SELECT track_id,unit_price AS precio_antes FROM public.track WHERE track_id=1;
UPDATE public.track SET unit_price=unit_price+0.10 WHERE track_id=1;
SELECT t.track_id,b.precio_antes,t.unit_price AS precio_despues,
       a.precio_anterior AS auditoria_anterior,
       a.precio_nuevo AS auditoria_nuevo,a.usuario_bd
FROM public.track t JOIN caso6_antes b ON b.track_id=t.track_id
JOIN LATERAL (
 SELECT precio_anterior,precio_nuevo,usuario_bd
 FROM public.auditoria_precios WHERE track_id=t.track_id
 ORDER BY auditoria_id DESC LIMIT 1
) a ON TRUE WHERE t.track_id=1;
-- Capturar aquí antes de revertir.
ROLLBACK;

-- CASO 7 | UPDATE con mismo precio no crea auditoría.
-- Esperado: cuenta auditorías 0 -> 0 y precio pista 1 = 0.99.
BEGIN;
CREATE TEMP TABLE caso7_antes ON COMMIT DROP AS
 SELECT COUNT(*) AS auditorias_antes FROM public.auditoria_precios;
UPDATE public.track SET unit_price=unit_price WHERE track_id=1;
SELECT b.auditorias_antes,
       (SELECT COUNT(*) FROM public.auditoria_precios) AS auditorias_despues,
       t.unit_price AS precio_actual
FROM caso7_antes b CROSS JOIN public.track t WHERE t.track_id=1;
ROLLBACK;

-- CASO 8 | Integridad: rollback revierte precio y auditoría.
-- Esperado: dentro de transacción 0.99 -> 1.19, auditado; al final 0.99 y 0.
BEGIN;
CREATE TEMP TABLE caso8_antes ON COMMIT DROP AS
SELECT track_id,unit_price AS precio_original,
       (SELECT COUNT(*) FROM public.auditoria_precios) AS auditorias_originales
FROM public.track WHERE track_id=1;
CALL public.aplicar_ajuste_precio(1,20);
SELECT b.track_id,b.precio_original,t.unit_price AS precio_durante,
       a.precio_anterior,a.precio_nuevo,b.auditorias_originales,
       (SELECT COUNT(*) FROM public.auditoria_precios) AS auditorias_durante
FROM caso8_antes b JOIN public.track t ON t.track_id=b.track_id
LEFT JOIN LATERAL (
 SELECT precio_anterior,precio_nuevo FROM public.auditoria_precios
 WHERE track_id=b.track_id ORDER BY auditoria_id DESC LIMIT 1
) a ON TRUE;
-- Capturar 8A antes del ROLLBACK.
ROLLBACK;
SELECT track_id,unit_price AS precio_final,
       (SELECT COUNT(*) FROM public.auditoria_precios) AS auditorias_finales
FROM public.track WHERE track_id=1;
-- Capturar 8B después del ROLLBACK.
