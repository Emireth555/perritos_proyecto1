-- ============================================================
-- Proyecto: Registro de perritos de la calle
-- Rol: DBA
-- Archivo: schema.sql  (DDL - definición de estructura)
-- Motor objetivo: MySQL 8.0+
--
-- Cómo correrlo:
--   Windows (cmd, desde la raíz del proyecto):
--     mysql -u root -p --default-character-set=utf8mb4 < database\schema.sql
--   Linux / macOS:
--     mysql -u root -p --default-character-set=utf8mb4 < database/schema.sql
--   MySQL Workbench: File > Open SQL Script > Execute (rayo amarillo)
--
-- ATENCIÓN: este script BORRA y recrea las tablas (DROP TABLE IF EXISTS).
-- Después de correrlo hay que volver a cargar los datos de prueba.
-- El usuario de la aplicación (perritos_app) NO se ve afectado: sus
-- permisos sobre perritos_db.* siguen vigentes.
-- ============================================================

SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS perritos_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Si la base ya existía con otra codificación, la forzamos a utf8mb4
ALTER DATABASE perritos_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE perritos_db;

-- ------------------------------------------------------------
-- Limpieza previa (orden inverso a las llaves foráneas)
-- Permite volver a ejecutar el script sin errores.
-- Al borrar perrito_colores también se borra su trigger.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS perrito_colores;
DROP TABLE IF EXISTS perritos;
DROP TABLE IF EXISTS razas;
DROP TABLE IF EXISTS colores;

-- ------------------------------------------------------------
-- Catálogo: razas
-- ------------------------------------------------------------
CREATE TABLE razas (
    id      INT AUTO_INCREMENT PRIMARY KEY,
    nombre  VARCHAR(80) NOT NULL,
    UNIQUE KEY uq_razas_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Catálogo: colores
-- ------------------------------------------------------------
CREATE TABLE colores (
    id      INT AUTO_INCREMENT PRIMARY KEY,
    nombre  VARCHAR(40) NOT NULL,
    UNIQUE KEY uq_colores_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Tabla principal: perritos
-- ------------------------------------------------------------
CREATE TABLE perritos (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    idempotency_key     VARCHAR(64)     NOT NULL,
    nombre              VARCHAR(100)    NOT NULL,
    foto_archivo        VARCHAR(255)    NOT NULL,
    raza_id             INT             NULL,
    color_principal_id  INT             NOT NULL,
    latitud             DECIMAL(10,7)   NOT NULL,
    longitud            DECIMAL(10,7)   NOT NULL,
    fecha_registro      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_perritos_idempotency (idempotency_key),

    -- nombre no puede ser solo espacios (requisito del PDF)
    -- requiere MySQL 8.0.16+; si tu servidor es más viejo, borra esta línea
    CONSTRAINT chk_perritos_nombre_no_vacio CHECK (TRIM(nombre) <> ''),

    CONSTRAINT fk_perritos_raza
        FOREIGN KEY (raza_id) REFERENCES razas(id)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT fk_perritos_color_principal
        FOREIGN KEY (color_principal_id) REFERENCES colores(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Tabla relacional: perrito_colores (0 a 2 colores adicionales)
-- ------------------------------------------------------------
CREATE TABLE perrito_colores (
    perrito_id  INT NOT NULL,
    color_id    INT NOT NULL,

    PRIMARY KEY (perrito_id, color_id),

    CONSTRAINT fk_pc_perrito
        FOREIGN KEY (perrito_id) REFERENCES perritos(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_pc_color
        FOREIGN KEY (color_id) REFERENCES colores(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Índices para las consultas declarativas del backend
-- (JOINs y agregaciones por color / fecha / raza)
-- ------------------------------------------------------------
CREATE INDEX idx_perritos_fecha           ON perritos(fecha_registro);
CREATE INDEX idx_perritos_color_principal ON perritos(color_principal_id);
CREATE INDEX idx_perritos_raza            ON perritos(raza_id);

-- ============================================================
-- OPCIONAL PERO RECOMENDADO: refuerzo de la regla de negocio
-- "0 a 2 colores adicionales, sin repetir el color principal
--  ni repetir un color" a nivel de base de datos.
--
-- El backend YA debe validar esto (así lo pide el PDF), pero
-- un trigger es una segunda línea de defensa: si mañana alguien
-- inserta directo con un script o otra app, la regla se respeta
-- igual. Los triggers con SIGNAL existen desde MySQL 5.5.
--
-- Nota: si quien corre este script NO es root y el servidor tiene
-- el binlog activado (por defecto en MySQL 8), crear el trigger puede
-- fallar con el error 1419. Córrelo con root o con un usuario con
-- privilegio SET_USER_ID.
-- ============================================================
DELIMITER $$

CREATE TRIGGER trg_perrito_colores_bi
BEFORE INSERT ON perrito_colores
FOR EACH ROW
BEGIN
    DECLARE v_principal INT;
    DECLARE v_count INT;

    SELECT color_principal_id INTO v_principal
    FROM perritos WHERE id = NEW.perrito_id;

    IF NEW.color_id = v_principal THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El color adicional no puede repetir el color principal';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM perrito_colores WHERE perrito_id = NEW.perrito_id;

    IF v_count >= 2 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un perrito no puede tener más de 2 colores adicionales';
    END IF;
END$$

DELIMITER ;

-- Nota: repetir el MISMO color adicional dos veces ya es imposible
-- por sí solo, porque (perrito_id, color_id) es PRIMARY KEY compuesta.