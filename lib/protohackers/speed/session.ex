defmodule Protohackers.Speed.Session do
  alias Protohackers.Speed.{Central, Message, Message.Encode}

  use GenServer, restart: :transient
  require Logger

  defmodule State do
    @enforce_keys [:socket, :central]
    defstruct socket: nil,
              central: nil,
              peername: nil,
              type: nil,
              heartbeat: nil,
              data: <<>>
  end

  def start_link(opts) do
    {client_opts, opts} = Keyword.split(opts, [:socket, :central])

    GenServer.start_link(__MODULE__, client_opts, opts)
  end

  @impl true
  def init(opts) do
    {socket, opts} = Keyword.pop!(opts, :socket)
    {central, _opts} = Keyword.pop!(opts, :central)

    {
      :ok,
      %State{socket: socket, central: central, peername: Protohackers.Util.peername(socket)}
    }
  end

  @impl true
  def handle_info({:tcp, _socket, data}, state) do
    {:noreply, %State{state | data: state.data <> data}, {:continue, :parse_data}}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    # Logger.debug("Connection with #{state.peername} closed")
    :gen_tcp.close(state.socket)

    {:noreply, state}
  end

  @impl true
  def handle_info(:send_hearbeat, state) do
    :gen_tcp.send(state.socket, Encode.encode(%Message.Heartbeat{}))
    schedule_heartbeat(state.heartbeat)

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:send_ticket, %Message.Ticket{} = ticket},
        %State{type: %Message.Dispatcher{}} = state
      ) do
    Logger.debug("Send ticket #{inspect(ticket)}")

    :gen_tcp.send(state.socket, Encode.encode(ticket))

    {:noreply, state}
  end

  @impl true
  def handle_continue(:parse_data, state) do
    case Message.decode(state.data) do
      {:ok, msg, data} ->
        # Logger.debug("Parsed #{inspect(msg)}")

        case handle_message(msg, state) do
          {:ok, state} ->
            {:noreply, %State{state | data: data}, {:continue, :parse_data}}

          {:error, reason} ->
            {:noreply, state, {:continue, {:send_error, reason}}}
        end

      :need_more_data ->
        # Logger.debug("Need more data")
        {:noreply, state}

      {:error, reason} ->
        {:noreply, state, {:continue, {:send_error, reason}}}
    end
  end

  @impl true
  def handle_continue({:send_error, reason}, state) do
    :gen_tcp.send(state.socket, Encode.encode(%Message.Error{msg: "#{inspect(reason)}"}))
    :gen_tcp.close(state.socket)

    {:stop, :normal, state}
  end

  # -- Private

  defp handle_message(%Message.WantHeartbeat{} = msg, %State{heartbeat: nil} = state) do
    period = trunc(msg.interval / 10 * 1_000)

    schedule_heartbeat(period)

    {:ok, %State{state | heartbeat: period}}
  end

  defp handle_message(%Message.WantHeartbeat{}, %State{heartbeat: _set}) do
    {:error, :heartbeat_already_set}
  end

  defp handle_message(%Message.Camera{} = camera, %State{type: nil} = state) do
    {:ok, %State{state | type: camera}}
  end

  defp handle_message(%Message.Camera{}, %State{type: _not_nil}) do
    {:error, :client_type_already_set}
  end

  defp handle_message(%Message.Dispatcher{} = dispatcher, %State{type: nil} = state) do
    Enum.each(dispatcher.roads, &Registry.register(Protohackers.Registry, &1, :dummy))

    {:ok, %State{state | type: dispatcher}}
  end

  defp handle_message(%Message.Dispatcher{}, %State{type: _not_nil}) do
    {:error, :client_type_already_set}
  end

  defp handle_message(%Message.Plate{} = plate, %State{type: %Message.Camera{} = camera} = state) do
    :ok = Central.add_observation(state.central, plate, camera)

    {:ok, state}
  end

  defp handle_message(%Message.Plate{}, %State{type: _not_camera}) do
    {:error, :plate_from_dispatcher}
  end

  defp schedule_heartbeat(0) do
  end

  defp schedule_heartbeat(period) do
    Process.send_after(self(), :send_hearbeat, period)
  end
end
