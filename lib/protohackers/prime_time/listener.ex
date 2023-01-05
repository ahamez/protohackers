defmodule Protohackers.PrimeTime.Listener do
  use GenServer, restart: :transient
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init([]) do
    {:ok, :no_state}
  end

  @impl true
  def handle_info({:tcp, client_socket, data}, state) do
    peername = Protohackers.Util.peername(client_socket)

    Logger.info("Received #{inspect(data)} from #{peername}")

    with {:ok, json} <- Jason.decode(data),
         {:ok, "isPrime"} <- Map.fetch(json, "method"),
         {:ok, number} <- Map.fetch(json, "number"),
         {:ok, is_prime} <- is_prime(number) do
      resp = %{
        "method" => "isPrime",
        "prime" => is_prime
      }

      Logger.debug("Answer for #{peername}: #{inspect(resp)}")

      :ok = :gen_tcp.send(client_socket, [Jason.encode!(resp), "\n"])

      {:noreply, state}
    else
      _ ->
        Logger.warn("Malformed request from #{peername}")

        :gen_tcp.send(client_socket, Jason.encode!(%{}))
        :gen_tcp.close(client_socket)

        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info({:tcp_closed, client_socket}, state) do
    Logger.info("Socket #{Protohackers.Util.peername(client_socket)} closed")

    :gen_tcp.close(client_socket)

    {:stop, :normal, state}
  end

  # -- Private

  defp is_prime(other) when is_float(other) do
    {:ok, false}
  end

  defp is_prime(other) when not is_integer(other) do
    {:error, :nan}
  end

  defp is_prime(2), do: {:ok, true}
  defp is_prime(3), do: {:ok, true}
  defp is_prime(5), do: {:ok, true}
  defp is_prime(7), do: {:ok, true}
  defp is_prime(11), do: {:ok, true}
  defp is_prime(13), do: {:ok, true}
  defp is_prime(17), do: {:ok, true}
  defp is_prime(23), do: {:ok, true}
  defp is_prime(29), do: {:ok, true}
  defp is_prime(31), do: {:ok, true}
  defp is_prime(37), do: {:ok, true}
  defp is_prime(41), do: {:ok, true}
  defp is_prime(43), do: {:ok, true}
  defp is_prime(47), do: {:ok, true}
  defp is_prime(53), do: {:ok, true}
  defp is_prime(59), do: {:ok, true}
  defp is_prime(61), do: {:ok, true}
  defp is_prime(67), do: {:ok, true}
  defp is_prime(71), do: {:ok, true}
  defp is_prime(73), do: {:ok, true}
  defp is_prime(79), do: {:ok, true}
  defp is_prime(83), do: {:ok, true}
  defp is_prime(89), do: {:ok, true}
  defp is_prime(97), do: {:ok, true}
  defp is_prime(number) when number < 100, do: {:ok, false}

  defp is_prime(number) do
    n = number |> :math.sqrt() |> trunc()

    is_prime =
      Enum.reduce_while(2..n, true, fn n, _acc ->
        case rem(number, n) do
          0 -> {:halt, false}
          _ -> {:cont, true}
        end
      end)

    {:ok, is_prime}
  end
end
