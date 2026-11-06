defmodule Perritos.Ruta do
  @moduledoc """
  Núcleo de la funcionalidad *ruta de rescate* (issue #14).

  Dado un punto de partida y una lista de perros, propone el orden de
  visita con el algoritmo del vecino más cercano: tomar el más cercano,
  quitarlo de la lista y repetir con lo que queda.

  Todas las funciones son puras. Los perros son mapas o structs con
  `id`, `nombre`, `lat` y `lon` (`lat` y `lon` como números, no `Decimal`).
  """

  alias Perritos.Geo

  @doc """
  Perros que están a `radio` metros o menos de `centro`.

      iex> perros = [%{id: 1, lat: 0.0, lon: 0.001}, %{id: 2, lat: 0.0, lon: 0.5}]
      iex> Perritos.Ruta.en_zona(perros, {0.0, 0.0}, 500) |> Enum.map(& &1.id)
      [1]
  """
  def en_zona(perros, centro, radio) do
    medir = distancia_desde(centro)
    Enum.filter(perros, fn perro -> medir.(perro) <= radio end)
  end

  @doc """
  Regresa una **función** que mide la distancia de `punto` a un perro.

  `criterio` es la función que calcula la distancia entre dos puntos
  `{lat, lon}`; por omisión, haversine en metros.

      iex> medir = Perritos.Ruta.distancia_desde({0.0, 0.0})
      iex> medir.(%{lat: 0.0, lon: 0.0})
      0.0
  """
  def distancia_desde(punto, criterio \\ &Geo.distancia/2) do
    fn perro -> criterio.(punto, {perro.lat, perro.lon}) end
  end

  @doc """
  Propone el orden de visita desde `inicio` y la distancia total.

  **Recibe una función** opcional (`criterio`) para medir distancias.
  Cada parada trae `distancia_m`, el tramo desde la parada anterior.
  Si dos perros empatan, gana el que viene primero en la lista.

      iex> perros = [
      ...>   %{id: 1, nombre: "Lejos", lat: 0.0, lon: 0.02},
      ...>   %{id: 2, nombre: "Cerca", lat: 0.0, lon: 0.01}
      ...> ]
      iex> ruta = Perritos.Ruta.proponer({0.0, 0.0}, perros)
      iex> Enum.map(ruta.orden, & &1.nombre)
      ["Cerca", "Lejos"]
      iex> ruta.distancia_total_m
      2223.9
  """
  def proponer(inicio, perros, criterio \\ &Geo.distancia/2)

  def proponer(_inicio, [], _criterio), do: %{orden: [], distancia_total_m: 0.0}

  def proponer(inicio, perros, criterio) when is_function(criterio, 2) do
    orden = visitar(inicio, perros, criterio)
    tramos = tramos(inicio, orden, criterio)

    %{
      orden: orden |> Enum.zip(tramos) |> Enum.map(&parada/1),
      distancia_total_m: tramos |> Enum.sum() |> redondear()
    }
  end

  # Recursión explícita: toma el más cercano, lo quita y repite con el resto.
  defp visitar(_posicion, [], _criterio), do: []

  defp visitar(posicion, pendientes, criterio) do
    siguiente = Enum.min_by(pendientes, distancia_desde(posicion, criterio))
    resto = List.delete(pendientes, siguiente)

    [siguiente | visitar({siguiente.lat, siguiente.lon}, resto, criterio)]
  end

  # Distancia de cada tramo (inicio -> 1ª parada, 1ª -> 2ª, ...) con reduce.
  defp tramos(inicio, orden, criterio) do
    {_posicion, anteriores} =
      Enum.reduce(orden, {inicio, []}, fn perro, {posicion, anteriores} ->
        destino = {perro.lat, perro.lon}
        {destino, [criterio.(posicion, destino) | anteriores]}
      end)

    Enum.reverse(anteriores)
  end

  defp parada({perro, metros}) do
    %{
      id: perro.id,
      nombre: perro.nombre,
      lat: perro.lat,
      lon: perro.lon,
      distancia_m: redondear(metros)
    }
  end

  defp redondear(numero), do: Float.round(numero * 1.0, 1)
end
