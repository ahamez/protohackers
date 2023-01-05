defmodule Protohackers.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: Protohackers.DynamicSupervisor},
      # {Protohackers.SmokeTest.Accepter, [config: [port: 10_000]]}
      {Protohackers.PrimeTime.Accepter, [config: [port: 10_000]]}
    ]

    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
