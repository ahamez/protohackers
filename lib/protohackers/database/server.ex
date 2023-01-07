defmodule Protohackers.Database.Server do
  use GenServer
  require Logger

  defmodule State do
    defstruct kv: %{}
  end

  def start_link(opts \\ []) do
    {config, _opts} = Keyword.pop!(opts, :config)

    GenServer.start_link(__MODULE__, config, opts)
  end

  @impl true
  def init(config) do
    {:ok, _socket} =
      :gen_udp.open(config[:port], [
        :binary,
        active: true,
        reuseaddr: true
      ])

    {:ok, %State{}}
  end

  @impl true
  def handle_info({:udp, socket, address, port, data}, state) do
    # Logger.debug("#{inspect(data)}")

    state =
      data
      |> parse()
      |> handle_message(state, {socket, address, port})

    {:noreply, state}
  end

  # -- Private

  defp handle_message({:insert, key, value}, state, _) do
    %State{state | kv: Map.put(state.kv, key, value)}
  end

  defp handle_message({:query, "version"}, state, {socket, address, port}) do
    :gen_udp.send(socket, address, port, "version=fubar")

    state
  end

  defp handle_message({:query, key}, state, {socket, address, port}) do
    value = Map.get(state.kv, key, "")

    # Logger.debug("Will send #{key}=#{value}")

    :gen_udp.send(socket, address, port, "#{key}=#{value}")

    state
  end

  defp parse(data) do
    case String.split(data, "=", parts: 2) do
      [key, value] -> {:insert, key, value}
      [key] -> {:query, key}
    end
  end
end
