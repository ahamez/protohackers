defmodule Protohackers.Speed.Message.Dispatcher do
  defstruct [:roads]
end

defimpl Protohackers.Speed.Message.Decode, for: Protohackers.Speed.Message.Dispatcher do
  alias Protohackers.Speed.Decode

  def decode(msg, data) do
    with {:ok, roads, data} <- Decode.u16_array(data) do
      {
        :ok,
        %{msg | roads: roads},
        data
      }
    end
  end
end
