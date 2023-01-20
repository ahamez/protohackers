defmodule Protohackers.Vcs.Vcs do
  use GenServer
  require Logger

  defmodule Node do
    defstruct name: nil, children: %{}, latest_revision: 0, revisions: %{}
  end

  defmodule State do
    defstruct fs: %{}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :none, opts)
  end

  @impl true
  def init(:none) do
    {:ok, %State{}}
  end

  def put(pid, path, data) do
    GenServer.call(pid, {:put, path, data})
  end

  def get(pid, path, revision) do
    GenServer.call(pid, {:get, path, revision})
  end

  def list(pid, path) do
    GenServer.call(pid, {:list, path})
  end

  @impl true
  def handle_call({:put, path, data}, _from, state) do
    Logger.info("PUT size: #{byte_size(data)}")

    {reply, fs} =
      with :ok <- is_abs_path?(path),
           {:ok, path} <- split_path(path),
           :ok <- is_text_content?(data) do
        {latest_revision, fs} = put_file(path, data, state.fs)
        {{:ok, latest_revision}, fs}
      else
        {:error, reason} ->
          Logger.warn("PUT #{inspect({:error, reason})}")
          {{:error, reason}, state.fs}
      end

    {:reply, reply, %State{state | fs: fs}}
  end

  @impl true
  def handle_call({:get, path, revision}, _from, state) do
    Logger.info("GET #{path} #{revision}")

    reply =
      with {:ok, revision} <- get_revision(revision),
           :ok <- is_abs_path?(path),
           {:ok, path} <- split_path(path),
           {:ok, data} <- get_file(path, state.fs, revision) do
        {:ok, data}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:list, path}, _from, state) do
    Logger.info("LIST #{path}")

    reply =
      with :ok <- is_abs_path?(path),
           {:ok, path} <- split_path(path) do
        get_listing(path, state.fs)
      end

    {:reply, reply, state}
  end

  # -- Private

  defp put_file([name], data, children) do
    Map.get_and_update(children, name, fn current_value ->
      node =
        case current_value do
          nil ->
            %Node{name: name, latest_revision: 1, revisions: %{1 => data}}

          node ->
            {:ok, latest_data} = Map.fetch(node.revisions, node.latest_revision)

            if data == latest_data do
              Logger.info("File #{name} has same content, don't bump revision")
              node
            else
              %Node{
                node
                | latest_revision: node.latest_revision + 1,
                  revisions: Map.put(node.revisions, node.latest_revision + 1, data)
              }
            end
        end

      {node.latest_revision, node}
    end)
  end

  defp put_file([name | path], data, children) do
    Map.get_and_update(children, name, fn current_value ->
      children =
        case current_value do
          nil -> %{}
          node -> node.children
        end

      {latest_revision, new_children} = put_file(path, data, children)
      node = %Node{name: name, children: new_children}
      {latest_revision, node}
    end)
  end

  defp get_file(["/"], _children, _revision), do: {:error, :illegal_file_name}

  defp get_file([name], children, revision) do
    case Map.fetch(children, name) do
      {:ok, node} ->
        case {revision, node.revisions} do
          {:latest, revisions} -> {:ok, Map.fetch!(revisions, node.latest_revision)}
          {r, revisions} when is_map_key(revisions, r) -> {:ok, Map.fetch!(revisions, r)}
          _ -> {:error, :no_such_revision}
        end

      :error ->
        {:error, :no_such_file}
    end
  end

  defp get_file([name | path], children, revision) do
    case Map.fetch(children, name) do
      {:ok, node} -> get_file(path, node.children, revision)
      :error -> {:error, :no_such_file}
    end
  end

  defp get_listing([name], children) do
    case Map.fetch(children, name) do
      {:ok, node} ->
        list =
          for {name, %Node{} = child} <- node.children do
            if map_size(child.children) > 0 do
              {"#{name}/", "DIR"}
            else
              {name, "r#{child.latest_revision}"}
            end
          end

        list = Enum.sort_by(list, fn {name, _metadata} -> name end)

        {:ok, {length(list), list}}

      :error ->
        {:error, :no_such_file}
    end
  end

  defp get_listing([name | path], children) do
    case Map.fetch(children, name) do
      {:ok, node} -> get_listing(path, node.children)
      :error -> {:error, :no_such_file}
    end
  end

  defp split_path(path) do
    if path =~ ~r"^[[:alnum:]/.\-_]+$" do
      case Path.split(path) do
        ["/" | path] -> {:ok, ["/" | path]}
        _ -> {:error, :illegal_file_name}
      end
    else
      {:error, :illegal_file_name}
    end
  end

  defp is_abs_path?(path) do
    if String.starts_with?(path, "/") do
      :ok
    else
      {:error, :illegal_file_name}
    end
  end

  defp get_revision(:latest), do: {:ok, :latest}

  defp get_revision("r" <> revision) do
    get_revision(revision)
  end

  defp get_revision(revision) do
    case Integer.parse(revision) do
      {revision, ""} -> {:ok, revision}
      _ -> {:error, :no_such_revision}
    end
  end

  defp is_text_content?(data) do
    # Printable characters + newline and tab
    if data =~ ~r"^[\x20-\x7e\x0a\x09]*$" do
      :ok
    else
      {:error, :not_a_text_file}
    end
  end
end
