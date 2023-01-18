defmodule Protohackers.Insecure.Session do
  use GenServer, restart: :transient
  require Logger

  alias Protohackers.Insecure.Cipher

  defmodule State do
    @enforce_keys [:socket]
    defstruct socket: nil,
              state: :waiting_cipher,
              cipher: nil,
              data: <<>>,
              decoded: "",
              recv_pos: 0,
              send_pos: 0
  end

  def start_link(opts) do
    {socket, opts} = Keyword.pop!(opts, :socket)

    GenServer.start_link(__MODULE__, socket, opts)
  end

  @impl true
  def init(socket) do
    Logger.debug("Init #{inspect(socket)}")

    state = %State{socket: socket}

    {:ok, state}
  end

  @impl true
  def handle_info({:tcp, _socket, data}, %State{state: :waiting_cipher} = state) do
    data = state.data <> data

    cipher_type = Enum.random([:byte_wise, :nx])

    case Cipher.new(data, type: cipher_type) do
      {:ok, cipher, rest} ->
        state = %State{state | state: :parse_data, data: rest, cipher: cipher}
        Logger.debug("Build cipher #{inspect(cipher.operations)}")
        {:noreply, state, {:continue, :decode_data}}

      {:error, :need_more_data} ->
        Logger.debug("Need more data to build cipher")
        {:noreply, state}

      {:error, reason} ->
        Logger.warn("Invalid cipher specification: #{inspect(reason)}")

        {:noreply, state, {:continue, :close}}
    end
  end

  @impl true
  def handle_info({:tcp, _socket, data}, %State{state: :parse_data} = state) do
    {:noreply, %State{state | data: state.data <> data}, {:continue, :decode_data}}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    {:noreply, state, {:continue, :close}}
  end

  @impl true
  def handle_continue(:decode_data, %State{} = state) do
    {decoded, pos} = decode(state.cipher, state.data, state.recv_pos)

    state = %State{
      state
      | data: "",
        recv_pos: pos,
        decoded: state.decoded <> decoded
    }

    {:noreply, state, {:continue, :parse_decoded}}
  end

  @impl true
  def handle_continue(:parse_decoded, state) when state.decoded == "" do
    {:noreply, state}
  end

  @impl true
  def handle_continue(:parse_decoded, state) do
    {lines, rest} = get_lines(state.decoded)

    send_pos =
      for line <- lines, reduce: state.send_pos do
        send_pos ->
          {toy, quantity} = parse_request(line)
          answer = "#{quantity}x#{toy}\n"

          {encoded, send_pos} = encode(state.cipher, answer, send_pos)
          :gen_tcp.send(state.socket, encoded)

          send_pos
      end

    state = %State{state | decoded: rest, send_pos: send_pos}

    {:noreply, state}
  end

  @impl true
  def handle_continue(:close, %State{} = state) do
    :gen_tcp.close(state.socket)

    {:stop, :normal, state}
  end

  # -- Private

  defp get_lines(data) do
    {rest, lines} =
      data
      |> String.split("\n")
      # Extract last part, which doesn't end with '\n'.
      |> List.pop_at(-1)

    {lines, rest}
  end

  defp parse_request(line) do
    line
    |> String.split(",")
    |> Enum.reduce({_toy = "", _quantity = 0}, fn current_toy_quantity, {toy, quantity} ->
      [current_quantity, current_toy] = String.split(current_toy_quantity, "x", parts: 2)
      current_quantity = String.to_integer(current_quantity)

      if current_quantity > quantity do
        {current_toy, current_quantity}
      else
        {toy, quantity}
      end
    end)
  end

  defp encode(cipher, str, pos) do
    transform_binary(fn byte, pos -> Cipher.encode(cipher, byte, pos) end, str, pos)
  end

  defp decode(cipher, str, pos) do
    transform_binary(fn byte, pos -> Cipher.decode(cipher, byte, pos) end, str, pos)
  end

  defp transform_binary(fun, data, pos) do
    for <<byte <- data>>, reduce: {<<>>, pos} do
      {transformed, pos} ->
        b = fun.(byte, pos)
        {<<transformed::binary, b>>, pos + 1}
    end
  end
end
