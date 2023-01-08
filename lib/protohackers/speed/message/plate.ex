defmodule Protohackers.Speed.Message.Plate do
  defstruct [:plate, :timestamp]
end

defimpl Protohackers.Speed.Message.Decode, for: Protohackers.Speed.Message.Plate do
  alias Protohackers.Speed.Decode

  def decode(msg, data) do
    with {:ok, plate, data} <- Decode.string(data),
         {:ok, timestamp, data} <- Decode.u32(data) do
      {
        :ok,
        %{msg | plate: plate, timestamp: timestamp},
        data
      }
    end
  end
end
