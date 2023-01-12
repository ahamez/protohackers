defmodule Protohackers.LineReversal.Message.Ack do
  defstruct [:session, :length]

  def new(session, length) do
    %__MODULE__{session: session, length: length}
  end

  def decode([session_str, length_str]) do
    {:ok, new(String.to_integer(session_str), String.to_integer(length_str))}
  end

  def decode(_) do
    {:error, :invalid_ack}
  end

  def encode(%__MODULE__{} = ack) do
    "/ack/#{ack.session}/#{ack.length}/"
  end
end
