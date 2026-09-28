// backend/routes/imagenes.js
//
// GET /api/imagenes/:archivo — sirve una foto a través de un endpoint del
// backend. NO se expone la carpeta RUTA_IMAGENES directamente (el PDF lo
// prohíbe): cada petición pasa por este código, que decide qué archivo
// se entrega.
//
// Medidas de seguridad:
// - path.basename() descarta cualquier ruta que venga en el parámetro
//   (por ejemplo "../../.env" queda reducido a ".env").
// - La opción { root } de sendFile obliga a que el archivo se busque
//   únicamente dentro de RUTA_IMAGENES.

const express = require('express');
const path = require('path');
const { RUTA_IMAGENES } = require('../middleware/upload');

const router = express.Router();

router.get('/:archivo', (req, res) => {
    const archivo = path.basename(req.params.archivo);

    res.sendFile(archivo, { root: path.resolve(RUTA_IMAGENES) }, (err) => {
        if (err && !res.headersSent) {
            res.status(404).json({ error: 'Imagen no encontrada' });
        }
    });
});

module.exports = router;