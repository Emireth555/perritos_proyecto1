require('dotenv').config();
const path = require('path');
const express = require('express');
const cors = require('cors');

const perritosRouter = require('./routes/perritos');
const catalogosRouter = require('./routes/catalogos');
const imagenesRouter = require('./routes/imagenes');

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// --- API ---------------------------------------------------
app.use('/api/perritos', perritosRouter);
app.use('/api/imagenes', imagenesRouter); // fotos servidas por endpoint, no por carpeta expuesta
app.use('/api', catalogosRouter);

// --- Frontend ----------------------------------------------
// Solo se sirve la carpeta frontend/ (NO la raíz del repo, ni la
// carpeta de imágenes), para que app.js pueda usar rutas relativas
// como '/api/perritos'.
app.use(express.static(path.join(__dirname, '..', 'frontend')));

// --- 404 ---------------------------------------------------
app.use((req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

// --- Errores con mensajes entendibles ----------------------
// Debe ir al final. Atrapa, por ejemplo, los rechazos de multer
// (foto demasiado grande o formato no permitido) y los responde en
// JSON, en vez de la página de error genérica de Express.
app.use((err, req, res, next) => {
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(400).json({ error: 'La foto es demasiado grande (máximo 8 MB)' });
  }
  if (err.message && err.message.startsWith('Formato no permitido')) {
    return res.status(400).json({ error: err.message });
  }
  console.error(err);
  res.status(500).json({ error: 'Error interno del servidor' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});