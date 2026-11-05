-- ============================================================
-- 04_avistamientos_masivos.sql
-- Datos de muestra para el Proyecto 2: 100 avistamientos nuevos
-- (más 8 posibles duplicados) sobre los 15 de 03_datos_prueba.sql.
--
-- Características de los datos:
--   * Coordenadas repartidas en 5 zonas de Saltillo, unas más
--     densas que otras (sirve para zonas/estadísticas/ruta).
--   * Fechas entre 2026-08-16 y 2026-11-04 (hay perros que no se
--     han vuelto a ver en semanas).
--   * ~1 de cada 6 sin raza; 0, 1 o 2 colores adicionales.
--   * 8 posibles duplicados: mismo perro con otro nombre, a ~55 m
--     y 3 días después, con los mismos colores y raza.
--
-- Se puede volver a correr: borra sólo lo que él mismo insertó
-- (idempotency_key que empieza con 'masivo-' o 'dup-masivo-').
-- Las fotos reutilizan perrito_001.jpg ... perrito_015.jpg.
-- ============================================================

SET NAMES utf8mb4;
USE perritos_db;

-- Limpieza de una corrida anterior (perrito_colores se borra en cascada)
DELETE FROM perritos
WHERE idempotency_key LIKE 'masivo-%' OR idempotency_key LIKE 'dup-masivo-%';

-- ------------------------------------------------------------
-- 1) 100 avistamientos base
-- ------------------------------------------------------------
INSERT INTO perritos
    (idempotency_key, nombre, foto_archivo, raza_id,
     color_principal_id, latitud, longitud, fecha_registro)
WITH RECURSIVE
seq AS (
    SELECT 1 AS i
    UNION ALL
    SELECT i + 1 FROM seq WHERE i < 100
),
col AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn FROM colores
),
raz AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn FROM razas
)
SELECT
    CONCAT('masivo-', LPAD(s.i, 4, '0')),
    ELT(1 + MOD(s.i, 40),
        'Bruno','Lola','Rex','Chispa','Boby','Mía','Zeus','Frida','Coco','Lucky',
        'Sombra','Tigre','Pelusa','Princesa','Apolo','Kiko','Daisy','Rufus','Nena','Osito',
        'Mochi','Chiquis','Bandido','Gordo','Perla','Tequila','Salsa','Taco','Chorizo','Mezcal',
        'Oreo','Pulgas','Rayo','Valiente','Chilo','Mora','Fiona','Gus','Hachi','Ícaro'),
    CONCAT('perrito_', LPAD(1 + MOD(s.i, 15), 3, '0'), '.jpg'),
    CASE WHEN MOD(s.i, 6) = 0 THEN NULL ELSE r.id END,
    c.id,
    -- latitud = centro de la zona + desplazamiento de hasta ~330 m
    CASE MOD(s.i, 10)
        WHEN 0 THEN 25.4232 WHEN 1 THEN 25.4232 WHEN 2 THEN 25.4232 WHEN 3 THEN 25.4232
        WHEN 4 THEN 25.4300 WHEN 5 THEN 25.4300
        WHEN 6 THEN 25.4180 WHEN 7 THEN 25.4180
        WHEN 8 THEN 25.4410
        ELSE 25.4270
    END + (MOD(s.i * 37, 21) - 10) * 0.0003,
    -- longitud = centro de la zona + desplazamiento
    CASE MOD(s.i, 10)
        WHEN 0 THEN -101.0000 WHEN 1 THEN -101.0000 WHEN 2 THEN -101.0000 WHEN 3 THEN -101.0000
        WHEN 4 THEN -100.9800 WHEN 5 THEN -100.9800
        WHEN 6 THEN -100.9900 WHEN 7 THEN -100.9900
        WHEN 8 THEN -101.0050
        ELSE -101.0100
    END + (MOD(s.i * 53, 21) - 10) * 0.0003,
    '2026-08-16 00:00:00'
        + INTERVAL MOD(s.i * 29, 81) DAY
        + INTERVAL (7 + MOD(s.i * 7, 13)) HOUR
        + INTERVAL MOD(s.i * 11, 60) MINUTE
FROM seq s
JOIN col c ON c.rn = MOD(s.i * 7, (SELECT COUNT(*) FROM colores)) + 1
LEFT JOIN raz r ON r.rn = MOD(s.i * 5, (SELECT COUNT(*) FROM razas)) + 1;

-- ------------------------------------------------------------
-- 2) Primer color adicional (2 de cada 3 perros)
--    Siempre distinto del principal: se corre 1 a 3 lugares en el catálogo.
-- ------------------------------------------------------------
INSERT INTO perrito_colores (perrito_id, color_id)
SELECT p.id, ce.id
FROM perritos p
JOIN (SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn FROM colores) cp
     ON cp.id = p.color_principal_id
JOIN (SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn FROM colores) ce
     ON ce.rn = MOD(cp.rn + MOD(p.id, 3), (SELECT COUNT(*) FROM colores)) + 1
WHERE p.idempotency_key LIKE 'masivo-%'
  AND MOD(p.id, 3) <> 0;

-- ------------------------------------------------------------
-- 3) Segundo color adicional (1 de cada 5 perros)
--    Se corre 4 o 5 lugares: nunca coincide con el principal ni con el primero.
-- ------------------------------------------------------------
INSERT INTO perrito_colores (perrito_id, color_id)
SELECT p.id, ce.id
FROM perritos p
JOIN (SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn FROM colores) cp
     ON cp.id = p.color_principal_id
JOIN (SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn FROM colores) ce
     ON ce.rn = MOD(cp.rn + 3 + MOD(p.id, 2), (SELECT COUNT(*) FROM colores)) + 1
WHERE p.idempotency_key LIKE 'masivo-%'
  AND MOD(p.id, 5) = 0
  AND MOD(p.id, 3) <> 0;

-- ------------------------------------------------------------
-- 4) Posibles duplicados: los perros masivo-0005 a masivo-0012 reportados
--    otra vez con otro nombre, ~55 m más allá y 3 días después.
-- ------------------------------------------------------------
INSERT INTO perritos
    (idempotency_key, nombre, foto_archivo, raza_id,
     color_principal_id, latitud, longitud, fecha_registro)
SELECT
    CONCAT('dup-', o.idempotency_key),
    ELT(1 + MOD(o.id, 8), 'Chato','Güero','Manchitas','Paco','Lobo','Peludo','Trueno','Rufo'),
    o.foto_archivo,
    o.raza_id,
    o.color_principal_id,
    o.latitud + 0.0004,
    o.longitud + 0.0003,
    o.fecha_registro + INTERVAL 3 DAY
FROM perritos o
WHERE o.idempotency_key BETWEEN 'masivo-0005' AND 'masivo-0012';

-- Los duplicados heredan los colores adicionales del original
INSERT INTO perrito_colores (perrito_id, color_id)
SELECT d.id, pc.color_id
FROM perritos d
JOIN perritos o  ON d.idempotency_key = CONCAT('dup-', o.idempotency_key)
JOIN perrito_colores pc ON pc.perrito_id = o.id;
