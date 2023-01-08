defprotocol Protohackers.Speed.Message.Encode do
  @spec encode(t) :: iodata()
  def encode(message)
end
