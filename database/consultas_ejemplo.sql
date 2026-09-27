-- ============================================================
-- Archivo: 04_consultas_ejemplo.sql
-- Consultas declarativas de referencia (para el README, sección
-- "Declarativo e imperativo" y para que verifiques que tu backend
-- resuelve esto en SQL y no trayendo todo y filtrando con ciclos).
-- ============================================================

USE perritos_db;

-- ------------------------------------------------------------
-- 1) JOIN: detalle de cada perrito con su raza, color principal
--    y sus colores adicionales (soporta GET /perritos y GET /perritos/:id)
-- ------------------------------------------------------------
SELECT
    p.id,
    p.nombre,
    p.foto_archivo,
    r.nombre                              AS raza,
    cp.nombre                              AS color_principal,
    GROUP_CONCAT(ca.nombre SEPARATOR ', ') AS colores_adicionales,
    p.latitud,
    p.longitud,
    p.fecha_registro
FROM perritos p
LEFT JOIN razas   r  ON p.raza_id = r.id
JOIN      colores cp ON p.color_principal_id = cp.id
LEFT JOIN perrito_colores pc ON pc.perrito_id = p.id
LEFT JOIN colores ca ON pc.color_id = ca.id
GROUP BY p.id
ORDER BY p.fecha_registro DESC;

-- ------------------------------------------------------------
-- 2) AGREGACIÓN: cuántos perritos hay por color principal
--    (soporta GET /estadisticas/por-color)
-- ------------------------------------------------------------
SELECT
    c.nombre       AS color,
    COUNT(p.id)    AS total_perritos
FROM colores c
LEFT JOIN perritos p ON p.color_principal_id = c.id
GROUP BY c.id, c.nombre
ORDER BY total_perritos DESC;

-- ------------------------------------------------------------
-- 3) AGREGACIÓN (extra): perritos por zona, redondeando
--    coordenadas a 2 decimales (~1.1 km) como "zona" aproximada.
--    Útil para el punto del PDF de "agregación por zona".
-- ------------------------------------------------------------
SELECT
    ROUND(latitud, 2)  AS zona_lat,
    ROUND(longitud, 2) AS zona_long,
    COUNT(*)           AS total_perritos
FROM perritos
GROUP BY zona_lat, zona_long
ORDER BY total_perritos DESC;

-- ------------------------------------------------------------
-- 4) VERIFICACIÓN DE IDEMPOTENCIA
--    Si el guardado idempotente funciona bien, esta consulta
--    SIEMPRE debe devolver 0 filas, incluso después de simular
--    un doble envío del formulario.
-- ------------------------------------------------------------
SELECT idempotency_key, COUNT(*) AS veces
FROM perritos
GROUP BY idempotency_key
HAVING COUNT(*) > 1;
