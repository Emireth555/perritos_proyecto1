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

  match _ do
    send_resp(conn, 404, "no encontrado")
  end
end