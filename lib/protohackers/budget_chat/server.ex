defmodule Protohackers.BudgetChat.Server do
  use GenServer
  require Logger

  defmodule State do
    defstruct [:listen_socket, :dynamic_supervisor]
  end

  def start_link(opts \\ []) do
    {config, _opts} = Keyword.pop!(opts, :config)

    {:ok, _pid} = Registry.start_link(name: BudgetChatRegistry, keys: :duplicate)

    GenServer.start_link(__MODULE__, config, opts)
  end

  @impl true
  def init(config) do
    {:ok, listen_socket} =
      :gen_tcp.listen(config[:port], [
        :binary,
        packet: :line,
        buffer: 1024 * 16,
        active: true,
        reuseaddr: true,
        exit_on_close: false
      ])

    {:ok, pid} = DynamicSupervisor.start_link([])

    state = %State{listen_socket: listen_socket, dynamic_supervisor: pid}

    {:ok, state, {:continue, :accept}}
  end

  @impl true
  def handle_continue(:accept, state) do
    {:ok, client_socket} = :gen_tcp.accept(state.listen_socket)

    Logger.info("Accepting new connection from #{Protohackers.Util.peername(client_socket)}")

    {:ok, pid} =
      DynamicSupervisor.start_child(
        state.dynamic_supervisor,
        {Protohackers.BudgetChat.Session, [socket: client_socket]}
      )

    :ok = :gen_tcp.controlling_process(client_socket, pid)

    {:noreply, state, {:continue, :accept}}
  end
end
