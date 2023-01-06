defmodule Protohackers.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # server = Application.fetch_env!(:protohackers, :server)
    server_mod =
      Module.concat([
        Protohackers,
        Application.fetch_env!(:protohackers, :server),
        Accepter
      ])

    children = [
      {DynamicSupervisor, name: Protohackers.DynamicSupervisor},
      {server_mod, [config: [port: 10_000]]}
    ]

    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
