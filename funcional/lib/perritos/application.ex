defmodule Perritos.Application do
  @moduledoc "Arranca el servidor HTTP del servicio funcional."

  use Application

  def start(_tipo, _args) do
    hijos = [
      {Bandit, plug: Perritos.Router, ip: :any, port: 4000}
    ]

    Supervisor.start_link(hijos, strategy: :one_for_one, name: Perritos.Supervisor)
  end
end