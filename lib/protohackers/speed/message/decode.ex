defprotocol Protohackers.Speed.Message.Decode do
  @spec decode(t, binary()) :: {:ok, struct(), binary()} | :need_more_data
  def decode(message, data)
end
