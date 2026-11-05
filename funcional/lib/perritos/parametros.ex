defmodule Perritos.Parametros do
  @moduledoc "Convierte los parámetros de la URL (texto) en criterios tipados."

  def parsear(params) do
    with {:ok, desde} <- fecha("desde", params["desde"]),
         {:ok, hasta} <- fecha("hasta", params["hasta"]),
         {:ok, lat} <- numero("lat", params["lat"]),
         {:ok, lon} <- numero("lon", params["lon"]),
         {:ok, metros} <- numero("metros", params["metros"]) do
      {:ok,
       %{
         raza: vacio(params["raza"]),
         color: vacio(params["color"]),
         desde: desde,
         hasta: hasta,
         lat: lat,
         lon: lon,
         metros: metros
       }}
    end
  end

  defp vacio(""), do: nil
  defp vacio(valor), do: valor

  defp fecha(_campo, v) when v in [nil, ""], do: {:ok, nil}

  defp fecha(campo, v) do
    case Date.from_iso8601(v) do
      {:ok, d} -> {:ok, d}
      {:error, _} -> {:error, "#{campo} inválido"}
    end
  end

  defp numero(_campo, v) when v in [nil, ""], do: {:ok, nil}

  defp numero(campo, v) do
    case Float.parse(v) do
      {n, ""} -> {:ok, n}
      _ -> {:error, "#{campo} inválido"}
    end
  end
end