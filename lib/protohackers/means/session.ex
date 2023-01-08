defmodule Protohackers.Means.Session do
  use GenServer, restart: :transient
  require Logger

  defmodule State do
    @enforce_keys [:client_socket]
    defstruct client_socket: nil,
              data: <<>>,
              asset: []
  end

  defmodule Price do
    @enforce_keys [:timestamp, :price]
    defstruct [:timestamp, :price]
  end

  defmodule Insert do
    @enforce_keys [:price]
    defstruct [:price]
  end

  defmodule Query do
    @enforce_keys [:mintime, :maxtime]
    defstruct [:mintime, :maxtime]
  end

  def start_link(opts) do
    {client_socket, opts} = Keyword.pop!(opts, :client_socket)

    GenServer.start_link(__MODULE__, client_socket, opts)
  end

  @impl true
  def init(client_socket) do
    {:ok, %State{client_socket: client_socket}}
  end

  @impl true
  def handle_info({:tcp, _client_socket, data}, state) do
    {:noreply, %State{state | data: state.data <> data}, {:continue, :parse_data}}
  end

  @impl true
  def handle_info({:tcp_closed, client_socket}, state) do
    Logger.info("Socket #{Protohackers.Util.peername(client_socket)} closed")

    {:noreply, state, {:continue, :close_socket}}
  end

  @impl true
  def handle_continue(:close_socket, state) do
    :gen_tcp.close(state.client_socket)

    {:stop, :normal, state}
  end

  @impl true
  def handle_continue(:parse_data, state) do
    case state.data do
      <<msg::binary-size(9), rest::binary>> ->
        case parse_message(msg) do
          {:ok, msg} ->
            state = handle_message(msg, state)
            {:noreply, %State{state | data: rest}, {:continue, :parse_data}}

          _ ->
            Logger.warn("Malformed message")
            {:noreply, state, {:continue, :close_socket}}
        end

      _ ->
        {:noreply, state}
    end
  end

  # -- Private

  defp parse_message(msg) do
    case msg do
      <<"I", timestamp::signed-big-32, price::signed-big-32>> ->
        {:ok, %Insert{price: %Price{timestamp: timestamp, price: price}}}

      <<"Q", mintime::signed-big-32, maxtime::signed-big-32>> ->
        {:ok, %Query{mintime: mintime, maxtime: maxtime}}

      _ ->
        :error
    end
  end

  defp handle_message(%Insert{} = msg, state) do
    asset = [msg.price | state.asset]

    %State{state | asset: asset}
  end

  defp handle_message(%Query{} = msg, state) do
    mean =
      state.asset
      |> Enum.reduce({0, 0}, fn price, acc ->
        if price.timestamp >= msg.mintime and price.timestamp <= msg.maxtime do
          {sum, count} = acc

          {sum + price.price, count + 1}
        else
          acc
        end
      end)
      |> then(fn
        {_, 0} -> 0
        {sum, count} -> div(sum, count)
      end)

    :ok = :gen_tcp.send(state.client_socket, <<mean::signed-big-32>>)

    state
  end
end
