defmodule Perritos.BusquedaHttp do
  @moduledoc "Cáscara de GET /f/busqueda: parsea, consulta, afina con el núcleo y responde JSON."

  import Plug.Conn
  alias Perritos.{Busqueda, Datos, Parametros}

  def manejar(conn) do
    conn = fetch_query_params(conn)
    conn.query_params |> Parametros.parsear() |> responder(conn)
  end

  defp responder({:ok, criterios}, conn) do
    filtro = criterios |> Busqueda.filtros() |> Busqueda.todos()

    criterios
    |> Datos.buscar()
    |> Busqueda.aplicar_filtro(filtro)
    |> Enum.map(&Map.from_struct/1)
    |> enviar(conn, 200)
  end

  defp responder({:error, mensaje}, conn), do: enviar(%{error: mensaje}, conn, 400)

  defp enviar(cuerpo, conn, estado) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(estado, Jason.encode!(cuerpo))
  end
end