defmodule Perritos.Datos do
  @moduledoc "Acceso a datos compartido con #14. Una sola consulta base."

  alias Perritos.{Avistamiento, Consulta}

  @consulta_base """
  SELECT p.id, p.nombre, p.foto_archivo, p.latitud, p.longitud, p.fecha_registro,
         r.nombre AS raza,
         c.nombre AS color_principal,
         (SELECT GROUP_CONCAT(c2.nombre SEPARATOR '|')
            FROM perrito_colores pc
            JOIN colores c2 ON c2.id = pc.color_id
           WHERE pc.perrito_id = p.id) AS extras
    FROM perritos p
    LEFT JOIN razas r ON r.id = p.raza_id
    JOIN colores c ON c.id = p.color_principal_id
  """

  def avistamientos, do: buscar(%{})

  def buscar(criterios) do
    {where, params} = Consulta.where(criterios)

    :db
    |> MyXQL.query!(@consulta_base <> where <> " ORDER BY p.fecha_registro DESC", params)
    |> Map.fetch!(:rows)
    |> Enum.map(&a_avistamiento/1)
  end

  defp a_avistamiento([id, nombre, foto, lat, lon, fecha, raza, principal, extras]) do
    %Avistamiento{
      id: id,
      nombre: nombre,
      raza: raza,
      colores: [principal | separar(extras)],
      lat: Decimal.to_float(lat),
      lon: Decimal.to_float(lon),
      foto: foto,
      fecha: fecha
    }
  end

  defp separar(nil), do: []
  defp separar(texto), do: String.split(texto, "|")
end