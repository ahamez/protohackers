defmodule Protohackers.Speed.Message.Error do
  defstruct [:msg]
end

defimpl Protohackers.Speed.Message.Encode, for: Protohackers.Speed.Message.Error do
  alias Protohackers.Speed.Encode

  def encode(error) do
    [<<0x10>>, Encode.str(error.msg)]
  end
end
