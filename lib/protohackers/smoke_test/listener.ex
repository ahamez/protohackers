defmodule Protohackers.SmokeTest.Listener do
  use GenServer, restart: :transient
  require Logger

  defmodule State do
    defstruct data: <<>>
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
    Logger.debug("Received #{inspect(data)} from #{inspect(client_socket)}")

    {:noreply, %{state | data: [state.data, data]}}
  end

  @impl true
  def handle_info({:tcp_closed, client_socket}, state) do
    Logger.info("Socket #{inspect(client_socket)} closed")
    Logger.debug("Send #{inspect(state.data)} to #{inspect(client_socket)}")

    :ok = :gen_tcp.send(client_socket, state.data)
    :gen_tcp.close(client_socket)

    {:stop, :normal, state}
  end
end
