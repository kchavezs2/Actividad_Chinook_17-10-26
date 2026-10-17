# Cambios de precios con trazabilidad - Chinook

**Asignatura:** Bases de Datos I  
**Estudiante:** Kevin Estuardo Chávez Santiago
**Motor verificado:** PostgreSQL 18.3  
**Cliente:** DataGrip  
**Base de datos con las tablas de Chinook:** `postgres` (`public.track`, `public.invoice`, `public.invoice_line`, etc.)  
**Variante:** nombres de tabla/columna `snake_case`  
**Archivo observado abierto en DataGrip:** `Chinook_PostgreSql.sql` (verificar que coincida con el archivo originalmente importado).  
**Referencia de Chinook:** https://github.com/lerocha/chinook-database  
**Repositorio publicado:** https://github.com/kchavezs2/Actividad_Chinook_17-10-26.git

## Contexto
Se necesita calcular un precio ajustado, aplicarlo a una única pista y auditar los cambios efectivos. No se actualizan importes históricos de `invoice` o `invoice_line`.

## Componentes
- `public.calcular_precio_ajustado(numeric,numeric)`: **función escalar**, devuelve NUMERIC con redondeo a 2 decimales, acepta -50 a 100 inclusive y valida NULL, precio no positivo y resultado redondeado no positivo; no modifica tablas.
- `public.aplicar_ajuste_precio(integer,numeric)`: **procedimiento**, usa `FOR UPDATE`, reutiliza la función y actualiza solamente la pista indicada, ejecutándose mediante CALL.
- `public.auditar_cambio_precio()` y `trg_auditar_precio`: **función trigger y trigger**, se ejecutan después de una modificación en `unit_price`, guardan `OLD`, `NEW`, fecha y `CURRENT_USER`, solo si el precio cambia realmente. Funcionan con CALL o UPDATE directo.
- `public.auditoria_precios`: tabla que conserva el historial de auditoría.

## Contenido y orden de ejecución
```
README.md
sql/
  01_preparacion.sql
  02_funcion_escalar.sql
  03_procedimiento.sql
  04_trigger_y_funcion.sql
  05_pruebas.sql
```

1. En DataGrip, elegir la conexión local `postgres@localhost` y una consola asociada a `postgres.public`. **No seleccionar `chinook.public`**, porque en el equipo comprobado esa base no contiene el catálogo `track`.
2. Ejecutar los archivos `01` a `04` en orden, confirmando su creación en PostgreSQL. Los datos existentes de `track` deben permanecer sin cambio durante la preparación.
3. Ejecutar `05_pruebas.sql` **por casos**, en la misma consola. Para las pruebas 3, 6 y 8 tomar captura después del cambio y antes del `ROLLBACK`; después ejecutar `ROLLBACK`.
4. En caso 2 se usan manejadores `EXCEPTION` individuales dentro de un bloque `DO`, para reunir siete errores reales en una sola salida. Si se pide estrictamente un SELECT por error, el archivo contiene esas siete llamadas como comentarios para ejecutarlas individualmente.
5. Las pistas de prueba confirmadas son IDs `1` y `2`, ambos originalmente a `0.99`. Las pruebas válidas se revierten y no deben dejar cambios en el catálogo.
6. Las secuencias de identidad pueden registrar saltos después de ROLLBACK; no es un error.

## Evidencia
Nueve capturas reales de DataGrip documentan ocho casos (la prueba 8 incluye estado durante y después de ROLLBACK). El PDF de evidencias se entrega separadamente en Canvas.

## Seguridad
No guardar contraseñas, credenciales ni cadenas de conexión privadas. Usar una copia de práctica, no una base de producción.
