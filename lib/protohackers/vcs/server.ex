defmodule Protohackers.Vcs.Server do
  use GenServer
  require Logger

  defmodule State do
    defstruct [:listen_socket, :dynamic_supervisor, :vcs]
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
        packet: :raw,
        active: true,
        reuseaddr: true,
        exit_on_close: false,
        nodelay: true
      ])

    {:ok, supervisor_pid} = DynamicSupervisor.start_link([])
    {:ok, vcs_pid} = Protohackers.Vcs.Vcs.start_link([])

    state = %State{listen_socket: listen_socket, dynamic_supervisor: supervisor_pid, vcs: vcs_pid}

    {:ok, state, {:continue, :accept}}
  end

  @impl true
  def handle_continue(:accept, state) do
    {:ok, client_socket} = :gen_tcp.accept(state.listen_socket)

    Logger.info("Accepting new connection from #{Protohackers.Util.peername(client_socket)}")

    {:ok, pid} =
      DynamicSupervisor.start_child(
        state.dynamic_supervisor,
        {Protohackers.Vcs.Session, [socket: client_socket, vcs: state.vcs]}
      )

    :ok = :gen_tcp.controlling_process(client_socket, pid)

    {:noreply, state, {:continue, :accept}}
  end
end
