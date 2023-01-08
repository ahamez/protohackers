defmodule Protohackers.Speed.Message.WantHeartbeat do
  defstruct [:interval]
end

defimpl Protohackers.Speed.Message.Decode, for: Protohackers.Speed.Message.WantHeartbeat do
  alias Protohackers.Speed.Decode

  def decode(msg, data) do
    with {:ok, interval, data} <- Decode.u32(data) do
      {
        :ok,
        %{msg | interval: interval},
        data
      }
    end
  end
end
