defmodule Protohackers.Vcs.Session do
  use GenServer, restart: :transient

  alias Protohackers.Vcs.Vcs

  defmodule State do
    @enforce_keys [:socket, :vcs]
    defstruct socket: nil, vcs: nil, data: <<>>, state: :normal
  end

  def start_link(opts) do
    {client_opts, opts} = Keyword.split(opts, [:socket, :vcs])

    GenServer.start_link(__MODULE__, client_opts, opts)
  end

  @impl true
  def init(opts) do
    {:ok, socket} = Keyword.fetch(opts, :socket)
    {:ok, vcs} = Keyword.fetch(opts, :vcs)

    state = %State{socket: socket, vcs: vcs}

    send_ready(state)

    {:ok, state}
  end

  @impl true
  def handle_info({:tcp, _socket, data}, %State{state: :normal} = state) do
    data = state.data <> data

    case String.split(data, "\n", parts: 2) do
      [request, rest] ->
        {:noreply, %State{state | data: rest}, {:continue, {:parse_request, request}}}

      _ ->
        {:noreply, %State{state | data: data}}
    end
  end

  @impl true
  def handle_info({:tcp, _socket, data}, %State{state: {:put, path, length}} = state) do
    state =
      %State{state | data: state.data <> data}
      |> maybe_put(path, length)
      |> maybe_send_ready()

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    {:noreply, state, {:continue, :close}}
  end

  @impl true
  def handle_continue(:close, %State{} = state) do
    :gen_tcp.close(state.socket)

    {:stop, :normal, state}
  end

  @impl true
  def handle_continue({:parse_request, request}, state) do
    [command | args] = request |> String.trim_trailing() |> String.split(" ")

    state =
      command
      |> String.upcase()
      |> handle_command(args, state)
      |> maybe_send_ready()

    {:noreply, state}
  end

  # -- Private

  defp maybe_send_ready(%State{state: :normal} = state), do: send_ready(state)
  defp maybe_send_ready(state), do: state

  defp maybe_put(state, path, length) do
    case state.data do
      <<put_data::binary-size(length), rest::binary>> ->
        state =
          with {:ok, latest_revision} <- Vcs.put(state.vcs, path, put_data) do
            send_ok("r#{latest_revision}", state)
          else
            {:error, reason} -> handle_error(reason, state)
          end

        %State{state | data: rest, state: :normal}

      _ ->
        %State{state | state: {:put, path, length}}
    end
  end

  defp handle_command("PUT", [path, length], state) do
    length = String.to_integer(length)

    maybe_put(state, path, length)
  end

  defp handle_command("PUT", _, state) do
    send_error("usage: PUT file length newline data", state)
  end

  defp handle_command("GET", [path], state) do
    handle_command("GET", [path, :latest], state)
  end

  defp handle_command("GET", [path, revision], state) do
    with {:ok, data} <- Vcs.get(state.vcs, path, revision) do
      send_ok("#{byte_size(data)}", state)
      send_data(data, state)
    else
      {:error, reason} -> handle_error(reason, state)
    end
  end

  defp handle_command("GET", _, state) do
    send_error("usage: GET file [revision]", state)
  end

  defp handle_command("LIST", [path], state) do
    with {:ok, {nb_elems, elems}} <- Vcs.list(state.vcs, path) do
      send_ok(nb_elems, state)

      Enum.reduce(elems, state, fn {path, metada}, state ->
        send_data("#{path} #{metada}\n", state)
      end)
    else
      {:error, reason} -> handle_error(reason, state)
    end
  end

  defp handle_command("LIST", _, state) do
    send_error("usage: LIST dir", state)
  end

  defp handle_command("HELP", _, state) do
    send_ok("usage: HELP|GET|PUT|LIST", state)
  end

  defp handle_command(method, _, state) do
    send_error("illegal method: #{method}", state)
  end

  defp handle_error(reason, state) do
    state =
      case reason do
        :illegal_file_name ->
          send_error("illegal file name", state)

        :no_such_file ->
          send_error("no such file", state)

        :no_such_revision ->
          send_error("no such revision", state)

        :not_a_text_file ->
          send_error("invalid file content", state)
      end

    send_ready(state)
  end

  defp send_error(message, state) do
    send_data("ERR #{message}\n", state)
  end

  defp send_ready(state) do
    send_data("READY\n", state)
  end

  defp send_ok(msg, state) do
    send_data("OK #{msg}\n", state)
  end

  defp send_data(data, state) do
    :ok = :gen_tcp.send(state.socket, data)

    state
  end
end
