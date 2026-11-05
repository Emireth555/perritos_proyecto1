defmodule Perritos.Busqueda do
  @moduledoc """
  Núcleo puro de la búsqueda combinada (#13): sin BD, sin conn, sin reloj, sin IO.
  Cada criterio regresa un filtro (avistamiento -> boolean).
  """

  alias Perritos.Avistamiento

  @radio_tierra_m 6_371_000

  # ---------- Filtros simples ----------

  @doc """
  Filtro que acepta avistamientos de la raza dada (sin importar mayúsculas ni espacios).

      iex> filtro = Perritos.Busqueda.por_raza("Labrador")
      iex> filtro.(%Perritos.Avistamiento{raza: " labrador "})
      true
      iex> filtro.(%Perritos.Avistamiento{raza: "Poodle"})
      false
  """
  def por_raza(raza) do
    buscada = normalizar(raza)
    fn %Avistamiento{raza: r} -> normalizar(r) == buscada end
  end

  @doc """
  Filtro que acepta avistamientos que tengan el color dado entre sus colores.

      iex> filtro = Perritos.Busqueda.por_color("café")
      iex> filtro.(%Perritos.Avistamiento{colores: ["Café", "blanco"]})
      true
      iex> filtro.(%Perritos.Avistamiento{colores: ["negro"]})
      false
  """
  def por_color(color) do
    buscado = normalizar(color)

    fn %Avistamiento{colores: colores} ->
      colores
      |> Enum.map(&normalizar/1)
      |> Enum.member?(buscado)
    end
  end

  # ---------- Fechas ----------

  @doc """
  Filtro por rango de fechas, inclusivo. `nil` deja ese extremo abierto.
  La fecha del avistamiento es NaiveDateTime; los extremos son `Date`.

      iex> filtro = Perritos.Busqueda.por_fechas(~D[2026-11-01], ~D[2026-11-05])
      iex> filtro.(%Perritos.Avistamiento{fecha: ~N[2026-11-05 23:59:59]})
      true
      iex> filtro.(%Perritos.Avistamiento{fecha: ~N[2026-11-06 00:00:00]})
      false
  """
  def por_fechas(desde, hasta) do
    fn %Avistamiento{fecha: f} -> desde_ok?(f, desde) and hasta_ok?(f, hasta) end
  end

  defp desde_ok?(_fecha, nil), do: true
  defp desde_ok?(fecha, %Date{} = d), do: Date.compare(NaiveDateTime.to_date(fecha), d) != :lt

  defp hasta_ok?(_fecha, nil), do: true
  defp hasta_ok?(fecha, %Date{} = d), do: Date.compare(NaiveDateTime.to_date(fecha), d) != :gt

  # ---------- Radio (haversine) ----------

  @doc """
  Distancia en metros entre dos puntos (fórmula de haversine).

      iex> Perritos.Busqueda.distancia_m(25.42, -101.0, 25.42, -101.0)
      0.0
  """
  def distancia_m(lat1, lon1, lat2, lon2) do
    rad = :math.pi() / 180
    dlat = (lat2 - lat1) * rad
    dlon = (lon2 - lon1) * rad

    a =
      :math.pow(:math.sin(dlat / 2), 2) +
        :math.cos(lat1 * rad) * :math.cos(lat2 * rad) * :math.pow(:math.sin(dlon / 2), 2)

    2 * @radio_tierra_m * :math.asin(:math.sqrt(a))
  end

  @doc """
  Filtro: avistamientos a `metros` o menos del punto (lat, lon). El borde cuenta (<=).

      iex> filtro = Perritos.Busqueda.por_radio(25.42, -101.0, 100)
      iex> filtro.(%Perritos.Avistamiento{lat: 25.42, lon: -101.0})
      true
      iex> filtro.(%Perritos.Avistamiento{lat: 26.0, lon: -101.0})
      false
  """
  def por_radio(lat, lon, metros) do
    fn %Avistamiento{lat: a_lat, lon: a_lon} ->
      distancia_m(lat, lon, a_lat, a_lon) <= metros
    end
  end

  # ---------- Combinadores (recursivos) ----------

  @doc """
  Y lógico: un filtro que exige que TODOS se cumplan. Lista vacía: acepta todo.

      iex> Perritos.Busqueda.todos([]).(%Perritos.Avistamiento{})
      true
  """
  def todos([]), do: fn _avistamiento -> true end
  def todos([h | t]), do: fn a -> h.(a) and todos(t).(a) end

  @doc """
  O lógico: un filtro que exige que ALGUNO se cumpla. Lista vacía: no acepta nada.

      iex> Perritos.Busqueda.alguno([]).(%Perritos.Avistamiento{})
      false
  """
  def alguno([]), do: fn _avistamiento -> false end
  def alguno([h | t]), do: fn a -> h.(a) or alguno(t).(a) end

  # ---------- Función de orden superior ----------

  @doc """
  Recibe una lista y un filtro (una función) y regresa los elementos que cumplen.

      iex> Perritos.Busqueda.aplicar_filtro([1, 2, 3, 4], &(&1 > 2))
      [3, 4]
  """
  def aplicar_filtro(avistamientos, filtro) do
    avistamientos
    |> Stream.filter(filtro)
    |> Enum.to_list()
  end

  # ---------- Criterios -> lista de filtros ----------

  @doc """
  Convierte criterios (un mapa) en la lista de filtros que aplican.
  Un criterio ausente (nil) no genera filtro.

      iex> Perritos.Busqueda.filtros(%{})
      []
      iex> length(Perritos.Busqueda.filtros(%{raza: "Poodle", color: "negro"}))
      2
  """
  def filtros(criterios) do
    [
      criterios |> Map.get(:raza) |> filtro_raza(),
      criterios |> Map.get(:color) |> filtro_color(),
      filtro_fechas(Map.get(criterios, :desde), Map.get(criterios, :hasta)),
      filtro_radio(criterios)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp filtro_raza(nil), do: nil
  defp filtro_raza(r), do: por_raza(r)

  defp filtro_color(nil), do: nil
  defp filtro_color(c), do: por_color(c)

  defp filtro_fechas(nil, nil), do: nil
  defp filtro_fechas(d, h), do: por_fechas(d, h)

  defp filtro_radio(%{lat: lat, lon: lon, metros: m})
       when is_number(lat) and is_number(lon) and is_number(m),
       do: por_radio(lat, lon, m)

  defp filtro_radio(_), do: nil

  # ---------- Auxiliar ----------

  defp normalizar(nil), do: ""
  defp normalizar(texto) when is_binary(texto), do: texto |> String.trim() |> String.downcase()
end