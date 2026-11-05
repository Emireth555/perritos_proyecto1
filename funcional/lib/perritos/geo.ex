defmodule Perritos.Geo do
  @moduledoc """
  Núcleo: distancias entre coordenadas.

  Todas las funciones son puras: reciben puntos `{lat, lon}` en grados
  y regresan metros. No consultan nada de afuera.
  """

  @radio_tierra_m 6_371_000

  @doc """
  Distancia en metros entre dos puntos `{lat, lon}` (fórmula de haversine).

      iex> Perritos.Geo.distancia({25.42, -101.0}, {25.42, -101.0})
      0.0

      iex> Perritos.Geo.distancia({0.0, 0.0}, {1.0, 0.0}) |> Float.round()
      111195.0
  """
  def distancia({lat1, lon1}, {lat2, lon2}) do
    phi1 = radianes(lat1)
    phi2 = radianes(lat2)
    delta_phi = phi2 - phi1
    delta_lambda = radianes(lon2 - lon1)

    a =
      :math.pow(:math.sin(delta_phi / 2), 2) +
        :math.cos(phi1) * :math.cos(phi2) * :math.pow(:math.sin(delta_lambda / 2), 2)

    a
    |> min(1.0)
    |> :math.sqrt()
    |> :math.asin()
    |> Kernel.*(2 * @radio_tierra_m)
  end

  defp radianes(grados), do: grados * :math.pi() / 180
end
