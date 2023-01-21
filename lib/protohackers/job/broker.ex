defmodule Protohackers.Job.Broker do
  use GenServer

  require Logger

  defmodule State do
    defstruct pending_jobs: nil, working_jobs: nil, waiting_clients: nil
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init([]) do
    {
      :ok,
      %State{
        pending_jobs: :ets.new(:pending_jobs, [:ordered_set, :private]),
        working_jobs: :ets.new(:working_jobs, [:set, :private]),
        waiting_clients: :ets.new(:waiting_clients, [:bag, :private])
      }
    }
  end

  # -- Client API

  def put(broker_pid, request) do
    GenServer.call(broker_pid, {:put, request})
  end

  def get(broker_pid, request) do
    GenServer.call(broker_pid, {:get, request})
  end

  def delete(broker_pid, request) do
    GenServer.call(broker_pid, {:delete, request})
  end

  def abort(broker_pid, request) do
    GenServer.call(broker_pid, {:abort, request})
  end

  def remove_worker(broker_pid) do
    GenServer.call(broker_pid, :remove_worker)
  end

  # -- GenServer

  @impl true
  def handle_call({:put, request}, _from, state) do
    id = make_id()
    job = %{id: id, pri: request.pri, queue: request.queue, job: request.job}

    add_pending_job(job, state)

    response = make_response(%{id: id})

    {:reply, {:ok, response}, state}
  end

  @impl true
  def handle_call({:get, request}, {from_pid, _}, state) do
    job = find_available_job(request, state)

    cond do
      job != nil ->
        response = make_response(job)
        state = assign_job(job, from_pid, state)
        {:reply, {:ok, response}, state}

      request.wait == false ->
        {:reply, {:ok, make_response(:no_job)}, state}

      true ->
        register_waiting_worker(from_pid, request.queues, state)
        {:reply, {:ok, :no_response}, state}
    end
  end

  @impl true
  def handle_call({:delete, request}, _from, state) do
    response =
      request.id
      |> delete_job(state)
      |> make_response()

    {:reply, {:ok, response}, state}
  end

  @impl true
  def handle_call({:abort, request}, {from_pid, _}, state) do
    with {:ok, ret} <- abort_job(request.id, from_pid, state) do
      {:reply, {:ok, make_response(ret)}, state}
    else
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:remove_worker, {worker_pid, _}, state) do
    deregister_waiting_worker(worker_pid, state)
    abort_all_jobs(worker_pid, state)

    {:reply, {:ok, :no_response}, state}
  end

  # -- Private

  defp make_response(:ok) do
    make_response(%{})
  end

  defp make_response(:no_job) do
    %{status: "no-job"}
  end

  defp make_response(fields) when is_map(fields) do
    Map.put(fields, :status, "ok")
  end

  defp make_id() do
    System.unique_integer([:positive, :monotonic])
  end

  defp find_available_job(request, state) do
    select =
      :ets.select_reverse(
        state.pending_jobs,
        [{{:_, :"$1"}, [], [:"$1"]}],
        # Number of elements to select. As it's an ordered set, the last one
        # has the highest priority.
        1
      )

    do_find_available_job(select, request.queues, state.pending_jobs)
  end

  defp do_find_available_job(:"$end_of_table", _queues, _pending_jobs), do: nil

  defp do_find_available_job({[job], continuation}, queues, pending_jobs) do
    case job.queue in queues do
      true -> job
      false -> do_find_available_job(:ets.select_reverse(continuation), queues, pending_jobs)
    end
  end

  defp abort_all_jobs(worker_pid, state) when is_pid(worker_pid) do
    jobs_ids =
      :ets.select(
        state.working_jobs,
        [{{:"$1", {worker_pid, :_}}, [], [:"$1"]}]
      )

    Enum.each(jobs_ids, fn id -> abort_job(id, worker_pid, state) end)
  end

  defp assign_job(job, worker_pid, state) when is_pid(worker_pid) do
    # First, delete the job from pending jobs.
    1 =
      :ets.select_delete(
        state.pending_jobs,
        [{{{:_, job.id}, :_}, [], [true]}]
      )

    # Then, add it to the list of jobs worked on.
    :ets.insert(
      state.working_jobs,
      {_key = job.id, _value = {worker_pid, job}}
    )

    state
  end

  defp abort_job(job_id, caller_pid, state) do
    case :ets.lookup(state.working_jobs, job_id) do
      [] ->
        {:ok, :no_job}

      [{^job_id, {^caller_pid, job}}] ->
        1 =
          :ets.select_delete(
            state.working_jobs,
            [{{job.id, :_}, [], [true]}]
          )

        add_pending_job(job, state)

        {:ok, _empty_response = %{}}

      [{^job_id, {_worker_pid, _job}}] ->
        {:error, :illegal_operation}
    end
  end

  defp add_pending_job(job, state) do
    :ets.insert(
      state.pending_jobs,
      {_key = {job.pri, job.id}, _value = job}
    )

    maybe_assign_job_to_waiting_workers(job, state)
  end

  defp maybe_assign_job_to_waiting_workers(job, state) do
    select =
      :ets.select(
        state.waiting_clients,
        [{{job.queue, :"$1"}, [], [:"$1"]}],
        1
      )

    case select do
      :"$end_of_table" ->
        :nothing_to_do

      {[worker_pid], _continuation} ->
        assign_job(job, worker_pid, state)
        response = make_response(job)
        send(worker_pid, {:job, response})
        deregister_waiting_worker_for_queue(worker_pid, job.queue, state)
    end
  end

  defp register_waiting_worker(worker_pid, queues, state) do
    Enum.each(queues, fn queue ->
      :ets.insert(
        state.waiting_clients,
        [{_key = queue, _value = worker_pid}]
      )
    end)
  end

  defp deregister_waiting_worker_for_queue(worker_pid, queue, state) do
    :ets.select_delete(
      state.waiting_clients,
      [{{queue, worker_pid}, [], [true]}]
    )
  end

  defp deregister_waiting_worker(worker_pid, state) do
    :ets.select_delete(
      state.waiting_clients,
      [{{:_, worker_pid}, [], [true]}]
    )
  end

  defp delete_job(job_id, state) do
    delete_pending =
      :ets.select_delete(
        state.pending_jobs,
        [{{{:_, job_id}, :_}, [], [true]}]
      )

    if delete_pending == 0 do
      delete_working =
        :ets.select_delete(
          state.working_jobs,
          [{{job_id, :_}, [], [true]}]
        )

      if delete_working == 0 do
        :no_job
      else
        :ok
      end
    else
      :ok
    end
  end
end
