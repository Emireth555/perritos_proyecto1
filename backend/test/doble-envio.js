// backend/tests/doble-envio.js
//
// PRUEBA DEL DOBLE ENVÍO (idempotencia del registro)
//
// Simula lo que pasa cuando el usuario presiona "Enviar" dos veces, o el
// celular reintenta por mala señal: se manda EL MISMO registro dos veces,
// con la misma clave de idempotencia. Un guardado idempotente debe:
//   1. Crear el perrito la primera vez (201).
//   2. Responder lo mismo la segunda vez (200), con el MISMO id.
//   3. Conservar el registro original (mismo nombre, foto y fecha).
//   4. No crear un perrito nuevo (el total sube en 1, no en 2).
//
// Cómo correrlo (con el servidor prendido en otra ventana):
//   cd backend
//   node tests/doble-envio.js
//
// Requiere Node 18 o superior (usa fetch, FormData y Blob integrados).
// Si el servidor no está en localhost:3000:
//   $env:API_URL="http://otra-direccion:3000"; node tests/doble-envio.js
//
// Limpieza opcional del perrito de prueba que deja cada corrida:
//   DELETE FROM perritos WHERE nombre = 'PRUEBA doble envio';
//   (sus colores adicionales se borran solos por ON DELETE CASCADE)

const { randomUUID } = require('crypto');

const BASE = process.env.API_URL || 'http://localhost:3000';

// PNG válido de 1x1 píxel, para no depender de ningún archivo externo.
// Pasa la validación por magic bytes del backend.
const PNG_1X1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGPY0BQDAAN0AY8YsVI5AAAAAElFTkSuQmCC',
  'base64'
);

// Arma un formulario idéntico cada vez (mismos datos, misma clave).
// Se crea de nuevo en cada envío porque un FormData se consume al mandarlo.
function crearFormulario(clave) {
  const form = new FormData();
  form.append('idempotency_key', clave);
  form.append('nombre', 'PRUEBA doble envio');
  form.append('color_principal_id', '1');
  form.append('colores_adicionales', JSON.stringify([2]));
  form.append('latitud', '25.4260');
  form.append('longitud', '-100.9959');
  form.append('foto', new Blob([PNG_1X1], { type: 'image/png' }), 'prueba.png');
  return form;
}

async function enviar(clave) {
  const res = await fetch(`${BASE}/api/perritos`, {
    method: 'POST',
    body: crearFormulario(clave),
  });
  return { status: res.status, cuerpo: await res.json() };
}

async function contarPerritos() {
  const res = await fetch(`${BASE}/api/perritos`);
  const lista = await res.json();
  return lista.length;
}

async function main() {
  const clave = randomUUID();
  console.log(`Servidor: ${BASE}`);
  console.log(`Clave de idempotencia de esta prueba: ${clave}\n`);

  const totalAntes = await contarPerritos();

  const primero = await enviar(clave);
  console.log(`1er envío -> HTTP ${primero.status}, id ${primero.cuerpo.id}`);

  const segundo = await enviar(clave);
  console.log(`2do envío -> HTTP ${segundo.status}, id ${segundo.cuerpo.id}`);

  const totalDespues = await contarPerritos();
  console.log(`Total de perritos: ${totalAntes} -> ${totalDespues}\n`);

  const p = primero.cuerpo;
  const s = segundo.cuerpo;

  const verificaciones = [
    ['El primer envío crea el registro (201)', primero.status === 201],
    ['El segundo envío responde 200, no error de duplicado', segundo.status === 200],
    ['Ambos envíos devuelven el mismo id', p.id !== undefined && p.id === s.id],
    ['Se conserva el registro original (nombre, foto y fecha iguales)',
      p.nombre === s.nombre &&
      p.foto_archivo === s.foto_archivo &&
      p.fecha_registro === s.fecha_registro],
    ['No se creó un perrito nuevo (el total subió en 1, no en 2)',
      totalDespues - totalAntes === 1],
  ];

  let todoBien = true;
  for (const [descripcion, ok] of verificaciones) {
    console.log(`${ok ? 'PASA ' : 'FALLA'}  ${descripcion}`);
    if (!ok) todoBien = false;
  }

  console.log(
    todoBien
      ? '\nRESULTADO: el guardado es idempotente.'
      : '\nRESULTADO: la prueba falló, revisa el detalle de arriba.'
  );
  process.exit(todoBien ? 0 : 1);
}

main().catch((err) => {
  console.error(
    `\nNo se pudo completar la prueba: ${err.message}\n` +
    `¿Está corriendo el servidor (node server.js) en ${BASE}?`
  );
  process.exit(1);
});