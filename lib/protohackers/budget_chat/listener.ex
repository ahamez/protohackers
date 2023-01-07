defmodule Protohackers.BudgetChat.Listener do
  use GenServer, restart: :transient
  require Logger

  defmodule State do
    @enforce_keys [:socket]
    defstruct socket: nil,
              state: :setting_name,
              peername: nil,
              username: nil
  end

  def start_link(opts) do
    {socket, opts} = Keyword.pop!(opts, :socket)

    GenServer.start_link(__MODULE__, socket, opts)
  end

  @impl true
  def init(socket) do
    {
      :ok,
      %State{socket: socket, peername: Protohackers.Util.peername(socket)},
      {:continue, :send_greeting}
    }
  end

  @impl true
  def handle_info({:tcp, _socket, data}, %State{state: :setting_name} = state) do
    username = String.trim_trailing(data)

    case validate_username(username) do
      true ->
        Logger.debug("Setting name to #{inspect(username)}")
        broadcast_client_joined(username)
        register_client(username)

        connected_clients = get_connected_clients(username)
        :ok = :gen_tcp.send(state.socket, "* The room contains: #{inspect(connected_clients)}\n")

        {:noreply, %State{state | state: :joined, username: username}}

      false ->
        :gen_tcp.close(state.socket)
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info({:tcp, _socket, data}, %State{state: :joined} = state) do
    Logger.debug("Received message from #{state.username} to broadcast to others")
    broadcast_message(state.username, String.trim_trailing(data))

    {:noreply, state}
  end

  @impl true
  def handle_info({:client_joined, joining_client}, state) do
    Logger.debug("Will tell #{state.username} that #{joining_client} has joined")
    :ok = :gen_tcp.send(state.socket, "* #{joining_client} has entered the room\n")

    {:noreply, state}
  end

  @impl true
  def handle_info({:client_left, leaving_client}, state) do
    Logger.debug("Will tell #{state.username} that #{leaving_client} has left")
    :ok = :gen_tcp.send(state.socket, "* #{leaving_client} has left the room\n")

    {:noreply, state}
  end

  @impl true
  def handle_info({:message, from, message}, state) do
    Logger.debug("Will send message to #{state.username}")
    :ok = :gen_tcp.send(state.socket, "[#{from}] #{message}\n")

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.info("Socket #{state.peername} closed")
    :gen_tcp.close(state.socket)

    {:noreply, state, {:continue, :notify_departure_to_others}}
  end

  @impl true
  def handle_continue(:send_greeting, state) do
    :ok = :gen_tcp.send(state.socket, "Welcome to budgetchat! What shall I call you?\n")

    {:noreply, state}
  end

  @impl true
  def handle_continue(:notify_departure_to_others, %State{state: :joined} = state) do
    broadcast_client_left(state.username)

    {:stop, :normal, state}
  end

  @impl true
  def handle_continue(:notify_departure_to_others, state) do
    {:stop, :normal, state}
  end

  # -- Private

  defp register_client(username) do
    Registry.register(Protohackers.Registry, :client, username)
  end

  defp broadcast_client_joined(joining_username) do
    broadcast({:client_joined, joining_username})
  end

  defp broadcast_client_left(leaving_username) do
    broadcast({:client_left, leaving_username})
  end

  defp broadcast_message(from, message) do
    broadcast({:message, from, message})
  end

  defp broadcast(data) do
    Registry.dispatch(Protohackers.Registry, :client, fn entries ->
      for {pid, _username} <- entries, pid != self() do
        send(pid, data)
      end
    end)
  end

  defp get_connected_clients(excluded_username) do
    Registry.select(
      Protohackers.Registry,
      [
        {
          # Match pattern
          {:_, :_, :"$1"},
          # Guard
          [{:"/=", :"$1", excluded_username}],
          # Body
          [:"$1"]
        }
      ]
    )
  end

  defp validate_username(""), do: false

  defp validate_username(username) do
    username
    |> String.to_charlist()
    |> Enum.all?(fn c ->
      cond do
        c >= ?a and c <= ?z -> true
        c >= ?A and c <= ?Z -> true
        c >= ?0 and c <= ?9 -> true
        true -> false
      end
    end)
  end
end
