defmodule Protohackers.LineReversal.Message.Connect do
  defstruct [:session]

  def new(session) do
    %__MODULE__{session: session}
  end

  def decode([session_str]) do
    {:ok, new(String.to_integer(session_str))}
  end

  def decode(_) do
    {:error, :invalid_connect}
  end
end
