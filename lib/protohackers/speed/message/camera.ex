defmodule Protohackers.Speed.Message.Camera do
  defstruct [:road, :mile, :limit]
end

defimpl Protohackers.Speed.Message.Decode, for: Protohackers.Speed.Message.Camera do
  alias Protohackers.Speed.Decode

  def decode(msg, data) do
    with {:ok, road, data} <- Decode.u16(data),
         {:ok, mile, data} <- Decode.u16(data),
         {:ok, limit, data} <- Decode.u16(data) do
      {
        :ok,
        %{msg | road: road, mile: mile, limit: limit},
        data
      }
    end
  end
end
