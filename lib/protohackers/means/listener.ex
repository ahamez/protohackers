defmodule Protohackers.Means.Listener do
  use GenServer, restart: :transient
  require Logger

  defmodule State do
    defstruct data: <<>>
  end

  defmodule Insert do
    @enforce_keys [:timestamp, :price]
    defstruct [:timestamp, :price]
  end

  defmodule Query do
    @enforce_keys [:mintime, :maxtime]
    defstruct [:mintime, :maxtime]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init([]) do
    {:ok, %State{}}
  end

  @impl true
  def handle_info({:tcp, client_socket, data}, state) do
    peername = Protohackers.Util.peername(client_socket)

    Logger.debug("Received #{inspect(data)} from #{peername}")


    {:noreply, %State{state | data: state.data <> data}, {:continue, :parse_data}}
  end

  @impl true
  def handle_info({:tcp_closed, client_socket}, state) do
    Logger.info("Socket #{Protohackers.Util.peername(client_socket)} closed")

    {:stop, :normal, state}
  end

  @impl true
  def handle_continue(:parse_data, state) do
    case state.data do
      <<msg::binary-size(9), rest::binary>> ->
        Logger.debug("Will parse message #{inspect(msg)}")

        {:ok, msg} = parse_message(msg)
        Logger.debug("#{inspect(msg)}")

        {:noreply, %State{state | data: rest}, {:continue, :parse_data}}

      _ ->
        Logger.debug("Incomplete data")
        {:noreply, state}
    end
  end

  # -- Private

  defp parse_message(msg) do
    case msg do
      <<"I", timestamp::signed-big-32, price::signed-big-32>> ->
        {:ok, %Insert{timestamp: timestamp, price: price}}

      <<"Q", mintime::signed-big-32, maxtime::signed-big-32>> ->
        {:ok, %Query{mintime: mintime, maxtime: maxtime}}

      _ ->
        :error
    end
  end

end
