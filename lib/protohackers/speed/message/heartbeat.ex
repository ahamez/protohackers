defmodule Protohackers.Speed.Message.Heartbeat do
  defstruct []
end

defimpl Protohackers.Speed.Message.Encode, for: Protohackers.Speed.Message.Heartbeat do
  def encode(_) do
    <<0x41>>
  end
end
