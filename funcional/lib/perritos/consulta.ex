defmodule Perritos.Consulta do
  @moduledoc "Convierte criterios en un WHERE grueso y sus parámetros. No toca la BD."

  @metros_por_grado 111_320

  @doc """
  Convierte criterios en un WHERE grueso y sus parámetros.

      iex> Perritos.Consulta.where(%{})
      {"", []}
      iex> Perritos.Consulta.where(%{raza: "Poodle"})
      {" WHERE r.nombre = ?", ["Poodle"]}
  """
  def where(criterios) do
    [
      raza(criterios[:raza]),
      color(criterios[:color]),
      desde(criterios[:desde]),
      hasta(criterios[:hasta]),
      caja(criterios[:lat], criterios[:lon], criterios[:metros])
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.unzip()
    |> armar()
  end

  defp armar({[], _}), do: {"", []}

  defp armar({sqls, params}),
    do: {" WHERE " <> Enum.join(sqls, " AND "), List.flatten(params)}

  defp raza(nil), do: nil
  defp raza(r), do: {"r.nombre = ?", [r]}

  defp color(nil), do: nil

  defp color(c) do
    {"(c.nombre = ? OR EXISTS (SELECT 1 FROM perrito_colores pc " <>
       "JOIN colores c2 ON c2.id = pc.color_id " <>
       "WHERE pc.perrito_id = p.id AND c2.nombre = ?))", [c, c]}
  end

  defp desde(nil), do: nil
  defp desde(%Date{} = d), do: {"p.fecha_registro >= ?", [NaiveDateTime.new!(d, ~T[00:00:00])]}

  defp hasta(nil), do: nil

  defp hasta(%Date{} = d),
    do: {"p.fecha_registro < ?", [NaiveDateTime.new!(Date.add(d, 1), ~T[00:00:00])]}

  defp caja(lat, lon, m) when is_number(lat) and is_number(lon) and is_number(m) do
    dlat = m / @metros_por_grado
    dlon = m / (@metros_por_grado * :math.cos(lat * :math.pi() / 180))

    {"p.latitud BETWEEN ? AND ? AND p.longitud BETWEEN ? AND ?",
     [lat - dlat, lat + dlat, lon - dlon, lon + dlon]}
  end

  defp caja(_, _, _), do: nil
end