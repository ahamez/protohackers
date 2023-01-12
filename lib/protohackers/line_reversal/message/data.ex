defmodule Protohackers.LineReversal.Message.Data do
  defstruct [:session, :pos, :data]

  def new(session, pos, data) do
    %__MODULE__{session: session, pos: pos, data: data}
  end

  def decode([session_str, pos_str, data]) do
    {:ok, new(String.to_integer(session_str), String.to_integer(pos_str), data)}
  end

  def decode(_) do
    {:error, :invalid_data}
  end

  def encode(%__MODULE__{} = data) do
    ["/data/", "#{data.session}", "/", "#{data.pos}", "/", escape(data.data), "/"]
  end

  # -- Private

  defp escape(data) do
    data
    |> String.replace("\\", "\\\\")
    |> String.replace("/", "\\/")
  end
end
