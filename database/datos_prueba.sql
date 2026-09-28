-- ============================================================
-- Archivo: datos_prueba.sql
-- 15 perritos de prueba, mínimo exigido por el PDF, con foto,
-- ubicación (zona de Saltillo, Coahuila, a modo de ejemplo) y
-- fecha de registro.
--
-- IMPORTANTE: aquí solo se guarda el NOMBRE del archivo de foto
-- (foto_archivo), no la imagen en sí. Las imágenes reales deben
-- existir físicamente en la carpeta que apunte RUTA_IMAGENES del
-- backend (fuera del repo). Avisa a tu compañera del backend para
-- que te pase 15 fotos de prueba y las coloquen ahí antes de la
-- demo, o dime y te genero unas imágenes placeholder simples.
--
-- Se usan subconsultas (SELECT id FROM ... WHERE nombre = ...)
-- en vez de números fijos: así el script no se rompe si el orden
-- de inserción de los catálogos cambia.
-- ============================================================

USE perritos_db;

INSERT INTO perritos
    (idempotency_key, nombre, foto_archivo, raza_id, color_principal_id, latitud, longitud, fecha_registro)
VALUES
('seed-perrito-001', 'Firulais',  'perrito_001.jpg',
    (SELECT id FROM razas WHERE nombre = 'Sin raza definida / criollo'),
    (SELECT id FROM colores WHERE nombre = 'Café'),
    25.4260, -100.9959, '2026-08-01 09:15:00'),

('seed-perrito-002', 'Luna',      'perrito_002.jpg',
    (SELECT id FROM razas WHERE nombre = 'Labrador Retriever'),
    (SELECT id FROM colores WHERE nombre = 'Dorado'),
    25.4310, -101.0021, '2026-08-02 11:40:00'),

('seed-perrito-003', 'Max',       'perrito_003.jpg',
    (SELECT id FROM razas WHERE nombre = 'Pastor Alemán'),
    (SELECT id FROM colores WHERE nombre = 'Negro'),
    25.4185, -100.9887, '2026-08-03 08:05:00'),

('seed-perrito-004', 'Canela',    'perrito_004.jpg',
    NULL,
    (SELECT id FROM colores WHERE nombre = 'Canela'),
    25.4402, -101.0110, '2026-08-04 16:22:00'),

('seed-perrito-005', 'Rocky',     'perrito_005.jpg',
    (SELECT id FROM razas WHERE nombre = 'Pitbull'),
    (SELECT id FROM colores WHERE nombre = 'Gris'),
    25.4290, -100.9750, '2026-08-05 07:50:00'),

('seed-perrito-006', 'Bella',     'perrito_006.jpg',
    (SELECT id FROM razas WHERE nombre = 'Caniche (Poodle)'),
    (SELECT id FROM colores WHERE nombre = 'Blanco'),
    25.4225, -100.9995, '2026-08-06 12:10:00'),

('seed-perrito-007', 'Toby',      'perrito_007.jpg',
    (SELECT id FROM razas WHERE nombre = 'Salchicha (Dachshund)'),
    (SELECT id FROM colores WHERE nombre = 'Chocolate'),
    25.4350, -100.9880, '2026-08-07 10:30:00'),

('seed-perrito-008', 'Nala',      'perrito_008.jpg',
    (SELECT id FROM razas WHERE nombre = 'Sin raza definida / criollo'),
    (SELECT id FROM colores WHERE nombre = 'Manchado (blanco y negro)'),
    25.4155, -101.0055, '2026-08-08 15:45:00'),

('seed-perrito-009', 'Thor',      'perrito_009.jpg',
    (SELECT id FROM razas WHERE nombre = 'Husky Siberiano'),
    (SELECT id FROM colores WHERE nombre = 'Gris'),
    25.4330, -100.9905, '2026-08-09 09:00:00'),

('seed-perrito-010', 'Coqueta',   'perrito_010.jpg',
    (SELECT id FROM razas WHERE nombre = 'Chihuahua'),
    (SELECT id FROM colores WHERE nombre = 'Crema'),
    25.4270, -101.0002, '2026-08-10 13:25:00'),

('seed-perrito-011', 'Duque',     'perrito_011.jpg',
    (SELECT id FROM razas WHERE nombre = 'Golden Retriever'),
    (SELECT id FROM colores WHERE nombre = 'Dorado'),
    25.4198, -100.9932, '2026-08-11 08:40:00'),

('seed-perrito-012', 'Pecas',     'perrito_012.jpg',
    NULL,
    (SELECT id FROM colores WHERE nombre = 'Atigrado'),
    25.4415, -100.9868, '2026-08-12 17:05:00'),

('seed-perrito-013', 'Kira',      'perrito_013.jpg',
    (SELECT id FROM razas WHERE nombre = 'Bulldog Francés'),
    (SELECT id FROM colores WHERE nombre = 'Blanco'),
    25.4240, -101.0130, '2026-08-13 11:15:00'),

('seed-perrito-014', 'Simón',     'perrito_014.jpg',
    (SELECT id FROM razas WHERE nombre = 'Xoloitzcuintle'),
    (SELECT id FROM colores WHERE nombre = 'Negro'),
    25.4302, -100.9791, '2026-08-14 14:50:00'),

('seed-perrito-015', 'Maple',     'perrito_015.jpg',
    (SELECT id FROM razas WHERE nombre = 'Schnauzer'),
    (SELECT id FROM colores WHERE nombre = 'Café claro'),
    25.4177, -100.9970, '2026-08-15 09:35:00');

-- ------------------------------------------------------------
-- Colores adicionales (0 a 2 por perrito, nunca el principal)
-- Referenciamos al perrito por su idempotency_key, no por id,
-- por la misma razón de robustez que arriba.
-- ------------------------------------------------------------
INSERT INTO perrito_colores (perrito_id, color_id) VALUES
-- Firulais: café + blanco
((SELECT id FROM perritos WHERE idempotency_key = 'seed-perrito-001'), (SELECT id FROM colores WHERE nombre = 'Blanco')),
-- Luna: dorado + crema
((SELECT id FROM perritos WHERE idempotency_key = 'seed-perrito-002'), (SELECT id FROM colores WHERE nombre = 'Crema')),
-- Max: negro + café + gris (2 adicionales)
((SELECT id FROM perritos WHERE idempotency_key = 'seed-perrito-003'), (SELECT id FROM colores WHERE nombre = 'Café')),
((SELECT id FROM perritos WHERE idempotency_key = 'seed-perrito-003'), (SELECT id FROM colores WHERE nombre = 'Gris')),
-- Rocky: gris + negro
((SELECT id FROM perritos WHERE idempotency_key = 'seed-perrito-005'), (SELECT id FROM colores WHERE nombre = 'Negro')),
-- Nala: manchado + negro + blanco
((SELECT id FROM perritos WHERE idempotency_key = 'seed-perrito-008'), (SELECT id FROM colores WHERE nombre = 'Negro')),
((SELECT id FROM perritos WHERE idempotency_key = 'seed-perrito-008'), (SELECT id FROM colores WHERE nombre = 'Blanco')),
-- Coqueta: crema + blanco
((SELECT id FROM perritos WHERE idempotency_key = 'seed-perrito-010'), (SELECT id FROM colores WHERE nombre = 'Blanco')),
-- Kira: blanco + café claro
((SELECT id FROM perritos WHERE idempotency_key = 'seed-perrito-013'), (SELECT id FROM colores WHERE nombre = 'Café claro')),
-- Simón: negro + tricolor
((SELECT id FROM perritos WHERE idempotency_key = 'seed-perrito-014'), (SELECT id FROM colores WHERE nombre = 'Tricolor'));

-- Firulais, Bella, Toby, Thor, Duque, Pecas y Maple se quedan
-- con SOLO su color principal (0 colores adicionales), a propósito,
-- para probar que el campo es opcional y funciona en 0, 1 y 2.
