// backend/middleware/upload.js
//
// Reglas que cumple este módulo (del enunciado del proyecto):
// - Las imágenes se guardan en RUTA_IMAGENES, fuera del código del proyecto.
// - El backend genera el nombre COMPLETO del archivo (nombre y extensión
//   incluida) -- nunca usa ninguna parte del nombre que mandó el usuario.
// - Se valida que el archivo realmente sea una imagen (magic bytes), no
//   solo la extensión ni el mimetype que declara el navegador.
// - Nunca se escribe a disco un archivo que no haya pasado la validación.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const multer = require('multer');

const RUTA_IMAGENES = process.env.RUTA_IMAGENES;

if (!RUTA_IMAGENES) {
    throw new Error('Falta configurar RUTA_IMAGENES en el .env');
}

if (!fs.existsSync(RUTA_IMAGENES)) {
    fs.mkdirSync(RUTA_IMAGENES, { recursive: true });
}

// memoryStorage: el archivo vive solo en RAM hasta que lo validemos.
// Nada se escribe a disco todavía en este paso.
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 8 * 1024 * 1024 }, // 8 MB máximo, ajustable
    fileFilter: (req, file, cb) => {
        // Filtro RÁPIDO y de baja confianza: el mimetype lo declara el
        // navegador/cliente y se puede falsificar fácilmente, pero sirve
        // para rechazar de inmediato lo obviamente equivocado sin gastar
        // tiempo de procesamiento. La validación real (autoridad final)
        // es la de magic bytes en validarYGuardarImagen, más abajo.
        const tiposPermitidos = ['image/jpeg', 'image/png', 'image/webp'];
        if (!tiposPermitidos.includes(file.mimetype)) {
            return cb(new Error('Formato no permitido. Solo JPG, PNG o WEBP.'));
        }
        cb(null, true);
    },
});

// Firmas ("magic bytes") reales de cada formato -- esto es lo que de
// verdad decide si el archivo es una imagen, sin importar lo que diga
// su nombre o su mimetype declarado.
const FIRMAS = {
    jpg: [0xff, 0xd8, 0xff],
    png: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
};

function coincideFirma(buffer, firma) {
    return firma.every((byte, i) => buffer[i] === byte);
}

function detectarExtensionReal(buffer) {
    if (coincideFirma(buffer, FIRMAS.jpg)) return 'jpg';
    if (coincideFirma(buffer, FIRMAS.png)) return 'png';

    // WEBP: "RIFF" en bytes 0-3, tamaño variable en 4-7, "WEBP" en 8-11.
    const esRiff = buffer.slice(0, 4).toString('ascii') === 'RIFF';
    const esWebp = buffer.slice(8, 12).toString('ascii') === 'WEBP';
    if (esRiff && esWebp) return 'webp';

    return null; // No es ninguno de los formatos permitidos
}

// Middleware que corre DESPUÉS de upload.single('foto').
// Valida el contenido real y, solo si es válido, escribe el archivo a
// disco con un nombre 100% generado por el backend.
function validarYGuardarImagen(req, res, next) {
    if (!req.file) {
        return res.status(400).json({ error: 'Falta la foto' });
    }

    const extensionReal = detectarExtensionReal(req.file.buffer);
    if (!extensionReal) {
        return res.status(400).json({ error: 'El archivo no es una imagen válida' });
    }

    // Nombre Y extensión generados enteramente por el backend: la
    // extensión sale de lo que detectamos en los bytes, nunca del
    // nombre que mandó el usuario.
    const nombreArchivo = `${crypto.randomUUID()}.${extensionReal}`;
    const rutaCompleta = path.join(RUTA_IMAGENES, nombreArchivo);

    fs.writeFileSync(rutaCompleta, req.file.buffer);

    req.fotoArchivo = nombreArchivo;
    next();
}

module.exports = { upload, validarYGuardarImagen, RUTA_IMAGENES };