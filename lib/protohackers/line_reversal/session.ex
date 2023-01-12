defmodule Protohackers.LineReversal.Session do
  use GenServer, restart: :transient
  require Logger

  @chunk_size 950
  @timeout_s 60
  @retransmit_s 3

  alias Protohackers.LineReversal.Message.{Ack, Close, Connect, Data}

  defmodule State do
    defstruct dynamic_supervisor: nil,
              socket: nil,
              host: nil,
              port: nil,
              session: nil,
              data_received: "",
              data_received_pos: 0,
              data_unacknowledged: "",
              acknowledged: 0,
              sent: 0,
              tick: 0
  end

  def start_link(opts) do
    {client_opts, opts} = Keyword.split(opts, [:dynamic_supervisor, :connection, :session])

    GenServer.start_link(__MODULE__, client_opts, opts)
  end

  @impl true
  def init(opts) do
    {dynamic_supervisor, opts} = Keyword.pop!(opts, :dynamic_supervisor)
    {{socket, host, port}, opts} = Keyword.pop!(opts, :connection)
    {session, _opts} = Keyword.pop!(opts, :session)

    {:ok, _} = Registry.register(LineReversalRegistry, session, :dummy)

    schedule_timer()

    Logger.metadata(session: session)

    state = %State{
      dynamic_supervisor: dynamic_supervisor,
      socket: socket,
      host: host,
      port: port,
      session: session
    }

    {:ok, state}
  end

  # -------- CONNECT

  @impl true
  def handle_info(%Connect{} = msg, state) do
    set_logger_metadata(state)
    Logger.debug("<-- CONNECT #{inspect(msg)}")

    send_ack(state)

    {:noreply, state}
  end

  # -------- DATA

  # data: 2
  @impl true
  def handle_info(%Data{} = data_msg, state) when data_msg.pos == state.data_received_pos do
    set_logger_metadata(state)
    Logger.debug("<-- DATA #{inspect(data_msg)}")

    state = application_layer(state, data_msg)

    {:noreply, state}
  end

  # data: 3
  @impl true
  def handle_info(%Data{} = data, state) do
    set_logger_metadata(state)
    Logger.debug("<-- DATA miss (#{inspect(data)})")

    send_ack(state)

    {:noreply, state}
  end

  # -------- ACK

  # ack: 2
  @impl true
  def handle_info(%Ack{} = ack, state) when ack.length <= state.acknowledged do
    set_logger_metadata(state)
    Logger.debug("<-- ACK duplicate. Nothing to do.")

    {:noreply, state}
  end

  # ack: 3
  @impl true
  def handle_info(%Ack{} = ack, state) when ack.length > state.sent do
    set_logger_metadata(state)
    Logger.debug("<-- ACK up to #{ack.length}, misbehaving peer, closing session")

    {:noreply, state, {:continue, :close}}
  end

  # ack: 4
  @impl true
  def handle_info(%Ack{} = ack, state) when ack.length < state.sent do
    set_logger_metadata(state)

    Logger.debug("<-- ACK up to #{ack.length}, need to resend some data")

    data_unacknowledged =
      binary_slice(
        state.data_unacknowledged,
        ack.length - state.acknowledged,
        byte_size(state.data_unacknowledged)
      )

    state = %State{state | acknowledged: ack.length, data_unacknowledged: data_unacknowledged}

    send_unacknowledged_data(state)

    {:noreply, state}
  end

  # ack: 5
  @impl true
  def handle_info(%Ack{} = ack, state) when ack.length == state.sent do
    set_logger_metadata(state)
    Logger.debug("<-- ACK all data sent has been received by peer.")

    data_unacknowledged =
      binary_slice(
        state.data_unacknowledged,
        ack.length - state.acknowledged,
        byte_size(state.data_unacknowledged)
      )

    state = %State{state | acknowledged: ack.length, data_unacknowledged: data_unacknowledged}

    {:noreply, state}
  end

  # -------- CLOSE

  @impl true
  def handle_info(%Close{} = _msg, state) do
    set_logger_metadata(state)
    Logger.debug("<-- CLOSE")

    {:noreply, state, {:continue, :close}}
  end

  # --------

  @impl true
  def handle_info(:timer, state) do
    set_logger_metadata(state)

    schedule_timer()
    state = %State{state | tick: state.tick + 1}

    if state.acknowledged < state.sent do
      cond do
        rem(state.tick, @timeout_s) == 0 ->
          Logger.warn("Timeout. Closing.")
          {:noreply, state, {:continue, :close}}

        rem(state.tick, @retransmit_s) == 0 ->
          send_unacknowledged_data(state)
          {:noreply, state}

        true ->
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  # --------

  @impl true
  def handle_continue(:close, state) do
    send_close(state)

    {:stop, :normal, state}
  end

  # -------- Private

  defp application_layer(state, data_msg) do
    {lines, rest} = get_lines(state.data_received <> data_msg.data)

    state =
      Enum.reduce(lines, state, fn line, state ->
        to_send = String.reverse(line) <> "\n"

        if byte_size(to_send) > 10_000 do
          Logger.error("Line too long")
        end

        send_data(state, state.sent, to_send)

        %State{
          state
          | data_unacknowledged: state.data_unacknowledged <> to_send,
            sent: state.sent + byte_size(to_send)
        }
      end)

    %State{
      state
      | data_received: rest,
        data_received_pos: state.data_received_pos + byte_size(data_msg.data)
    }
  end

  defp send_unacknowledged_data(state) do
    {lines, _rest} = get_lines(state.data_unacknowledged)

    Enum.reduce(lines, _sent = 0, fn line, sent ->
      to_send = line <> "\n"
      send_data(state, state.acknowledged + sent, to_send)

      sent + byte_size(to_send)
    end)
  end

  defp get_lines(data) do
    {rest, lines} =
      data
      |> String.split("\n")
      # Extract last part, which doesn't end with '\n'.
      |> List.pop_at(-1)

    {lines, rest}
  end

  # -- Send ACK

  defp send_ack(state) do
    ack = Ack.new(state.session, state.data_received_pos) |> Ack.encode()
    Logger.debug("--> ACK #{inspect(ack)}")

    :gen_udp.send(state.socket, state.host, state.port, ack)
  end

  # -- Send DATA

  defp send_data(state, pos, data_to_send) when byte_size(data_to_send) > @chunk_size do
    <<data_to_send::binary-size(@chunk_size), rest::binary>> = data_to_send
    send_data_helper(state, pos, data_to_send)

    send_data(state, pos + @chunk_size, rest)
  end

  defp send_data(state, pos, data_to_send) do
    send_data_helper(state, pos, data_to_send)
  end

  defp send_data_helper(state, pos, data_to_send) do
    data =
      Data.new(state.session, pos, data_to_send)
      |> Data.encode()

    Logger.debug("--> DATA (#{byte_size(data_to_send)}) #{inspect(data)}")

    :gen_udp.send(state.socket, state.host, state.port, data)
  end

  # -- Send CLOSE

  defp send_close(state) do
    close = Close.new(state.session) |> Close.encode()
    Logger.debug("--> CLOSE #{inspect(close)}")

    :gen_udp.send(state.socket, state.host, state.port, close)
  end

  # -- Misc.

  defp set_logger_metadata(state) do
    Logger.metadata(
      data_received_pos: state.data_received_pos,
      acknowledged: state.acknowledged,
      sent: state.sent
    )
  end

  defp schedule_timer() do
    Process.send_after(self(), :timer, _ms = 1_000)
  end
end
