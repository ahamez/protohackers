defmodule Protohackers.LineReversal.Message.Close do
  defstruct [:session]

  def new(session) do
    %__MODULE__{session: session}
  end

  def decode([session_str]) do
    {:ok, new(String.to_integer(session_str))}
  end

  def decode(_) do
    {:error, :invalid_close}
  end

  def encode(%__MODULE__{} = close) do
    "/close/#{close.session}/"
  end
end
