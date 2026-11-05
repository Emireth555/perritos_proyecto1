defmodule Perritos.Datos do
  @moduledoc """
  Cáscara: lee los avistamientos de la base de datos del Proyecto 1
  (MySQL, con MyXQL) y los convierte en structs para el núcleo.

  Esta es la ÚNICA puerta a la base de datos para todas las
  funcionalidades. El núcleo nunca sabe de dónde vinieron los datos.
  """

  alias Perritos.Avistamiento

  # Una fila por perro. Los colores adicionales llegan juntos en un solo
  # texto separado por "|" (vacío -> NULL si el perro no tiene).
  @consulta """
  SELECT p.id,
         p.nombre,
         r.nombre AS raza,
         cp.nombre AS color_principal,
         p.latitud,
         p.longitud,
         p.foto_archivo,
         p.fecha_registro,
         (SELECT GROUP_CONCAT(c.nombre ORDER BY c.id SEPARATOR '|')
            FROM perrito_colores pc
            JOIN colores c ON c.id = pc.color_id
           WHERE pc.perrito_id = p.id) AS adicionales
    FROM perritos p
    LEFT JOIN razas r ON r.id = p.raza_id
    JOIN colores cp ON cp.id = p.color_principal_id
   ORDER BY p.id
  """

  @doc """
  Todos los avistamientos como `%Avistamiento{}`.

  Regresa `{:ok, lista}` o `{:error, motivo}`.
  """
  def avistamientos do
    case MyXQL.query(:db, @consulta, []) do
      {:ok, %MyXQL.Result{rows: filas}} -> {:ok, Enum.map(filas, &a_avistamiento/1)}
      {:error, error} -> {:error, error}
    end
  end

  # MyXQL entrega DECIMAL como %Decimal{}; el núcleo necesita floats.
  defp a_avistamiento([id, nombre, raza, principal, lat, lon, foto, fecha, adicionales]) do
    %Avistamiento{
      id: id,
      nombre: nombre,
      raza: raza,
      colores: [principal | separar(adicionales)],
      lat: Decimal.to_float(lat),
      lon: Decimal.to_float(lon),
      foto: foto,
      fecha: fecha
    }
  end

  defp separar(nil), do: []
  defp separar(texto), do: String.split(texto, "|")
end
