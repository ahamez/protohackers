defmodule Protohackers.Job.Session do
  use GenServer, restart: :transient

  require Logger

  alias Protohackers.Job.Broker

  defmodule State do
    @enforce_keys [:socket, :broker]
    defstruct socket: nil, broker: nil
  end

  def start_link(opts) do
    {client_opts, opts} = Keyword.split(opts, [:socket, :broker])

    GenServer.start_link(__MODULE__, client_opts, opts)
  end

  @impl true
  def init(opts) do
    {:ok, socket} = Keyword.fetch(opts, :socket)
    {:ok, broker} = Keyword.fetch(opts, :broker)

    Logger.debug("New worker #{inspect(self())}")

    {:ok, %State{socket: socket, broker: broker}}
  end

  @impl true
  def handle_info({:tcp, _socket, data}, state) do
    # Logger.debug("(#{inspect(self())}) Received #{inspect(Jason.decode(data))}")

    state =
      with {:ok, {method, request}} <- decode(data),
           {:ok, maybe_response} <- apply(Broker, method, [_pid = state.broker, request]) do
        case maybe_response do
          response when is_map(response) -> send_response(response, state)
          _ -> state
        end
      else
        reason ->
          send_error(state, reason)
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.debug("(#{inspect(self())}) Closing connection")
    Broker.remove_worker(state.broker)

    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:job, response}, state) do
    state = send_response(response, state)

    {:noreply, state}
  end

  # -- Private

  defp decode(line) when is_binary(line) do
    with {:ok, decoded} <- Jason.decode(line),
         {:ok, request} <- make_request(decoded) do
      {:ok, request}
    end
  end

  defp make_request(%{"request" => "put"} = request) do
    with {:ok, queue} <- Map.fetch(request, "queue"),
         :ok <- valid_queue_name?(queue),
         {:ok, priority} <- Map.fetch(request, "pri"),
         :ok <- valid_priority?(priority),
         {:ok, job} <- Map.fetch(request, "job"),
         :ok <- valid_job?(job) do
      {:ok, {:put, %{queue: queue, pri: priority, job: job}}}
    end
  end

  defp make_request(%{"request" => "get"} = request) do
    with {:ok, queues} <- Map.fetch(request, "queues"),
         :ok <- valid_queue_names?(queues),
         wait = Map.get(request, "wait", false),
         true <- is_boolean(wait) do
      {:ok, {:get, %{queues: queues, wait: wait}}}
    end
  end

  defp make_request(%{"request" => "delete"} = request) do
    with {:ok, id} <- Map.fetch(request, "id"),
         true <- is_integer(id) do
      {:ok, {:delete, %{id: id}}}
    end
  end

  defp make_request(%{"request" => "abort"} = request) do
    with {:ok, id} <- Map.fetch(request, "id"),
         true <- is_integer(id) do
      {:ok, {:abort, %{id: id}}}
    end
  end

  defp make_request(_request) do
    {:error, :unkown_request_type}
  end

  defp valid_queue_name?(queue) when is_binary(queue), do: :ok
  defp valid_queue_name?(_queue), do: {:error, :invalid_queue_name}

  defp valid_queue_names?(queues) when is_list(queues) do
    case Enum.all?(queues, &valid_queue_name?/1) do
      true -> :ok
      false -> {:error, :invalid_queue_names}
    end
  end

  defp valid_queue_names?(_), do: {:error, :queues_names_not_a_list}

  defp valid_priority?(priority) when is_integer(priority) and priority >= 0, do: :ok
  defp valid_priority?(_priority), do: {:error, :priority_nan}

  defp valid_job?(job) when is_map(job), do: :ok
  defp valid_job?(_job), do: {:error, :job_not_json}

  defp send_error(state, reason) do
    %{status: "error"}
    |> Map.put("error", "#{inspect(reason)}")
    |> send_response(state)
  end

  defp send_response(response, state) when is_map(response) do
    :gen_tcp.send(state.socket, [Jason.encode_to_iodata!(response), "\n"])

    state
  end
end
