defmodule Perritos.Router do
  @moduledoc "Cáscara HTTP: traduce peticiones en llamadas al núcleo."

  use Plug.Router

  plug :match
  plug :dispatch

  get "/f/salud" do
    send_resp(conn, 200, "ok")
  end

  get "/f/busqueda" do
    Perritos.BusquedaHttp.manejar(conn)
  end

  get "/f/ruta" do
    conn = fetch_query_params(conn)
    params = conn.query_params

    case punto(params["lat"], params["lon"]) do
      {:ok, inicio} ->
        radio = numero(params["radio"], 1500.0)

        cuerpo =
          Perritos.Datos.avistamientos()
          |> Perritos.Ruta.en_zona(inicio, radio)
          |> then(&Perritos.Ruta.proponer(inicio, &1))
          |> Jason.encode!()

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, cuerpo)

      :parametros_invalidos ->
        send_resp(conn, 400, ~s({"error": "lat y lon son obligatorios"}))
    end
  end

  match _ do
    send_resp(conn, 404, "no encontrado")
  end

  defp punto(lat, lon), do: punto_de(decimal(lat), decimal(lon))

  defp punto_de({:ok, lat}, {:ok, lon}), do: {:ok, {lat, lon}}
  defp punto_de(_, _), do: :parametros_invalidos

  defp numero(texto, defecto) do
    case decimal(texto) do
      {:ok, n} -> n
      :error -> defecto
    end
  end

  defp decimal(texto) when is_binary(texto) do
    case Float.parse(texto) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  defp decimal(_), do: :error
end