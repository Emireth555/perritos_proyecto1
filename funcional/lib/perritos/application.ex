defmodule Perritos.Application do
  @moduledoc "Arranca el servidor HTTP del servicio funcional."

  use Application

  def start(_tipo, _args) do
    hijos = [
      {MyXQL,
       name: :db,
       hostname: System.get_env("BD_HOST", "localhost"),
       username: System.fetch_env!("BD_USUARIO"),
       password: System.fetch_env!("BD_PASSWORD"),
       database: System.fetch_env!("BD_NOMBRE")},
      {Bandit, plug: Perritos.Router, ip: :any, port: 4000}
    ]

    Supervisor.start_link(hijos, strategy: :one_for_one, name: Perritos.Supervisor)
  end
end