defmodule Protohackers.Means.Accepter do
  use GenServer
  require Logger

  defmodule State do
    defstruct [:listen_socket]
  end

  def start_link(opts \\ []) do
    {config, _opts} = Keyword.pop!(opts, :config)

    GenServer.start_link(__MODULE__, config, opts)
  end

  @impl true
  def init(config) do
    {:ok, listen_socket} =
      :gen_tcp.listen(config[:port], [
        :binary,
        packet: :raw,
        active: true,
        reuseaddr: true,
        exit_on_close: false
      ])

    state = %State{listen_socket: listen_socket}

    {:ok, state, {:continue, :accept}}
  end

  @impl true
  def handle_continue(:accept, state) do
    {:ok, client_socket} = :gen_tcp.accept(state.listen_socket)

    Logger.info("Accepting new connection from #{Protohackers.Util.peername(client_socket)}")

    {:ok, pid} =
      DynamicSupervisor.start_child(
        Protohackers.DynamicSupervisor,
        {Protohackers.Means.Listener, [client_socket: client_socket]}
      )

    :ok = :gen_tcp.controlling_process(client_socket, pid)

    {:noreply, state, {:continue, :accept}}
  end
end
