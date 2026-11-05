// ruta.js — Ruta de rescate (issue #14).
// Usa el mapa de la pestaña "Mapa" (variable global mapaGeneral de app.js)
// y le pide la ruta al servicio Elixir con una ruta relativa: /f/ruta.
// El cálculo NO se hace aquí: el frontend sólo manda el punto de partida
// y dibuja lo que regresa el servicio.

(() => {
  const SERVICIO = '/f';
  let capa = null; // grupo de capas con la línea, la salida y las paradas
  let esperandoClic = false;

  const $ = (id) => document.getElementById(id);

  function aviso(texto) {
    $('ruta-resumen').textContent = texto;
  }

  function limpiar() {
    if (capa) {
      capa.remove();
      capa = null;
    }
    aviso('');
    $('ruta-lista').innerHTML = '';
    $('btn-ruta-limpiar').classList.add('hidden');
  }

  function dibujar(inicio, ruta) {
    limpiar();

    if (ruta.orden.length === 0) {
      aviso('No hay perritos en ese radio. Prueba con uno más grande.');
      return;
    }

    capa = L.layerGroup().addTo(mapaGeneral);

    const puntos = [inicio, ...ruta.orden.map((p) => [p.lat, p.lon])];
    L.polyline(puntos, { color: '#4f46e5', weight: 4, opacity: 0.8 }).addTo(capa);

    L.circleMarker(inicio, { radius: 9, color: '#16a34a', fillColor: '#22c55e', fillOpacity: 1 })
      .bindTooltip('Salida')
      .addTo(capa);

    ruta.orden.forEach((p, i) => {
      const icono = L.divIcon({
        className: 'marcador-ruta',
        html: `<span>${i + 1}</span>`,
        iconSize: [28, 28],
      });

      const popup = document.createElement('div');
      const nombre = document.createElement('b');
      nombre.textContent = p.nombre;
      popup.append(nombre, ` · ${Math.round(p.distancia_m)} m desde la parada anterior`);

      L.marker([p.lat, p.lon], { icon: icono }).bindPopup(popup).addTo(capa);

      const item = document.createElement('li');
      item.textContent = `${p.nombre} (${Math.round(p.distancia_m)} m)`;
      $('ruta-lista').appendChild(item);
    });

    mapaGeneral.fitBounds(puntos, { padding: [30, 30] });

    const km = (ruta.distancia_total_m / 1000).toFixed(2);
    aviso(`${ruta.orden.length} paradas · ${km} km en total`);
    $('btn-ruta-limpiar').classList.remove('hidden');
  }

  async function trazar(lat, lon) {
    const radio = $('ruta-radio').value;
    aviso('Calculando ruta...');

    try {
      const resp = await fetch(`${SERVICIO}/ruta?lat=${lat}&lon=${lon}&radio=${radio}`);
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      dibujar([lat, lon], await resp.json());
    } catch (err) {
      console.log('Error al pedir la ruta:', err);
      aviso('No se pudo calcular la ruta. Intenta de nuevo en un momento.');
    }
  }

  function desdeMiUbicacion() {
    if (!navigator.geolocation) return aviso('Tu navegador no ofrece ubicación. Elige un punto en el mapa.');
    aviso('Buscando tu ubicación...');
    navigator.geolocation.getCurrentPosition(
      (pos) => trazar(pos.coords.latitude, pos.coords.longitude),
      () => aviso('No se pudo obtener tu ubicación. Elige un punto en el mapa.')
    );
  }

  function elegirPuntoEnMapa() {
    if (!mapaGeneral || esperandoClic) return;
    esperandoClic = true;
    aviso('Toca el mapa para elegir el punto de partida.');
    mapaGeneral.once('click', (e) => {
      esperandoClic = false;
      trazar(e.latlng.lat, e.latlng.lng);
    });
  }

  $('btn-ruta-gps').addEventListener('click', desdeMiUbicacion);
  $('btn-ruta-punto').addEventListener('click', elegirPuntoEnMapa);
  $('btn-ruta-limpiar').addEventListener('click', limpiar);
})();
