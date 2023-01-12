defmodule Protohackers.LineReversal.Server do
  use GenServer
  require Logger

  alias Protohackers.LineReversal.Message
  alias Protohackers.LineReversal.Message.{Close, Connect}

  defmodule State do
    defstruct [:dynamic_supervisor]
  end

  def start_link(opts \\ []) do
    {config, _opts} = Keyword.pop!(opts, :config)

    GenServer.start_link(__MODULE__, config, opts)
  end

  @impl true
  def init(config) do
    {:ok, _socket} =
      :gen_udp.open(
        config[:port],
        [
          :binary,
          active: true,
          reuseaddr: true
        ]
      )

    {:ok, dynamic_supervisor} = DynamicSupervisor.start_link([])
    {:ok, _pid} = Registry.start_link(name: LineReversalRegistry, keys: :unique)

    {:ok, %State{dynamic_supervisor: dynamic_supervisor}}
  end

  @impl true
  def handle_info({:udp, _socket, _host, _port, data}, state) when byte_size(data) >= 1_000 do
    Logger.warn("Message size >= 1000 bytes.")

    {:noreply, state}
  end

  @impl true
  def handle_info({:udp, socket, host, port, data}, state) do
    data
    |> Message.decode()
    |> handle_message({socket, host, port}, state)

    {:noreply, state}
  end

  # -- Private

  defp handle_message({:ok, %Connect{} = msg}, connection, state) do
    pid =
      case Registry.lookup(LineReversalRegistry, msg.session) do
        [] -> start_session(msg.session, connection, state)
        [{pid, _}] -> pid
      end

    send(pid, msg)
  end

  defp handle_message({:ok, msg}, {socket, host, port}, _state) do
    with [{pid, _}] <- Registry.lookup(LineReversalRegistry, msg.session) do
      send(pid, msg)
    else
      _ ->
        Logger.warn("Unkwnown session #{msg.session}. Closing.")

        close = Close.new(msg.session) |> Close.encode()
        :gen_udp.send(socket, host, port, close)
    end
  end

  defp handle_message({:error, reason}, _connection, _state) do
    Logger.warn("#{inspect(reason)}")
  end

  defp start_session(session, connection, state) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        state.dynamic_supervisor,
        {Protohackers.LineReversal.Session,
         [
           dynamic_supervisor: state.dynamic_supervisor,
           connection: connection,
           session: session
         ]}
      )

    pid
  end
end
