// app.js — conecta el formulario, el mapa y las pestañas.
// Los IDs usados aquí coinciden exactamente con los del HTML del formulario.

const API = '/api';
const API_F = '/f'; // servicio funcional (Elixir) (#13)

// Genera la clave de idempotencia (un UUID versión 4) que identifica cada intento de registro.
// Se usa crypto.randomUUID() cuando existe, pero esa función solo está disponible en
// https o localhost. Si abrimos la app desde el celular por http://192.168.x.x no existe,
// así que el "plan B" arma el UUID a mano con crypto.getRandomValues(), que sí funciona en http:
//   1. genera 16 bytes aleatorios
//   2. fija los bits de versión (4) y de variante para que sea un UUID válido
//   3. convierte cada byte a hexadecimal y los une con guiones en formato 8-4-4-4-12
function generarClave() {
  if (crypto.randomUUID) return crypto.randomUUID();
  const b = crypto.getRandomValues(new Uint8Array(16));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  const h = [...b].map((x) => x.toString(16).padStart(2, '0'));
  return `${h.slice(0, 4).join('')}-${h.slice(4, 6).join('')}-${h.slice(6, 8).join('')}-${h.slice(8, 10).join('')}-${h.slice(10).join('')}`;
}

// ---------------------------------------------------------------------------
// Navegación por pestañas
// ---------------------------------------------------------------------------
document.querySelectorAll('.tab').forEach((btn) => {
  btn.addEventListener('click', () => mostrarVista(btn.dataset.vista));
});

function mostrarVista(nombre) {
  document.querySelectorAll('.vista').forEach((v) => v.classList.add('hidden'));
  document.getElementById(`vista-${nombre}`).classList.remove('hidden');
  // (#13) el panel de filtros solo se ve en Mapa y Lista
  document.getElementById('form-filtros').classList.toggle('hidden', !['mapa', 'lista'].includes(nombre));
  document.querySelectorAll('.tab').forEach((b) => b.classList.remove('activo'));
  document.querySelector(`.tab[data-vista="${nombre}"]`)?.classList.add('activo');

  if (nombre === 'mapa') cargarMapaGeneral();
  if (nombre === 'lista') cargarLista();
}

// ---------------------------------------------------------------------------
// Idempotencia: una clave por "sesión de formulario", se manda en cada intento
// ---------------------------------------------------------------------------
let idempotencyKey = generarClave();
document.getElementById('idempotency_key').value = idempotencyKey;

function reiniciarClaveIdempotencia() {
  idempotencyKey = generarClave();
  document.getElementById('idempotency_key').value = idempotencyKey;
}

// ---------------------------------------------------------------------------
// Catálogos: llenan raza, color principal y los dos selects de color extra
// ---------------------------------------------------------------------------
async function cargarCatalogos() {
  const [razas, colores] = await Promise.all([
    fetch(`${API}/razas`).then((r) => r.json()),
    fetch(`${API}/colores`).then((r) => r.json()),
  ]);

  const selectRaza = document.getElementById('raza_id');
  selectRaza.innerHTML =
    '<option value="">Sin raza definida / criollo</option>' +
    razas.map((r) => `<option value="${r.id}">${r.nombre}</option>`).join('');

  const opcionesColor = colores.map((c) => `<option value="${c.id}">${c.nombre}</option>`).join('');

  document.getElementById('color_principal_id').innerHTML =
    '<option value="" disabled selected>Selecciona el color principal</option>' + opcionesColor;

  document.getElementById('color_secundario_1_id').innerHTML =
    '<option value="">Ninguno</option>' + opcionesColor;

  document.getElementById('color_secundario_2_id').innerHTML =
    '<option value="">Ninguno</option>' + opcionesColor;

  // (#13) Selects del panel de filtros: el valor es el NOMBRE, porque /f/busqueda filtra por nombre
  const aOpcion = (x) => `<option value="${x.nombre}">${x.nombre}</option>`;
  document.getElementById('f-raza').innerHTML =
    '<option value="">Cualquiera</option>' + razas.map(aOpcion).join('');
  document.getElementById('f-color').innerHTML =
    '<option value="">Cualquiera</option>' + colores.map(aOpcion).join('');
}

// ---------------------------------------------------------------------------
// Foto: preview cuando eligen archivo (cámara o galería, mismo input)
// ---------------------------------------------------------------------------
const inputCamara = document.getElementById('foto-camara');
const inputGaleria = document.getElementById('foto-galeria');
const previewContainer = document.getElementById('preview-container');
const fotoPreview = document.getElementById('foto-preview');

// La foto elegida, venga de la cámara o de la galería.
let archivoFoto = null;

// Los inputs de archivo están ocultos: cada botón "hace clic" en el suyo.
document.getElementById('btn-tomar-foto').addEventListener('click', () => inputCamara.click());
document.getElementById('btn-elegir-foto').addEventListener('click', () => inputGaleria.click());

function alElegirFoto(e) {
  const archivo = e.target.files[0];
  if (!archivo) return;
  archivoFoto = archivo;
  fotoPreview.src = URL.createObjectURL(archivo);
  previewContainer.classList.remove('hidden');
}

inputCamara.addEventListener('change', alElegirFoto);
inputGaleria.addEventListener('change', alElegirFoto);

// ---------------------------------------------------------------------------
// Mapa del formulario: pin arrastrable + botón de "mi ubicación"
// ---------------------------------------------------------------------------
let mapaFormulario, marcadorFormulario;

function iniciarMapaFormulario() {
  mapaFormulario = L.map('map').setView([25.4383, -100.9737], 13); // Saltillo por defecto
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap',
  }).addTo(mapaFormulario);

  mapaFormulario.on('click', (e) => colocarPin(e.latlng.lat, e.latlng.lng));
}

function colocarPin(lat, lng) {
  document.getElementById('latitud').value = lat;
  document.getElementById('longitud').value = lng;

  if (marcadorFormulario) {
    marcadorFormulario.setLatLng([lat, lng]);
  } else {
    marcadorFormulario = L.marker([lat, lng], { draggable: true }).addTo(mapaFormulario);
    marcadorFormulario.on('dragend', () => {
      const pos = marcadorFormulario.getLatLng();
      document.getElementById('latitud').value = pos.lat;
      document.getElementById('longitud').value = pos.lng;
    });
  }
  mapaFormulario.setView([lat, lng], mapaFormulario.getZoom());
}

document.getElementById('btn-location').addEventListener('click', () => {
  navigator.geolocation.getCurrentPosition(
    (pos) => colocarPin(pos.coords.latitude, pos.coords.longitude),
    () => mostrarAlerta('No se pudo obtener tu ubicación. Toca el mapa para colocarla a mano.', 'error')
  );
});

// ---------------------------------------------------------------------------
// Envío del formulario
// ---------------------------------------------------------------------------
document.getElementById('form-perrito').addEventListener('submit', async (e) => {
  e.preventDefault();
  ocultarAlerta();

  const nombre = document.getElementById('nombre').value.trim();
  const razaId = document.getElementById('raza_id').value;
  const colorPrincipalId = document.getElementById('color_principal_id').value;
  const colorExtra1 = document.getElementById('color_secundario_1_id').value;
  const colorExtra2 = document.getElementById('color_secundario_2_id').value;
  const latitud = document.getElementById('latitud').value;
  const longitud = document.getElementById('longitud').value;
  const archivo = archivoFoto;

  // --- Validaciones del lado del cliente ---
  if (!archivo) return mostrarAlerta('Falta la foto', 'error');
  if (!nombre) return mostrarAlerta('Falta el nombre', 'error');
  if (!colorPrincipalId) return mostrarAlerta('Falta el color principal', 'error');
  if (!latitud || !longitud) return mostrarAlerta('Falta la ubicación', 'error');

  // Arma el arreglo de colores extra, sin vacíos
  const coloresExtra = [colorExtra1, colorExtra2].filter((id) => id !== '').map(Number);

  if (coloresExtra.includes(Number(colorPrincipalId))) {
    return mostrarAlerta('Un color adicional no puede repetir el color principal', 'error');
  }
  if (new Set(coloresExtra).size !== coloresExtra.length) {
    return mostrarAlerta('No puedes elegir el mismo color adicional dos veces', 'error');
  }

  const datos = new FormData();
  datos.append('foto', archivo);
  datos.append('idempotency_key', idempotencyKey);
  datos.append('nombre', nombre);
  if (razaId) datos.append('raza_id', razaId);
  datos.append('color_principal_id', colorPrincipalId);
  datos.append('colores_adicionales', JSON.stringify(coloresExtra));
  datos.append('latitud', latitud);
  datos.append('longitud', longitud);

  const btnSubmit = document.getElementById('btn-submit');
  btnSubmit.disabled = true;
  btnSubmit.querySelector('span').textContent = 'Registrando...';

  try {
    const resp = await fetch(`${API}/perritos`, { method: 'POST', body: datos });
    const resultado = await resp.json();

    if (!resp.ok) {
      mostrarAlerta(resultado.error || 'No se pudo registrar el perrito', 'error');
      return;
    }

    mostrarAlerta(`¡${resultado.nombre} fue registrado!`, 'exito');
    document.getElementById('form-perrito').reset();
    previewContainer.classList.add('hidden');
    archivoFoto = null;
    marcadorFormulario = null;
    reiniciarClaveIdempotencia();
    setTimeout(() => mostrarVista('mapa'), 800);
  } catch (err) {
    mostrarAlerta('Error de conexión. Es seguro reintentar, no se duplicará.', 'error');
  } finally {
    btnSubmit.disabled = false;
    btnSubmit.querySelector('span').textContent = 'Registrar Perrito';
  }
});

function mostrarAlerta(texto, tipo) {
  const el = document.getElementById('alert-box');
  el.textContent = texto;
  el.classList.remove('hidden');
  el.style.background = tipo === 'error' ? '#ffe3e3' : '#dcfce7';
  el.style.color = tipo === 'error' ? '#9c1c1c' : '#166534';
}
function ocultarAlerta() {
  document.getElementById('alert-box').classList.add('hidden');
}

// ---------------------------------------------------------------------------
// Filtros de búsqueda combinada (#13)
// ---------------------------------------------------------------------------
let resultadosFiltrados = null; // null = sin búsqueda activa

// Traduce el JSON de /f/busqueda a los nombres que ya usa el frontend
function adaptar(a) {
  return {
    id: a.id,
    nombre: a.nombre,
    raza: a.raza,
    color_principal: a.colores[0],
    latitud: a.lat,
    longitud: a.lon,
    foto_archivo: a.foto,
    fecha_registro: a.fecha,
  };
}

const CAMPOS_FILTRO = {
  raza: 'f-raza',
  color: 'f-color',
  desde: 'f-desde',
  hasta: 'f-hasta',
  lat: 'f-lat',
  lon: 'f-lon',
  metros: 'f-metros',
};

function armarQuery() {
  const params = new URLSearchParams();
  Object.entries(CAMPOS_FILTRO).forEach(([nombre, id]) => {
    const valor = document.getElementById(id).value.trim();
    if (valor) params.set(nombre, valor);
  });
  return params.toString();
}

function mensajeFiltros(texto) {
  document.getElementById('filtros-msg').textContent = texto;
}

function refrescarVistaActual() {
  const actual = document.querySelector('.tab.activo').dataset.vista;
  if (actual === 'lista') cargarLista();
  if (actual === 'mapa') cargarMapaGeneral();
}

// Devuelve los resultados filtrados si hay búsqueda activa; si no, todos (API del P1)
async function obtenerPerritos() {
  if (resultadosFiltrados) return resultadosFiltrados;
  const resp = await fetch(`${API}/perritos`);
  return resp.ok ? resp.json() : [];
}

document.getElementById('form-filtros').addEventListener('submit', async (e) => {
  e.preventDefault();

  // El radio necesita los tres campos juntos
  const radio = ['f-lat', 'f-lon', 'f-metros'].map((id) => document.getElementById(id).value.trim());
  const llenos = radio.filter((v) => v !== '').length;
  if (llenos > 0 && llenos < 3) {
    return mensajeFiltros('Para buscar por radio llena latitud, longitud y metros.');
  }

  try {
    const resp = await fetch(`${API_F}/busqueda?${armarQuery()}`);
    const cuerpo = await resp.json();
    if (!resp.ok) return mensajeFiltros(cuerpo.error || 'No se pudo buscar.');

    resultadosFiltrados = cuerpo.map(adaptar);
    mensajeFiltros(`${resultadosFiltrados.length} resultado(s).`);
    refrescarVistaActual();
  } catch (err) {
    mensajeFiltros('Error de conexión con el servicio de búsqueda.');
  }
});

document.getElementById('btn-filtro-limpiar').addEventListener('click', () => {
  document.getElementById('form-filtros').reset();
  resultadosFiltrados = null;
  mensajeFiltros('');
  refrescarVistaActual();
});

document.getElementById('btn-filtro-gps').addEventListener('click', () => {
  navigator.geolocation.getCurrentPosition(
    (pos) => {
      document.getElementById('f-lat').value = pos.coords.latitude;
      document.getElementById('f-lon').value = pos.coords.longitude;
    },
    () => mensajeFiltros('No se pudo obtener tu ubicación. Escribe las coordenadas.')
  );
});

// ---------------------------------------------------------------------------
// Mapa general (pestaña "Mapa")
// ---------------------------------------------------------------------------
let mapaGeneral, capaMarcadores;

async function cargarMapaGeneral() {
  // El mapa se crea SIEMPRE, aunque no haya backend/datos todavía.
  if (!mapaGeneral) {
    mapaGeneral = L.map('mapa-general').setView([25.4383, -100.9737], 12);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap',
    }).addTo(mapaGeneral);
    capaMarcadores = L.layerGroup().addTo(mapaGeneral); // (#13) capa que se puede limpiar
  }

  // Leaflet se crea mientras la pestaña todavía está oculta (display:none),
  // así que "piensa" que mide 0x0. invalidateSize() lo obliga a recalcular
  // su tamaño real ahora que la pestaña ya es visible.
  setTimeout(() => mapaGeneral.invalidateSize(), 100);

  // Los marcadores son "extra": si falla (BD aún no existe), el mapa se
  // sigue viendo vacío en vez de romperse.
  try {
    const perritos = await obtenerPerritos();
    capaMarcadores.clearLayers(); // (#13) evita marcadores duplicados al filtrar

    perritos
      .filter((p) => p.latitud && p.longitud)
      .forEach((p) => {
        L.marker([p.latitud, p.longitud])
          .addTo(capaMarcadores)
          .bindPopup(
            `<b>${p.nombre}</b><br/>${p.color_principal}<br/><img src="${API}/imagenes/${p.foto_archivo}" width="100"/>`
          );
      });
  } catch (err) {
    // Sin conexión al backend todavía — el mapa vacío es un resultado válido.
    console.log('Aún no hay conexión con el backend para cargar perritos en el mapa.');
  }
}

// ---------------------------------------------------------------------------
// Lista con miniatura + detalle (pestaña "Lista")
// ---------------------------------------------------------------------------
async function cargarLista() {
  const contenedor = document.getElementById('lista-perritos');

  let perritos = [];
  try {
    perritos = await obtenerPerritos();
  } catch (err) {
    console.log('Aún no hay conexión con el backend para cargar la lista.');
  }

  if (perritos.length === 0) {
    const texto = resultadosFiltrados
      ? 'Ningún perrito coincide con los filtros.'
      : 'Todavía no hay perritos registrados.';
    contenedor.innerHTML = `<p class="ayuda">${texto}</p>`;
    return;
  }

  contenedor.innerHTML = perritos
    .map(
      (p) => `
    <div class="tarjeta-perrito" data-id="${p.id}">
      <img src="${API}/imagenes/${p.foto_archivo}" alt="${p.nombre}" />
      <div>
        <strong>${p.nombre}</strong><br/>
        <span>${p.raza || 'Sin raza definida'} · ${p.color_principal}</span>
      </div>
    </div>`
    )
    .join('');

  contenedor.querySelectorAll('.tarjeta-perrito').forEach((card) => {
    card.addEventListener('click', () => verDetalle(card.dataset.id));
  });
}

async function verDetalle(id) {
  const p = await fetch(`${API}/perritos/${id}`).then((r) => r.json());
  document.getElementById('detalle-contenido').innerHTML = `
    <img src="${API}/imagenes/${p.foto_archivo}" style="width:100%; border-radius:12px" />
    <h2>${p.nombre}</h2>
    <p><b>Raza:</b> ${p.raza || 'Sin raza definida'}</p>
    <p><b>Color principal:</b> ${p.color_principal}</p>
    <p><b>Colores adicionales:</b> ${p.colores_adicionales.join(', ') || 'Ninguno'}</p>
    <p><b>Registrado:</b> ${new Date(p.fecha_registro).toLocaleString()}</p>
  `;
  document.querySelectorAll('.vista').forEach((v) => v.classList.add('hidden'));
  document.getElementById('form-filtros').classList.add('hidden'); // (#13)
  document.getElementById('vista-detalle').classList.remove('hidden');
}

document.getElementById('btn-volver-lista').addEventListener('click', () => mostrarVista('lista'));

// ---------------------------------------------------------------------------
// Arranque
// ---------------------------------------------------------------------------
cargarCatalogos();
iniciarMapaFormulario();