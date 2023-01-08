defmodule Protohackers.Mob.Session do
  use GenServer, restart: :transient
  require Logger

  @upstream_dns "chat.protohackers.com" |> String.to_charlist()
  @upstream_port 16_963
  @tony_address "7YWHMfk9JZe0LM0g1ZauHuiSxhI"

  defmodule State do
    @enforce_keys [:downstream_socket, :upstream_socket, :peername]
    defstruct downstream_socket: nil, upstream_socket: nil, peername: nil
  end

  def start_link(opts) do
    {downstream_socket, opts} = Keyword.pop!(opts, :socket)

    GenServer.start_link(__MODULE__, downstream_socket, opts)
  end

  @impl true
  def init(downstream_socket) do
    {:ok, upstream_socket} =
      :gen_tcp.connect(@upstream_dns, @upstream_port, [:binary, packet: :line, active: true])

    {
      :ok,
      %State{
        downstream_socket: downstream_socket,
        upstream_socket: upstream_socket,
        peername: Protohackers.Util.peername(downstream_socket)
      }
    }
  end

  @impl true
  def handle_info({:tcp, socket, data}, %State{upstream_socket: socket} = state) do
    :gen_tcp.send(state.downstream_socket, maybe_rewrite_address(data))

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp, socket, data}, %State{downstream_socket: socket} = state) do
    :gen_tcp.send(state.upstream_socket, maybe_rewrite_address(data))

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.info("Socket #{state.peername} closed")
    :gen_tcp.close(state.upstream_socket)
    :gen_tcp.close(state.downstream_socket)

    {:noreply, state}
  end

  # -- Private

  def maybe_rewrite_address(data) do
    # data
    # |> String.split(" ", trim: false)
    # |> Enum.map(fn str ->
    #   Regex.replace(
    #     ~r/^7[[:alnum:]]{25,34}$/,
    #     str,
    #     @tony_address
    #   )
    # end)
    # |> Enum.join("  ")

    # (?<= ) -> "lookbehind" assertions
    #     Matches if the current position in the string is preceded by a match for ' '
    #     that ends at the current position.
    # (?= ) -> "lookahead" assertions
    Regex.replace(
      ~r/(^|(?<= ))7[[:alnum:]]{25,34}((?= )|$)/,
      data,
      @tony_address
    )
  end
end
