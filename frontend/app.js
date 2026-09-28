// app.js — conecta el formulario, el mapa y las pestañas.
// Los IDs usados aquí coinciden exactamente con los del HTML del formulario.

const API = '/api';

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
}

// ---------------------------------------------------------------------------
// Foto: preview cuando eligen archivo (cámara o galería, mismo input)
// ---------------------------------------------------------------------------
const inputFoto = document.getElementById('foto');
const previewContainer = document.getElementById('preview-container');
const fotoPreview = document.getElementById('foto-preview');

inputFoto.addEventListener('change', () => {
  const archivo = inputFoto.files[0];
  if (!archivo) {
    previewContainer.classList.add('hidden');
    return;
  }
  fotoPreview.src = URL.createObjectURL(archivo);
  previewContainer.classList.remove('hidden');
});

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
  const archivo = document.getElementById('foto').files[0];

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
// Mapa general (pestaña "Mapa")
// ---------------------------------------------------------------------------
let mapaGeneral;

async function cargarMapaGeneral() {
  // El mapa se crea SIEMPRE, aunque no haya backend/datos todavía.
  if (!mapaGeneral) {
    mapaGeneral = L.map('mapa-general').setView([25.4383, -100.9737], 12);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap',
    }).addTo(mapaGeneral);
  }

  // Leaflet se crea mientras la pestaña todavía está oculta (display:none),
  // así que "piensa" que mide 0x0. invalidateSize() lo obliga a recalcular
  // su tamaño real ahora que la pestaña ya es visible.
  setTimeout(() => mapaGeneral.invalidateSize(), 100);

  // Los marcadores son "extra": si falla (BD aún no existe), el mapa se
  // sigue viendo vacío en vez de romperse.
  try {
    const resp = await fetch(`${API}/perritos`);
    if (!resp.ok) return; // backend respondió con error, no hay datos aún
    const perritos = await resp.json();

    perritos
      .filter((p) => p.latitud && p.longitud)
      .forEach((p) => {
        L.marker([p.latitud, p.longitud])
          .addTo(mapaGeneral)
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
    const resp = await fetch(`${API}/perritos`);
    if (resp.ok) perritos = await resp.json();
  } catch (err) {
    console.log('Aún no hay conexión con el backend para cargar la lista.');
  }

  if (perritos.length === 0) {
    contenedor.innerHTML = `<p class="ayuda">Todavía no hay perritos registrados.</p>`;
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
  document.getElementById('vista-detalle').classList.remove('hidden');
}

document.getElementById('btn-volver-lista').addEventListener('click', () => mostrarVista('lista'));

// ---------------------------------------------------------------------------
// Arranque
// ---------------------------------------------------------------------------
cargarCatalogos();
iniciarMapaFormulario();