-- ============================================================
-- Archivo: 06_usuario_app.sql
-- Crea un usuario de MySQL exclusivo para el backend, con permisos
-- limitados solo a perritos_db (nunca uses la cuenta root en el
-- .env de una aplicación, ni siquiera en un proyecto escolar:
-- si algún día el .env se filtra o se sube por error a Git, con
-- este usuario el daño posible está acotado a esta base de datos).
--
-- Correr con la cuenta root, DESPUÉS de 01_schema.sql:
--   mysql -u root -p < 06_usuario_app.sql
-- ============================================================

-- Cambia 'CAMBIA_ESTA_CONTRASENA' por una contraseña real.
-- Esa contraseña es la que va en el .env del backend, NO en Git
-- (recuerda: el PDF exige .env.example con valores de ejemplo,
-- nunca el .env real con la contraseña verdadera).
CREATE USER IF NOT EXISTS 'perritos_app'@'localhost'
    IDENTIFIED BY 'CAMBIA_ESTA_CONTRASENA';

-- Solo lo que el backend realmente necesita: leer y escribir datos.
-- Nada de permisos para crear/borrar tablas o usuarios (eso es
-- trabajo de este script, no de la aplicación en producción).
GRANT SELECT, INSERT, UPDATE, DELETE
    ON perritos_db.*
    TO 'perritos_app'@'localhost';

FLUSH PRIVILEGES;

-- Verificación (opcional, correr después para confirmar):
-- SHOW GRANTS FOR 'perritos_app'@'localhost';
