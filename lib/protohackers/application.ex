defmodule Protohackers.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    server_mod =
      Module.concat([
        Protohackers,
        Application.fetch_env!(:protohackers, :server),
        Server
      ])

    server_port = Application.get_env(:protohackers, :port, 10_000)

    children = [
      {server_mod, [config: [port: server_port]]}
    ]

    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
