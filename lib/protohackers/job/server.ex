defmodule Protohackers.Job.Server do
  use GenServer
  require Logger

  defmodule State do
    defstruct listen_socket: nil, session_supervisor: nil, broker: nil
  end

  def start_link(opts \\ []) do
    {config, _opts} = Keyword.pop!(opts, :config)

    GenServer.start_link(__MODULE__, config, opts)
  end

  @impl true
  def init(config) do
    {:ok, listen_socket} =
      :gen_tcp.listen(config[:port], [
        {:inet_backend, :socket},
        :binary,
        packet: :line,
        active: true,
        reuseaddr: true
      ])

    {:ok, session_supervisor} = DynamicSupervisor.start_link([])
    {:ok, broker} = Protohackers.Job.Broker.start_link([])

    state = %State{
      listen_socket: listen_socket,
      session_supervisor: session_supervisor,
      broker: broker
    }

    {:ok, state, {:continue, :accept}}
  end

  @impl true
  def handle_continue(:accept, state) do
    {:ok, client_socket} = :gen_tcp.accept(state.listen_socket)

    {:ok, pid} =
      DynamicSupervisor.start_child(
        state.session_supervisor,
        {Protohackers.Job.Session, [socket: client_socket, broker: state.broker]}
      )

    :ok = :gen_tcp.controlling_process(client_socket, pid)

    {:noreply, state, {:continue, :accept}}
  end
end
