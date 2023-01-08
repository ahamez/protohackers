defmodule Protohackers.Speed.Message do
  alias Protohackers.Speed.{Message.Decode, Message}

  def decode(data) do
    case data do
      <<0x20, rest::binary>> -> Decode.decode(%Message.Plate{}, rest)
      <<0x40, rest::binary>> -> Decode.decode(%Message.WantHeartbeat{}, rest)
      <<0x80, rest::binary>> -> Decode.decode(%Message.Camera{}, rest)
      <<0x81, rest::binary>> -> Decode.decode(%Message.Dispatcher{}, rest)
      <<>> -> :need_more_data
      _ -> {:error, :unknown_message_type}
    end
  end
end
