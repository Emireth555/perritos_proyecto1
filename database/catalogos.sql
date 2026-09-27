-- ============================================================
-- Archivo: 02_catalogos.sql
-- Catálogos: razas y colores (mínimo 10 de cada uno, exige el PDF)
-- Correr DESPUÉS de 01_schema.sql
-- ============================================================

USE perritos_db;

-- ------------------------------------------------------------
-- Razas (12) — la primera es obligatoria por el PDF:
-- "Sin raza definida / criollo" debe existir como OPCIÓN DEL
-- CATÁLOGO que el usuario elige, no solo dejar raza_id en NULL.
-- ------------------------------------------------------------
INSERT INTO razas (nombre) VALUES
('Sin raza definida / criollo'),
('Labrador Retriever'),
('Pastor Alemán'),
('Chihuahua'),
('Pitbull'),
('Caniche (Poodle)'),
('Salchicha (Dachshund)'),
('Golden Retriever'),
('Bulldog Francés'),
('Schnauzer'),
('Husky Siberiano'),
('Xoloitzcuintle');

-- ------------------------------------------------------------
-- Colores (12)
-- ------------------------------------------------------------
INSERT INTO colores (nombre) VALUES
('Negro'),
('Blanco'),
('Café'),
('Café claro'),
('Gris'),
('Dorado'),
('Canela'),
('Crema'),
('Atigrado'),
('Manchado (blanco y negro)'),
('Chocolate'),
('Tricolor');
